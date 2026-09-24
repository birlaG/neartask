import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { WalletModule } from '../wallet/wallet.module';
import { TasksModule } from '../tasks/tasks.module';

@Module({
  imports: [WalletModule, TasksModule],
  controllers: [AdminController],
})
export class AdminModule {}
