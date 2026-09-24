import { BadRequestException, Injectable } from '@nestjs/common';
import { KycStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { StorageService } from './storage.service';

@Injectable()
export class KycService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
  ) {}

  async submit(userId: string, idDocument?: Express.Multer.File, selfie?: Express.Multer.File) {
    if (!idDocument || !selfie) {
      throw new BadRequestException('Both an ID document and a selfie photo are required');
    }

    const idUpload = await this.storage.upload(idDocument, `kyc/${userId}`);
    const selfieUpload = await this.storage.upload(selfie, `kyc/${userId}`);

    const submission = await this.prisma.kycSubmission.create({
      data: {
        userId,
        idDocumentUrl: idUpload.url,
        selfieUrl: selfieUpload.url,
        status: KycStatus.PENDING,
      },
    });

    await this.prisma.user.update({ where: { id: userId }, data: { kycStatus: KycStatus.PENDING } });

    return submission;
  }

  async latestForUser(userId: string) {
    return this.prisma.kycSubmission.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
