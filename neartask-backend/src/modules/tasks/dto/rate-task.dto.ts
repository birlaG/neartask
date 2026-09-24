import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class RateTaskDto {
  @IsString()
  toUserId!: string;

  @IsInt()
  @Min(1)
  @Max(5)
  score!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;
}
