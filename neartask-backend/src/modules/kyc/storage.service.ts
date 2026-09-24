import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

export interface UploadResult {
  url: string;
  key: string;
}

/**
 * Switches on STORAGE_DRIVER ('local' | 's3'). Local is fine for dev/testing
 * on your machine; for the Contabo VPS, point this at an S3-compatible
 * object storage bucket (Contabo Object Storage, Backblaze B2, Cloudflare
 * R2 all work — none of them are AWS-specific, the S3 API is a standard).
 *
 * KYC documents are sensitive — do NOT serve the local-storage /uploads
 * folder as world-readable in production. This dev setup is for local
 * testing only; production should use the S3 driver with a private bucket
 * and signed URLs (not implemented here — see README).
 */
@Injectable()
export class StorageService {
  private driver = process.env.STORAGE_DRIVER || 'local';
  private uploadDir = process.env.UPLOAD_DIR || path.join(process.cwd(), 'uploads');
  private s3Client?: S3Client;

  constructor() {
    if (this.driver === 's3') {
      this.s3Client = new S3Client({
        region: process.env.S3_REGION || 'auto',
        endpoint: process.env.S3_ENDPOINT,
        forcePathStyle: true, // required by most non-AWS S3-compatible providers
        credentials: {
          accessKeyId: process.env.S3_ACCESS_KEY || '',
          secretAccessKey: process.env.S3_SECRET_KEY || '',
        },
      });
    } else {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  async upload(file: Express.Multer.File, folder: string): Promise<UploadResult> {
    const key = `${folder}/${randomUUID()}${path.extname(file.originalname || '')}`;

    if (this.driver === 's3') {
      await this.s3Client!.send(
        new PutObjectCommand({
          Bucket: process.env.S3_BUCKET,
          Key: key,
          Body: file.buffer,
          ContentType: file.mimetype,
        }),
      );
      const base = process.env.S3_PUBLIC_BASE_URL || `${process.env.S3_ENDPOINT}/${process.env.S3_BUCKET}`;
      return { url: `${base}/${key}`, key };
    }

    const destPath = path.join(this.uploadDir, key);
    fs.mkdirSync(path.dirname(destPath), { recursive: true });
    fs.writeFileSync(destPath, file.buffer);
    return { url: `/uploads/${key}`, key };
  }
}
