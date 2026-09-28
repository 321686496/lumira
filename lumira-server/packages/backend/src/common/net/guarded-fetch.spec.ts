// lumira-server/packages/backend/src/common/net/guarded-fetch.spec.ts
import { assertPublicHttpUrl, fetchGuarded, isPrivateAddress } from './guarded-fetch';

/** 注入式 DNS：按域名返回预设地址，单测不触网 */
const dns = (map: Record<string, string[]>) => async (host: string) =>
  (map[host] ?? []).map((address) => ({ address }));

describe('isPrivateAddress', () => {
  it('拦截 IPv4 私网 / 环回 / 链路本地 / 保留段', () => {
    for (const ip of ['10.1.2.3', '172.16.0.1', '192.168.1.1', '127.0.0.1', '169.254.1.1', '0.0.0.0', '100.64.0.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });

  it('放行公网 IPv4', () => {
    expect(isPrivateAddress('8.8.8.8')).toBe(false);
  });

  it('拦截 IPv6 环回 / ULA / 链路本地 / v4 映射私网', () => {
    for (const ip of ['::1', 'fc00::1', 'fd12:3456::1', 'fe80::1', '::ffff:192.168.1.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });
});

describe('assertPublicHttpUrl', () => {
  it('拒绝非 http(s) 协议', async () => {
    await expect(assertPublicHttpUrl('file:///etc/passwd')).rejects.toThrow('不支持的协议');
  });

  it('拒绝非法 URL', async () => {
    await expect(assertPublicHttpUrl('not a url')).rejects.toThrow('图片地址非法');
  });

  it('IP 字面量为私网时拒绝', async () => {
    await expect(assertPublicHttpUrl('http://192.168.1.10/x')).rejects.toThrow('目标地址位于内网');
    await expect(assertPublicHttpUrl('http://[::1]/x')).rejects.toThrow('目标地址位于内网');
  });

  it('裸公网 IP 放行', async () => {
    await expect(assertPublicHttpUrl('http://8.8.8.8/x')).resolves.toBeInstanceOf(URL);
  });

  it('域名解析到私网时拒绝（注入 lookup）', async () => {
    const deps = { lookup: dns({ 'evil.example': ['172.16.0.9'] }) };
    await expect(assertPublicHttpUrl('http://evil.example/x', deps)).rejects.toThrow('目标地址解析到内网');
  });

  it('域名解析全部为公网时放行（注入 lookup）', async () => {
    const deps = { lookup: dns({ 'ok.example': ['93.184.216.34'] }) };
    await expect(assertPublicHttpUrl('https://ok.example/x', deps)).resolves.toBeInstanceOf(URL);
  });

  it('域名无解析结果时拒绝（注入 lookup）', async () => {
    const deps = { lookup: dns({}) };
    await expect(assertPublicHttpUrl('https://none.example/x', deps)).rejects.toThrow('域名无解析结果');
  });
});

describe('fetchGuarded', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => fetchMock.mockReset());
  afterAll(() => fetchMock.mockRestore());

  const publicDns = { lookup: dns({ 'ok.example': ['93.184.216.34'] }) };

  it('逐跳校验重定向并跟到最终响应', async () => {
    fetchMock
      .mockResolvedValueOnce(new Response('', { status: 302, headers: { Location: 'https://ok.example/b' } }))
      .mockResolvedValueOnce(new Response('final', { status: 200 }));
    const res = await fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns });
    expect(res.status).toBe(200);
    await expect(res.text()).resolves.toBe('final');
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('重定向目标解析到私网时拒绝且不发出该跳请求', async () => {
    fetchMock.mockResolvedValueOnce(new Response('', { status: 302, headers: { Location: 'http://192.168.1.9/secret' } }));
    await expect(fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns })).rejects.toThrow('目标地址位于内网');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('自定义 headers 覆盖默认 User-Agent（供爬取链路传伪装头与 cookie）', async () => {
    fetchMock.mockResolvedValueOnce(new Response('ok', { status: 200 }));
    await fetchGuarded('https://ok.example/a', {
      timeoutMs: 1000,
      headers: { 'User-Agent': 'Chrome', Cookie: 'a=1' },
      ...publicDns,
    });
    const init = fetchMock.mock.calls[0][1] as RequestInit;
    const headers = init.headers as Record<string, string>;
    expect(headers['User-Agent']).toBe('Chrome');
    expect(headers.Cookie).toBe('a=1');
  });

  it('超时映射为可读错误', async () => {
    fetchMock.mockRejectedValueOnce(Object.assign(new Error('aborted'), { name: 'TimeoutError' }));
    await expect(fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns })).rejects.toThrow('抓取超时');
  });

  it('超出跳数上限时拒绝', async () => {
    fetchMock.mockImplementation(async () => new Response('', { status: 302, headers: { Location: 'https://ok.example/loop' } }));
    await expect(fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns })).rejects.toThrow('重定向次数超出上限');
  });
});