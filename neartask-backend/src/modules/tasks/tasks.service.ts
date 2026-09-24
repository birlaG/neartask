import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ApplicationStatus, TaskCategory, TaskStatus, VerificationTier } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { WalletService } from '../wallet/wallet.service';
import { getPreAcceptRefundPercent } from '../../config/constants';
import { CreateTaskDto } from './dto/create-task.dto';
import { ApplyTaskDto } from './dto/apply-task.dto';
import { RateTaskDto } from './dto/rate-task.dto';
import { RaiseDisputeDto, DisputeResolution } from './dto/dispute.dto';

@Injectable()
export class TasksService {
  constructor(
    private prisma: PrismaService,
    private walletService: WalletService,
  ) {}

  /**
   * Creates a task and immediately locks the price from the creator's
   * wallet — this is what lets applicants trust the money is real before
   * they apply (PRD §6.6, fund flow step 1).
   *
   * Guardrail from PRD §8: gender/age preferences are only permitted on
   * SOCIAL tasks, and SOCIAL tasks require VERIFIED tier or above.
   */
  async createTask(creatorId: string, dto: CreateTaskDto) {
    if (dto.category === TaskCategory.CHORE && (dto.genderPreference || dto.minAge || dto.maxAge)) {
      throw new BadRequestException('Gender/age preferences are only allowed on SOCIAL tasks');
    }

    if (dto.category === TaskCategory.SOCIAL) {
      const creator = await this.prisma.user.findUnique({ where: { id: creatorId } });
      if (!creator) throw new NotFoundException('User not found');
      if (creator.verificationTier === VerificationTier.BASIC) {
        throw new ForbiddenException('Social gigs require identity verification. Please complete KYC first.');
      }
    }

    return this.prisma.$transaction(async (tx) => {
      const task = await tx.task.create({
        data: {
          creatorId,
          category: dto.category,
          title: dto.title,
          description: dto.description,
          price: dto.price,
          latitude: dto.latitude,
          longitude: dto.longitude,
          radiusMeters: dto.radiusMeters ?? 3000,
          scheduledAt: dto.scheduledAt ? new Date(dto.scheduledAt) : null,
          genderPreference: dto.genderPreference,
          minAge: dto.minAge,
          maxAge: dto.maxAge,
        },
      });

      await this.walletService.lockFundsForTask(tx, creatorId, task.id, Number(dto.price));

      return task;
    });
  }

  /**
   * Geo-nearby task feed using PostGIS. Uses raw SQL since Prisma has no
   * native geography type support. For MVP volumes this scans on lat/lng
   * columns directly; once task volume grows, add a dedicated `geography`
   * column + GiST index (see migration note in README) for query speed.
   */
  async findNearby(lat: number, lng: number, radiusMeters = 5000, category?: TaskCategory) {
    return this.prisma.$queryRawUnsafe(
      `
      SELECT id, title, description, category, price, latitude, longitude, "scheduledAt", status,
        ST_Distance(
          ST_MakePoint(longitude, latitude)::geography,
          ST_MakePoint($1, $2)::geography
        ) AS distance_meters
      FROM "Task"
      WHERE status = 'OPEN'
        ${category ? `AND category = '${category}'` : ''}
        AND ST_DWithin(
          ST_MakePoint(longitude, latitude)::geography,
          ST_MakePoint($1, $2)::geography,
          $3
        )
      ORDER BY distance_meters ASC
      LIMIT 50;
      `,
      lng,
      lat,
      radiusMeters,
    );
  }

  async applyToTask(taskId: string, applicantId: string, dto: ApplyTaskDto) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId } });
    if (!task) throw new NotFoundException('Task not found');
    if (task.status !== TaskStatus.OPEN) throw new BadRequestException('This task is no longer open for applications');
    if (task.creatorId === applicantId) throw new BadRequestException('You cannot apply to your own task');

    if (task.category === TaskCategory.SOCIAL) {
      const applicant = await this.prisma.user.findUnique({ where: { id: applicantId } });
      if (!applicant) throw new NotFoundException('User not found');
      if (applicant.verificationTier === VerificationTier.BASIC) {
        throw new ForbiddenException('Social gigs require identity verification. Please complete KYC first.');
      }
      this.assertMeetsPreferences(task, applicant);
    }

    return this.prisma.taskApplication.create({
      data: { taskId, applicantId, note: dto.note },
    });
  }

  private assertMeetsPreferences(
    task: { genderPreference: string | null; minAge: number | null; maxAge: number | null },
    applicant: { gender: string | null; dateOfBirth: Date | null },
  ) {
    if (task.genderPreference && applicant.gender && task.genderPreference !== applicant.gender) {
      throw new ForbiddenException('This task has a gender preference you do not match');
    }
    if ((task.minAge || task.maxAge) && applicant.dateOfBirth) {
      const age = getAge(applicant.dateOfBirth);
      if (task.minAge && age < task.minAge) throw new ForbiddenException('You do not meet this task\'s minimum age preference');
      if (task.maxAge && age > task.maxAge) throw new ForbiddenException('You do not meet this task\'s maximum age preference');
    }
  }

  /**
   * Creator selects one applicant. All other applications are auto-declined.
   * From this point on, per PRD §6.6, cancellation by the creator gets no refund.
   */
  async selectApplicant(taskId: string, creatorId: string, applicationId: string) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId }, include: { applications: true } });
    if (!task) throw new NotFoundException('Task not found');
    if (task.creatorId !== creatorId) throw new ForbiddenException('Only the task creator can select an applicant');
    if (task.status !== TaskStatus.OPEN) throw new BadRequestException('This task already has a selection or is closed');

    const chosen = task.applications.find((a) => a.id === applicationId);
    if (!chosen) throw new NotFoundException('Application not found for this task');

    return this.prisma.$transaction(async (tx) => {
      await tx.taskApplication.update({ where: { id: applicationId }, data: { status: ApplicationStatus.SELECTED } });
      await tx.taskApplication.updateMany({
        where: { taskId, id: { not: applicationId } },
        data: { status: ApplicationStatus.DECLINED },
      });
      return tx.task.update({
        where: { id: taskId },
        data: { status: TaskStatus.SELECTED, selectedApplicationId: applicationId },
      });
    });
  }

  /**
   * Creator confirms the gig is done. Releases locked funds to the doer.
   */
  async completeTask(taskId: string, creatorId: string) {
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      include: { selectedApplication: true },
    });
    if (!task) throw new NotFoundException('Task not found');
    if (task.creatorId !== creatorId) throw new ForbiddenException('Only the task creator can mark this complete');
    if (task.status !== TaskStatus.SELECTED && task.status !== TaskStatus.IN_PROGRESS) {
      throw new BadRequestException('Task must have a selected applicant before it can be completed');
    }
    if (!task.selectedApplication) throw new BadRequestException('No selected applicant on this task');

    const doerId = task.selectedApplication.applicantId;

    return this.prisma.$transaction(async (tx) => {
      await this.walletService.releaseToDoer(tx, creatorId, doerId, taskId, Number(task.price));
      await tx.user.update({ where: { id: doerId }, data: { completedTasks: { increment: 1 } } });
      return tx.task.update({ where: { id: taskId }, data: { status: TaskStatus.COMPLETED } });
    });
  }

  /**
   * Cancellation, implementing the exact refund table from PRD §6.6:
   *  - OPEN (no one selected yet):   creator gets PRE_ACCEPT_REFUND_PERCENT back
   *  - SELECTED/IN_PROGRESS:         no refund — funds are committed
   */
  async cancelTask(taskId: string, creatorId: string) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId } });
    if (!task) throw new NotFoundException('Task not found');
    if (task.creatorId !== creatorId) throw new ForbiddenException('Only the task creator can cancel this task');
    if (task.status === TaskStatus.COMPLETED || task.status === TaskStatus.CANCELLED) {
      throw new BadRequestException('This task cannot be cancelled from its current state');
    }

    const refundPercent = task.status === TaskStatus.OPEN ? getPreAcceptRefundPercent() : 0;

    return this.prisma.$transaction(async (tx) => {
      await this.walletService.refundLockedFunds(tx, creatorId, taskId, Number(task.price), refundPercent);
      return tx.task.update({ where: { id: taskId }, data: { status: TaskStatus.CANCELLED } });
    });
  }

  /**
   * Doer selected but never showed up. Creator gets a FULL refund (not the
   * partial pre-accept rate), and the doer takes a trust-score strike.
   * This case exists to close the gap in a creator-cancels-only policy —
   * see PRD §6.6 refund table, "doer fails to show" row.
   */
  async reportNoShow(taskId: string, creatorId: string) {
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      include: { selectedApplication: true },
    });
    if (!task) throw new NotFoundException('Task not found');
    if (task.creatorId !== creatorId) throw new ForbiddenException('Only the task creator can report this');
    if (task.status !== TaskStatus.SELECTED && task.status !== TaskStatus.IN_PROGRESS) {
      throw new BadRequestException('No active selected applicant to report');
    }
    if (!task.selectedApplication) throw new BadRequestException('No selected applicant on this task');

    return this.prisma.$transaction(async (tx) => {
      await this.walletService.refundLockedFunds(tx, creatorId, taskId, Number(task.price), 100);
      await tx.taskApplication.update({
        where: { id: task.selectedApplication!.id },
        data: { status: ApplicationStatus.NO_SHOW },
      });
      await tx.user.update({
        where: { id: task.selectedApplication!.applicantId },
        data: { noShowCount: { increment: 1 } },
      });
      return tx.task.update({ where: { id: taskId }, data: { status: TaskStatus.CANCELLED } });
    });
  }

  /**
   * Either party on a COMPLETED task can rate the other, once each. Recomputes
   * the rated user's trustScore as the average of all ratings they've received
   * — this is what applicant ranking in a creator's selection list draws on.
   */
  async rateTask(taskId: string, fromUserId: string, dto: RateTaskDto) {
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      include: { selectedApplication: true },
    });
    if (!task) throw new NotFoundException('Task not found');
    if (task.status !== TaskStatus.COMPLETED) throw new BadRequestException('You can only rate a completed task');

    const doerId = task.selectedApplication?.applicantId;
    if (!doerId) throw new BadRequestException('This task has no selected applicant');

    const isCreator = fromUserId === task.creatorId;
    const isDoer = fromUserId === doerId;
    if (!isCreator && !isDoer) {
      throw new ForbiddenException('Only the creator or the selected doer can rate this task');
    }

    const expectedToUserId = isCreator ? doerId : task.creatorId;
    if (dto.toUserId !== expectedToUserId) {
      throw new BadRequestException('toUserId does not match the other party on this task');
    }

    const existing = await this.prisma.rating.findUnique({
      where: { taskId_fromUserId_toUserId: { taskId, fromUserId, toUserId: dto.toUserId } },
    });
    if (existing) throw new BadRequestException('You already rated this task');

    return this.prisma.$transaction(async (tx) => {
      const rating = await tx.rating.create({
        data: { taskId, fromUserId, toUserId: dto.toUserId, score: dto.score, comment: dto.comment },
      });
      const agg = await tx.rating.aggregate({ where: { toUserId: dto.toUserId }, _avg: { score: true } });
      await tx.user.update({ where: { id: dto.toUserId }, data: { trustScore: agg._avg.score ?? 0 } });
      return rating;
    });
  }

  /**
   * Either the creator or the selected doer can raise a dispute while the
   * gig is SELECTED/IN_PROGRESS — i.e. before completion, while funds are
   * still locked. This is deliberately NOT available after COMPLETED:
   * funds have already been released to the doer by then, so a dispute at
   * that point needs a human support conversation, not an automated flow.
   */
  async raiseDispute(taskId: string, userId: string, dto: RaiseDisputeDto) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId }, include: { selectedApplication: true } });
    if (!task) throw new NotFoundException('Task not found');

    const doerId = task.selectedApplication?.applicantId;
    const isCreator = userId === task.creatorId;
    const isDoer = userId === doerId;
    if (!isCreator && !isDoer) throw new ForbiddenException('Only the creator or the selected doer can raise a dispute');

    if (task.status !== TaskStatus.SELECTED && task.status !== TaskStatus.IN_PROGRESS) {
      throw new BadRequestException('Disputes can only be raised while a gig is selected and in progress');
    }

    return this.prisma.task.update({
      where: { id: taskId },
      data: { status: TaskStatus.DISPUTED, disputeReason: dto.reason, disputedById: userId },
    });
  }

  /**
   * Admin-only. Funds stay locked/untouched until this is called — never
   * auto-released on a dispute. Resolution reuses the same wallet primitives
   * as the normal complete/cancel paths, so the ledger entries look
   * identical to a non-disputed outcome (just later, and admin-triggered).
   */
  async resolveDispute(taskId: string, resolution: DisputeResolution, adminNote?: string) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId }, include: { selectedApplication: true } });
    if (!task) throw new NotFoundException('Task not found');
    if (task.status !== TaskStatus.DISPUTED) throw new BadRequestException('This task is not under dispute');
    if (!task.selectedApplication) throw new BadRequestException('No selected applicant on this task');

    const doerId = task.selectedApplication.applicantId;

    return this.prisma.$transaction(async (tx) => {
      if (resolution === DisputeResolution.RELEASE_TO_DOER) {
        await this.walletService.releaseToDoer(tx, task.creatorId, doerId, taskId, Number(task.price));
        await tx.user.update({ where: { id: doerId }, data: { completedTasks: { increment: 1 } } });
        return tx.task.update({
          where: { id: taskId },
          data: { status: TaskStatus.COMPLETED, disputeReason: `${task.disputeReason ?? ''}\n[Resolved by admin: released to doer${adminNote ? ' — ' + adminNote : ''}]` },
        });
      }
      await this.walletService.refundLockedFunds(tx, task.creatorId, taskId, Number(task.price), 100);
      return tx.task.update({
        where: { id: taskId },
        data: { status: TaskStatus.CANCELLED, disputeReason: `${task.disputeReason ?? ''}\n[Resolved by admin: refunded creator${adminNote ? ' — ' + adminNote : ''}]` },
      });
    });
  }

  async getTaskWithApplications(taskId: string) {
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      include: { applications: { include: { applicant: true } }, ratings: true },
    });
    if (!task) throw new NotFoundException('Task not found');
    return task;
  }
}

function getAge(dob: Date): number {
  const diff = Date.now() - dob.getTime();
  return Math.floor(diff / (365.25 * 24 * 60 * 60 * 1000));
}
