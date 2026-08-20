import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { questionnaireRecords } from '../../database/schema';
import { ProfileService } from '../profile/profile.service';
import { SubmitQuestionnaireDto } from './dto/submit-questionnaire.dto';

@Injectable()
export class QuestionnaireService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly profileService: ProfileService,
  ) {}

  async submit(deviceId: string, dto: SubmitQuestionnaireDto, ip: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    await db.insert(questionnaireRecords).values({
      deviceId,
      answersJson: JSON.stringify(dto.answers),
      submittedAt: dto.submittedAt,
      clientIp: ip,
    });

    await this.profileService.mergeQuestionnairePrefs(deviceId, {
      gender: dto.answers.gender,
      favorite_categories: dto.answers.favorite_categories,
      pain_points: dto.answers.pain_points,
      skill_level: dto.answers.skill_level,
      expectations: dto.answers.expectations,
      common_scenes: dto.answers.common_scenes,
      shoot_frequency: dto.answers.shoot_frequency,
    });

    return { success: true, receivedAt: now };
  }
}
