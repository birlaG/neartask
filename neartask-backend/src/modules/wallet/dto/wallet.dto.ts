import { IsNumber, IsPositive, IsString, MinLength } from 'class-validator';

export class TopUpDto {
  @IsNumber()
  @IsPositive()
  amount!: number;

  @IsString()
  @MinLength(3)
  gatewayRef!: string;
}

export class WithdrawDto {
  @IsNumber()
  @IsPositive()
  amount!: number;

  @IsString()
  @MinLength(3)
  payoutDestination!: string; // bank account or UPI ID
}
