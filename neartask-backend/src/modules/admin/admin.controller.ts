import { Body, Controller, Get, NotFoundException, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { KycStatus, TaskStatus } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { WalletService } from '../wallet/wallet.service';
import { TasksService } from '../tasks/tasks.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ReviewKycDto } from './dto/review-kyc.dto';
import { ResolveDisputeDto } from '../tasks/dto/dispute.dto';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(
    private walletService: WalletService,
    private tasksService: TasksService,
    private prisma: PrismaService,
  ) {}

  // ── Withdrawal queue (PRD §6.6 manual withdrawal flow) ──────────

  @Get('withdrawals/pending')
  pendingWithdrawals() {
    return this.walletService.listPendingWithdrawals();
  }

  @Post('withdrawals/:transactionId/mark-paid')
  markPaid(@Param('transactionId') transactionId: string) {
    // Only call this once the transfer has genuinely gone out — see README.
    return this.walletService.markWithdrawalPaid(transactionId);
  }

  // ── KYC review (PRD §7 verification tiers) ──────────
  // Reviews an actual submitted document pair, not just a status flag.

  @Get('kyc/pending')
  pendingKyc() {
    return this.prisma.kycSubmission.findMany({
      where: { status: KycStatus.PENDING },
      include: {
        user: { select: { id: true, name: true, phone: true, email: true } },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  @Patch('kyc/:submissionId')
  async reviewKyc(@Param('submissionId') submissionId: string, @Body() dto: ReviewKycDto) {
    const submission = await this.prisma.kycSubmission.findUnique({ where: { id: submissionId } });
    if (!submission) throw new NotFoundException('KYC submission not found');

    await this.prisma.kycSubmission.update({
      where: { id: submissionId },
      data: { status: dto.status, adminNote: dto.adminNote, reviewedAt: new Date() },
    });

    return this.prisma.user.update({
      where: { id: submission.userId },
      data: {
        kycStatus: dto.status,
        verificationTier: dto.status === KycStatus.VERIFIED ? (dto.tier ?? 'VERIFIED') : undefined,
      },
    });
  }

  // ── Reports / disputes ──────────
  // Raised via POST /tasks/:id/dispute by either party while SELECTED/IN_PROGRESS.
  // Funds stay locked until resolved here — never auto-released.

  @Get('tasks/disputed')
  disputedTasks() {
    return this.prisma.task.findMany({
      where: { status: TaskStatus.DISPUTED },
      include: {
        creator: { select: { id: true, name: true, phone: true } },
        selectedApplication: { include: { applicant: { select: { id: true, name: true, phone: true } } } },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  @Post('disputes/:taskId/resolve')
  resolveDispute(@Param('taskId') taskId: string, @Body() dto: ResolveDisputeDto) {
    return this.tasksService.resolveDispute(taskId, dto.resolution, dto.adminNote);
  }

  // ── Dashboard stats ──────────

  @Get('stats')
  async stats() {
    const [totalUsers, verifiedUsers, openTasks, completedTasks, pendingWithdrawalCount] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { kycStatus: KycStatus.VERIFIED } }),
      this.prisma.task.count({ where: { status: TaskStatus.OPEN } }),
      this.prisma.task.count({ where: { status: TaskStatus.COMPLETED } }),
      this.prisma.walletTransaction.count({ where: { type: 'WITHDRAWAL_REQUEST', status: 'PENDING' } }),
    ]);
    return { totalUsers, verifiedUsers, openTasks, completedTasks, pendingWithdrawalCount };
  }
}
