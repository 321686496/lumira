import { AiSilhouetteTaskService } from './ai-silhouette-task.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { UploadFile } from '../templates/admin-templates.service';

jest.mock('./ai-generate-silhouette.service');

const generateMock = AiSilhouetteService.prototype.generate as jest.MockedFunction<
  typeof AiSilhouetteService.prototype.generate
>;

function image(): UploadFile {
  return { buffer: Buffer.from('image'), filename: 'a.jpg', mimetype: 'image/jpeg' };
}

describe('AiSilhouetteTaskService', () => {
  beforeEach(() => {
    generateMock.mockReset();
  });

  it('submit returns immediately and exposes an async done task', async () => {
    let resolveGenerate: (value: { image: string; mimeType: 'image/png' }) => void;
    generateMock.mockImplementationOnce(() => new Promise((resolve) => {
      resolveGenerate = resolve;
    }));
    const service = new AiSilhouetteTaskService({ generate: generateMock } as unknown as AiSilhouetteService);

    const started = await service.submit(image(), JSON.stringify({ mode: 'sketch' }));
    expect(started.taskId).toMatch(/^sil_/);
    expect(['pending', 'running']).toContain(service.get(started.taskId)?.status);

    resolveGenerate!({ image: 'png', mimeType: 'image/png' });
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(service.get(started.taskId)).toMatchObject({
      status: 'done',
      result: { image: 'png', mimeType: 'image/png' },
    });
    service.onModuleDestroy();
  });

  it('generation errors are stored on the task instead of rejecting submit', async () => {
    generateMock.mockRejectedValueOnce(new Error('model missing'));
    const service = new AiSilhouetteTaskService({ generate: generateMock } as unknown as AiSilhouetteService);
    const started = await service.submit(image(), null);
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(service.get(started.taskId)).toMatchObject({ status: 'error', error: 'model missing' });
    service.onModuleDestroy();
  });
});
