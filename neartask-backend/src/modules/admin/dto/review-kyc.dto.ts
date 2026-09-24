import { KycStatus, VerificationTier } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';

export class ReviewKycDto {
  @IsEnum(KycStatus)
  status!: KycStatus; // VERIFIED or REJECTED

  @IsOptional()
  @IsEnum(VerificationTier)
  tier?: VerificationTier; // typically VERIFIED when approving

  @IsOptional()
  @IsString()
  @MaxLength(500)
  adminNote?: string;
}
