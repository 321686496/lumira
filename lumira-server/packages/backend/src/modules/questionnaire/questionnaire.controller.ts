import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { QuestionnaireService } from './questionnaire.service';
import { SubmitQuestionnaireDto } from './dto/submit-questionnaire.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId, ClientIp } from '../../common/decorators';

@Controller('questionnaire')
@UseGuards(DeviceAuthGuard)
export class QuestionnaireController {
  constructor(private readonly questionnaireService: QuestionnaireService) {}

  @Post('submit')
  async submit(
    @DeviceId() deviceId: string,
    @Body() dto: SubmitQuestionnaireDto,
    @ClientIp() ip: string,
  ) {
    return this.questionnaireService.submit(deviceId, dto, ip);
  }
}
