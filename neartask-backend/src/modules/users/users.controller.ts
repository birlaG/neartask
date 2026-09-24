import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private prisma: PrismaService) {}

  @Get('me')
  async me(@Req() req: any) {
    const user = await this.prisma.user.findUnique({ where: { id: req.user.userId } });
    if (!user) return null;
    const { passwordHash, ...safe } = user;
    return safe;
  }

  @Patch('me')
  async updateMe(@Req() req: any, @Body() dto: UpdateProfileDto) {
    const updated = await this.prisma.user.update({
      where: { id: req.user.userId },
      data: {
        name: dto.name,
        gender: dto.gender,
        dateOfBirth: dto.dateOfBirth ? new Date(dto.dateOfBirth) : undefined,
        latitude: dto.latitude,
        longitude: dto.longitude,
        profileVisibility: dto.profileVisibility,
      },
    });
    const { passwordHash, ...safe } = updated;
    return safe;
  }
}
