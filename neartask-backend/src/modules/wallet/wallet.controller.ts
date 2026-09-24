import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WalletService } from './wallet.service';
import { TopUpDto, WithdrawDto } from './dto/wallet.dto';

@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private walletService: WalletService) {}

  @Get('balance')
  getBalance(@Req() req: any) {
    return this.walletService.getBalance(req.user.userId);
  }

  @Get('transactions')
  getHistory(@Req() req: any) {
    return this.walletService.getTransactionHistory(req.user.userId);
  }

  @Post('topup')
  topUp(@Req() req: any, @Body() dto: TopUpDto) {
    // In production this endpoint is called by your payment-gateway webhook
    // handler after a verified successful payment — never trust a client-
    // supplied "I paid" call without gateway signature verification.
    return this.walletService.topUp(req.user.userId, dto.amount, dto.gatewayRef);
  }

  @Post('withdraw')
  requestWithdrawal(@Req() req: any, @Body() dto: WithdrawDto) {
    return this.walletService.requestWithdrawal(req.user.userId, dto.amount, dto.payoutDestination);
  }
}
