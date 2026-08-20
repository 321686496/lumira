import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateProfileDto } from './update-profile.dto';

describe('UpdateProfileDto', () => {
  it('接受合法的新增偏好字段', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      gender: 'male',
      skillLevel: 'intermediate',
      shootFrequency: 'weekly',
      favoriteCategories: ['portrait', 'food'],
      painPoints: ['composition'],
      expectations: ['share_works'],
      commonScenes: ['cafe'],
      avatarUrl: 'https://example.com/uploads/users/x/avatar.png',
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('拒绝不在白名单的单选项', async () => {
    const dto = plainToInstance(UpdateProfileDto, { gender: 'robot' });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('拒绝多选中的非法枚举值', async () => {
    const dto = plainToInstance(UpdateProfileDto, { favoriteCategories: ['hiking'] });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});