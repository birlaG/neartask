import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RaiseDisputeDto {
  @IsString()
  @MinLength(10)
  @MaxLength(1000)
  reason!: string;
}

export enum DisputeResolution {
  RELEASE_TO_DOER = 'RELEASE_TO_DOER',
  REFUND_CREATOR = 'REFUND_CREATOR',
}

export class ResolveDisputeDto {
  @IsEnum(DisputeResolution)
  resolution!: DisputeResolution;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  adminNote?: string;
}
