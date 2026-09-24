import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, TransactionType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { getPlatformCommissionPercent } from '../../config/constants';

/**
 * WalletService owns every rupee movement in the system.
 *
 * Hard rule baked into every method here: the ledger (WalletTransaction) is
 * append-only and must always reflect what actually happened. Nothing in
 * this file ever deletes a transaction row — corrections are new, offsetting
 * rows, so the wallet always has a full, honest audit trail (PRD §6.6).
 */
@Injectable()
export class WalletService {
  constructor(private prisma: PrismaService) {}

  async getOrCreateWallet(userId: string) {
    const existing = await this.prisma.wallet.findUnique({ where: { userId } });
    if (existing) return existing;
    return this.prisma.wallet.create({ data: { userId } });
  }

  async getBalance(userId: string) {
    const wallet = await this.getOrCreateWallet(userId);
    return {
      available: wallet.availableBalance,
      locked: wallet.lockedBalance,
    };
  }

  async getTransactionHistory(userId: string) {
    const wallet = await this.getOrCreateWallet(userId);
    return this.prisma.walletTransaction.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Top-up: money coming IN via the payment gateway (Razorpay/Cashfree).
   * `gatewayRef` should be the payment gateway's transaction ID for reconciliation.
   */
  async topUp(userId: string, amount: number, gatewayRef: string) {
    if (amount <= 0) throw new BadRequestException('Top-up amount must be positive');
    const wallet = await this.getOrCreateWallet(userId);

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.wallet.update({
        where: { id: wallet.id },
        data: { availableBalance: { increment: amount } },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: TransactionType.TOPUP,
          amount,
          note: `Gateway ref: ${gatewayRef}`,
        },
      });
      return updated;
    });
  }

  /**
   * Locks funds from a creator's Available balance into their own Locked
   * balance at task-posting time (PRD §6.6, step 1 of the fund flow).
   * Throws if the creator doesn't have enough available balance.
   */
  async lockFundsForTask(tx: Prisma.TransactionClient, userId: string, taskId: string, amount: number) {
    const wallet = await tx.wallet.findUnique({ where: { userId } });
    if (!wallet) throw new NotFoundException('Wallet not found');
    if (Number(wallet.availableBalance) < amount) {
      throw new BadRequestException('Insufficient wallet balance to post this task');
    }

    await tx.wallet.update({
      where: { id: wallet.id },
      data: {
        availableBalance: { decrement: amount },
        lockedBalance: { increment: amount },
      },
    });
    await tx.walletTransaction.create({
      data: { walletId: wallet.id, type: TransactionType.LOCK, amount, taskId },
    });
  }

  /**
   * Refunds a percentage of locked funds back to Available balance.
   * Used for: pre-acceptance cancellation (partial, e.g. 95%) and
   * doer no-show / mutual cancellation (full, 100%) — PRD §6.6 refund table.
   * The un-refunded remainder is recorded as forfeited commission.
   */
  async refundLockedFunds(
    tx: Prisma.TransactionClient,
    userId: string,
    taskId: string,
    lockedAmount: number,
    refundPercent: number,
  ) {
    const wallet = await tx.wallet.findUnique({ where: { userId } });
    if (!wallet) throw new NotFoundException('Wallet not found');

    const refundAmount = round2((lockedAmount * refundPercent) / 100);
    const forfeitedAmount = round2(lockedAmount - refundAmount);

    await tx.wallet.update({
      where: { id: wallet.id },
      data: {
        lockedBalance: { decrement: lockedAmount },
        availableBalance: { increment: refundAmount },
      },
    });
    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        type: TransactionType.REFUND_UNLOCK,
        amount: refundAmount,
        taskId,
        note: `Refund ${refundPercent}% of locked ₹${lockedAmount}`,
      },
    });
    if (forfeitedAmount > 0) {
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: TransactionType.COMMISSION,
          amount: forfeitedAmount,
          taskId,
          note: 'Non-refundable portion on cancellation',
        },
      });
    }
  }

  /**
   * Releases a creator's locked funds to the doer on task completion,
   * minus platform commission (PRD §6.6, step 3 of the fund flow).
   */
  async releaseToDoer(
    tx: Prisma.TransactionClient,
    creatorUserId: string,
    doerUserId: string,
    taskId: string,
    amount: number,
  ) {
    const commissionPercent = getPlatformCommissionPercent();
    const commission = round2((amount * commissionPercent) / 100);
    const payout = round2(amount - commission);

    const creatorWallet = await tx.wallet.findUnique({ where: { userId: creatorUserId } });
    const doerWallet = await tx.wallet.findUnique({ where: { userId: doerUserId } });
    if (!creatorWallet || !doerWallet) throw new NotFoundException('Wallet not found');

    await tx.wallet.update({
      where: { id: creatorWallet.id },
      data: { lockedBalance: { decrement: amount } },
    });
    await tx.wallet.update({
      where: { id: doerWallet.id },
      data: { availableBalance: { increment: payout } },
    });

    await tx.walletTransaction.create({
      data: {
        walletId: creatorWallet.id,
        type: TransactionType.RELEASE_TO_DOER,
        amount,
        taskId,
        note: `Released to doer, commission ₹${commission} (${commissionPercent}%)`,
      },
    });
    await tx.walletTransaction.create({
      data: {
        walletId: doerWallet.id,
        type: TransactionType.RELEASE_TO_DOER,
        amount: payout,
        taskId,
        note: 'Task payout received',
      },
    });
    await tx.walletTransaction.create({
      data: {
        walletId: creatorWallet.id,
        type: TransactionType.COMMISSION,
        amount: commission,
        taskId,
        status: 'COMPLETED',
        note: 'Platform commission',
      },
    });
  }

  /**
   * Doer requests a withdrawal. This does NOT move real money — it just
   * decrements the ledger and creates a PENDING request for an admin to
   * action manually (PRD §6.6 manual withdrawal flow). The request must be
   * marked PAID only after the transfer has actually gone out.
   */
  async requestWithdrawal(userId: string, amount: number, payoutDestination: string) {
    if (amount <= 0) throw new BadRequestException('Withdrawal amount must be positive');
    const wallet = await this.getOrCreateWallet(userId);
    if (Number(wallet.availableBalance) < amount) {
      throw new BadRequestException('Insufficient available balance');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { availableBalance: { decrement: amount } },
      });
      return tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: TransactionType.WITHDRAWAL_REQUEST,
          amount,
          status: 'PENDING',
          note: `Payout destination: ${payoutDestination}`,
        },
      });
    });
  }

  /**
   * Admin-only: confirms a withdrawal request has actually been paid out
   * manually. Never call this before the money has genuinely left your
   * account — the ledger must always match reality (PRD §6.6).
   */
  async markWithdrawalPaid(transactionId: string) {
    const txn = await this.prisma.walletTransaction.findUnique({ where: { id: transactionId } });
    if (!txn || txn.type !== TransactionType.WITHDRAWAL_REQUEST) {
      throw new NotFoundException('Withdrawal request not found');
    }
    if (txn.status === 'COMPLETED') {
      throw new BadRequestException('Withdrawal already marked paid');
    }
    return this.prisma.walletTransaction.update({
      where: { id: transactionId },
      data: { status: 'COMPLETED', type: TransactionType.WITHDRAWAL_PAID },
    });
  }

  async listPendingWithdrawals() {
    return this.prisma.walletTransaction.findMany({
      where: { type: TransactionType.WITHDRAWAL_REQUEST, status: 'PENDING' },
      include: { wallet: { include: { user: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
