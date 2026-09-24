import { IsOptional, IsString, MaxLength } from 'class-validator';

export class ApplyTaskDto {
  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}
