// lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.spec.ts
import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { BatchEventDto } from './batch-events.dto';

function buildEvent(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    clientEventId: 'e1',
    itemType: 'template',
    itemId: 't1',
    itemSource: 'builtin',
    eventType: 'open_detail',
    occurredAt: 1000,
    ...overrides,
  };
}

describe('BatchEventDto 校验', () => {
  it('接受 banner 曝光/点击事件', async () => {
    const dto = plainToInstance(BatchEventDto, {
      events: [
        buildEvent({ clientEventId: 'b1', itemType: 'banner', itemId: 'op_invite', itemSource: 'app', eventType: 'expose' }),
        buildEvent({ clientEventId: 'b2', itemType: 'banner', itemId: 'op_invite', itemSource: 'app', eventType: 'click' }),
      ],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('仍接受 template/scene 的既有三类事件', async () => {
    const dto = plainToInstance(BatchEventDto, {
      events: [
        buildEvent({ clientEventId: 'e1', itemType: 'template', eventType: 'open_detail' }),
        buildEvent({ clientEventId: 'e2', itemType: 'template', eventType: 'use_shoot' }),
        buildEvent({ clientEventId: 'e3', itemType: 'scene', itemSource: 'system', eventType: 'scene_select' }),
      ],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('拒绝未知 itemType / eventType', async () => {
    const dto = plainToInstance(BatchEventDto, {
      events: [buildEvent({ itemType: 'foo' }), buildEvent({ eventType: 'bar' })],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
    const flat = JSON.stringify(errors);
    expect(flat).toContain('itemType');
    expect(flat).toContain('eventType');
  });
});
