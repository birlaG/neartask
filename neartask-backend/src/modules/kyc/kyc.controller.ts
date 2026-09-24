import { Controller, Get, Post, Req, UseGuards, UseInterceptors, UploadedFiles } from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { KycService } from './kyc.service';

const MAX_FILE_SIZE_BYTES = 8 * 1024 * 1024; // 8 MB — generous for a phone photo, small enough to not choke the server

@UseGuards(JwtAuthGuard)
@Controller('kyc')
export class KycController {
  constructor(private kycService: KycService) {}

  @Post('submit')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'idDocument', maxCount: 1 },
        { name: 'selfie', maxCount: 1 },
      ],
      { storage: memoryStorage(), limits: { fileSize: MAX_FILE_SIZE_BYTES } },
    ),
  )
  submit(
    @Req() req: any,
    @UploadedFiles() files: { idDocument?: Express.Multer.File[]; selfie?: Express.Multer.File[] },
  ) {
    return this.kycService.submit(req.user.userId, files.idDocument?.[0], files.selfie?.[0]);
  }

  @Get('me')
  me(@Req() req: any) {
    return this.kycService.latestForUser(req.user.userId);
  }
}
