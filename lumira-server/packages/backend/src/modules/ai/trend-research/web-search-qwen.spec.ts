// web-search-qwen.spec.ts
import { createQwenSearchProvider } from './web-search-qwen';
import type { WebSearchProvider } from './web-search.provider';

const OK_TOOL_CALL = {
  message: {
    tool_calls: [{
      id: 'call_1', type: 'function',
      function: { name: 'web_search', arguments: JSON.stringify({ search_info: { search_results: [
        { title: '秋日少女写真', url: 'https://a.example', snippet: '秋日光影 温柔' },
        { title: '胶片感人像', url: 'https://b.example', content: '胶片 复古 质感' },
      ] } }) },
    }],
  },
};

const OK_JSON_CONTENT = {
  message: { content: JSON.stringify({ results: [
    { title: '公园人像构图', url: 'https://c.example', content: '构图 光比' },
  ] }) },
};

describe('web-search-qwen', () => {
  let provider: WebSearchProvider;
  beforeEach(() => {
    provider = createQwenSearchProvider({ baseUrl: 'https://qw.cn/v1', apiKey: 'sk-qw', model: 'qwen-plus' });
  });

  it('tool_calls.web_search.search_info.search_results → ResearchItem[]（source=qwen，url 取自 url，无 url 时回退 site）', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_TOOL_CALL), { status: 200 }));
    const items = await provider.search({ query: '人像', limit: 10 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0];
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.enable_search).toBe(true);
    expect((init as RequestInit).headers).toMatchObject({ Authorization: 'Bearer sk-qw' });
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ source: 'qwen', title: '秋日少女写真', url: 'https://a.example' });
    expect(Array.isArray(items[0].keywords)).toBe(true);
  });

  it('content 为 JSON 字符串 {results} → 结构化兜底解析', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_JSON_CONTENT), { status: 200 }));
    const items = await provider.search({ query: '构图', limit: 10 });
    expect(items).toHaveLength(1);
    expect(items[0].title).toBe('公园人像构图');
  });

  it('三方中转站顶层 sources[]（title+url 带反引号）→ 综述置首 + 解析并清洗引用', async () => {
    const gtw = {
      choices: [{ message: { role: 'assistant', content: '这是回答文本。' } }],
      sources: [
        { index: 1, title: 'weather.com.cn', url: '`https://www.weather.com.cn/weather/101010100.shtml`' },
        { index: 2, title: 'nmc.cn', url: '`https://www.nmc.cn/publish/forecast/ABJ/beijing.html`' },
      ],
    };
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(gtw), { status: 200 }));
    const items = await provider.search({ query: '北京天气', limit: 10 });
    expect(items).toHaveLength(3);
    expect(items[0]).toMatchObject({ source: 'qwen', title: '联网综述', snippet: '这是回答文本。' });
    expect(items[1]).toMatchObject({
      source: 'qwen',
      title: 'weather.com.cn',
      url: 'https://www.weather.com.cn/weather/101010100.shtml', // 反引号被清洗
    });
    expect(items[2].url).toBe('https://www.nmc.cn/publish/forecast/ABJ/beijing.html');
  });

  it('存在顶层 sources 时：content 正文作为「联网综述」条目置首，引用排其后（不再丢弃正文）', async () => {
    const gtw = {
      choices: [{ message: { role: 'assistant', content: '纯文本回答，非 JSON。' } }],
      sources: [{ index: 1, title: '源A', url: 'https://a.example' }],
    };
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(gtw), { status: 200 }));
    const items = await provider.search({ query: '趋势', limit: 10 });
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ source: 'qwen', title: '联网综述', snippet: '纯文本回答，非 JSON。' });
    expect(items[0].url).toBeUndefined();
    expect(items[1].url).toBe('https://a.example');
  });

  it('正文为长 markdown 综述 + sources 仅域名 → 综述完整带出（不再只留裸域名）', async () => {
    const content = [
      '# 📷 编辑手记｜2026 下半年「未过节日」摄影模板日历',
      '',
      '| 节日 | 公历日期 | 距今 |',
      '|---|---|---|',
      '| 中秋节 | 9/25 | 2 天 |',
      '| 国庆节 | 10/1 | 8 天 |',
      '| 万圣节 | 10/31 | 38 天 |',
    ].join('\n');
    const gtw = {
      choices: [{ message: { role: 'assistant', content } }],
      sources: [{ index: 1, title: 'holidays-calendar.net', url: 'https://holidays-calendar.net' }],
    };
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(gtw), { status: 200 }));
    const items = await provider.search({ query: '近期节日 节日摄影模板', limit: 10 });
    expect(items).toHaveLength(2);
    expect(items[0].title).toBe('联网综述');
    expect(items[0].snippet).toContain('中秋节');
    expect(items[0].snippet).toContain('10/1');
    expect(items[0].keywords).toEqual([]);
    expect(items[1].title).toBe('holidays-calendar.net');
  });

  it('无引用可解析 → 抛“未取到引用”错误', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify({ message: { content: '没有检索到相关资料。' } }), { status: 200 }));
    await expect(provider.search({ query: '冷门', limit: 10 })).rejects.toThrow('未取到引用');
  });

  it('缺 baseUrl → 抛可读错误', async () => {
    const p = createQwenSearchProvider({ apiKey: 'k' });
    await expect(p.search({ query: 'x' })).rejects.toThrow('baseUrl');
  });

  it('上游 HTTP 错误 → 抛可读错误', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 429 }));
    await expect(provider.search({ query: 'x' })).rejects.toThrow(/HTTP 429/);
  });
});