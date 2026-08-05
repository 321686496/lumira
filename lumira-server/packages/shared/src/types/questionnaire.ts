export type QuestionId =
  | 'source' | 'favorite_categories' | 'pain_points' | 'skill_level'
  | 'expectations' | 'common_scenes' | 'shoot_frequency';

export interface QuestionnaireAnswers {
  source: string | null;
  favorite_categories: string[];
  pain_points: string[];
  skill_level: string | null;
  expectations: string[];
  common_scenes: string[];
  shoot_frequency: string | null;
}

export interface SubmitQuestionnaireRequest {
  answers: QuestionnaireAnswers;
  submittedAt: number;
}

export interface SubmitQuestionnaireResponse {
  success: boolean;
  receivedAt: number;
}

export interface QuestionnaireRecord {
  id: number;
  deviceId: string;
  answersJson: string;
  submittedAt: number;
  clientIp: string | null;
}

export interface QuestionnaireListItem extends QuestionnaireRecord {
  deviceAlias: string | null;
}

export interface QuestionnaireListResponse {
  data: QuestionnaireListItem[];
  total: number;
  page: number;
  pageSize: number;
}

export interface QuestionnaireHistoryResponse {
  data: QuestionnaireRecord[];
  total: number;
}

export interface QuestionnaireStats {
  totalRespondents: number;
  source: Record<string, number>;
  favorite_categories: Record<string, number>;
  pain_points: Record<string, number>;
  skill_level: Record<string, number>;
  expectations: Record<string, number>;
  common_scenes: Record<string, number>;
  shoot_frequency: Record<string, number>;
}
