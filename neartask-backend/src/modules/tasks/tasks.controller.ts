import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { TaskCategory } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TasksService } from './tasks.service';
import { CreateTaskDto } from './dto/create-task.dto';
import { ApplyTaskDto } from './dto/apply-task.dto';
import { RateTaskDto } from './dto/rate-task.dto';
import { RaiseDisputeDto } from './dto/dispute.dto';

@UseGuards(JwtAuthGuard)
@Controller('tasks')
export class TasksController {
  constructor(private tasksService: TasksService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateTaskDto) {
    return this.tasksService.createTask(req.user.userId, dto);
  }

  @Get('nearby')
  nearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius') radius?: string,
    @Query('category') category?: TaskCategory,
  ) {
    return this.tasksService.findNearby(
      parseFloat(lat),
      parseFloat(lng),
      radius ? parseInt(radius, 10) : undefined,
      category,
    );
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.tasksService.getTaskWithApplications(id);
  }

  @Post(':id/apply')
  apply(@Req() req: any, @Param('id') id: string, @Body() dto: ApplyTaskDto) {
    return this.tasksService.applyToTask(id, req.user.userId, dto);
  }

  @Post(':id/select/:applicationId')
  select(@Req() req: any, @Param('id') id: string, @Param('applicationId') applicationId: string) {
    return this.tasksService.selectApplicant(id, req.user.userId, applicationId);
  }

  @Post(':id/complete')
  complete(@Req() req: any, @Param('id') id: string) {
    return this.tasksService.completeTask(id, req.user.userId);
  }

  @Post(':id/cancel')
  cancel(@Req() req: any, @Param('id') id: string) {
    return this.tasksService.cancelTask(id, req.user.userId);
  }

  @Post(':id/no-show')
  noShow(@Req() req: any, @Param('id') id: string) {
    return this.tasksService.reportNoShow(id, req.user.userId);
  }

  @Post(':id/rate')
  rate(@Req() req: any, @Param('id') id: string, @Body() dto: RateTaskDto) {
    return this.tasksService.rateTask(id, req.user.userId, dto);
  }

  @Post(':id/dispute')
  dispute(@Req() req: any, @Param('id') id: string, @Body() dto: RaiseDisputeDto) {
    return this.tasksService.raiseDispute(id, req.user.userId, dto);
  }
}
