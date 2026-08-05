import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { questionnaireRecords } from '../../database/schema';
import { SubmitQuestionnaireDto } from './dto/submit-questionnaire.dto';

@Injectable()
export class QuestionnaireService {
  constructor(private readonly dbService: DatabaseService) {}

  async submit(deviceId: string, dto: SubmitQuestionnaireDto, ip: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    await db.insert(questionnaireRecords).values({
      deviceId,
      answersJson: JSON.stringify(dto.answers),
      submittedAt: dto.submittedAt,
      clientIp: ip,
    });
    return { success: true, receivedAt: now };
  }
}
