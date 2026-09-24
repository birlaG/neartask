import { IsOptional, IsPhoneNumber, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsPhoneNumber('IN')
  phone!: string;

  @IsString()
  @MinLength(2)
  name!: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsOptional()
  @IsString()
  email?: string;
}

export class LoginDto {
  @IsPhoneNumber('IN')
  phone!: string;

  @IsString()
  password!: string;
}
