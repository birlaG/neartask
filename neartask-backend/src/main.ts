import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { join } from 'path';
import * as express from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strips unknown fields — important with money-related DTOs
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableCors(); // tighten this to your actual app domains before production

  // Local-disk KYC uploads only — this is a DEV convenience. In production,
  // switch STORAGE_DRIVER to 's3' and put KYC documents in a private bucket,
  // not behind a public static route like this one (see README §Storage).
  if ((process.env.STORAGE_DRIVER || 'local') === 'local') {
    app.use('/uploads', express.static(join(process.cwd(), 'uploads')));
  }

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`NearTask API running on port ${port}`);
}

bootstrap();
