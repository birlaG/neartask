import { TaskCategory } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';

export class CreateTaskDto {
  @IsEnum(TaskCategory)
  category!: TaskCategory;

  @IsString()
  @MinLength(3)
  title!: string;

  @IsString()
  @MinLength(10)
  description!: string;

  @IsNumber()
  @IsPositive()
  price!: number;

  @IsLatitude()
  latitude!: number;

  @IsLongitude()
  longitude!: number;

  @IsOptional()
  @IsInt()
  @Min(100)
  @Max(50000)
  radiusMeters?: number;

  @IsOptional()
  @IsString()
  scheduledAt?: string; // ISO date string

  // Social-gig-only safety/comfort preferences — enforced in service layer
  @IsOptional()
  @IsString()
  genderPreference?: string;

  @IsOptional()
  @IsInt()
  @Min(18)
  minAge?: number;

  @IsOptional()
  @IsInt()
  @Min(18)
  maxAge?: number;
}
