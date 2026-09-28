// lumira-server/packages/backend/src/modules/ai/cookie-crypto.spec.ts
import { decryptCookies, encryptCookies, selectCookiesForHost } from './cookie-crypto';

const SECRET = 'a'.repeat(64); // 32 字节 hex

describe('selectCookiesForHost', () => {
  const cookies = { 'zhihu.com': 'z_c0=abc', 'www.zhihu.com': 'x=1', 'other.com': 'y=2' };

  it('精确匹配', () => {
    expect(selectCookiesForHost('zhihu.com', cookies)).toEqual({ 'zhihu.com': 'z_c0=abc' });
  });

  it('子域后缀匹配（同时命中父域与自身域）', () => {
    expect(selectCookiesForHost('www.zhihu.com', cookies)).toEqual({
      'zhihu.com': 'z_c0=abc',
      'www.zhihu.com': 'x=1',
    });
  });

  it('伪子域不匹配（evil-zhihu.com 不得命中 zhihu.com）', () => {
    expect(selectCookiesForHost('evil-zhihu.com', cookies)).toEqual({});
  });

  it('无匹配则不发送任何 cookie', () => {
    expect(selectCookiesForHost('example.com', cookies)).toEqual({});
  });

  it('host 大小写与尾点归一化', () => {
    expect(selectCookiesForHost('WWW.Zhihu.com.', cookies)).toEqual({
      'zhihu.com': 'z_c0=abc',
      'www.zhihu.com': 'x=1',
    });
  });
});

describe('cookie 加解密', () => {
  const original = process.env.CRAWL_COOKIE_SECRET;

  beforeEach(() => {
    process.env.CRAWL_COOKIE_SECRET = SECRET;
  });
  afterAll(() => {
    if (original === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = original;
  });

  it('加解密往返一致', () => {
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' });
    expect(stored).toMatch(/^v1:[0-9a-f]+:[0-9a-f]+:[0-9a-f]+$/);
    expect(stored).not.toContain('z_c0=abc');
    expect(decryptCookies(stored)).toEqual({ 'zhihu.com': 'z_c0=abc' });
  });

  it('空对象加密返回 null', () => {
    expect(encryptCookies({})).toBeNull();
    expect(encryptCookies({ 'zhihu.com': '' })).toBeNull();
  });

  it('密钥缺失时加密抛错（绝不落明文）', () => {
    delete process.env.CRAWL_COOKIE_SECRET;
    expect(() => encryptCookies({ 'zhihu.com': 'z_c0=abc' })).toThrow('未配置 CRAWL_COOKIE_SECRET');
  });

  it('密钥长度非法时加密抛错', () => {
    process.env.CRAWL_COOKIE_SECRET = 'abcd';
    expect(() => encryptCookies({ 'zhihu.com': 'z_c0=abc' })).toThrow('未配置 CRAWL_COOKIE_SECRET');
  });

  it('密文被篡改时解密返回空对象（不抛错）', () => {
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' }) as string;
    const tampered = stored.slice(0, -2) + (stored.endsWith('00') ? '11' : '00');
    expect(decryptCookies(tampered)).toEqual({});
  });

  it('格式非法 / 空值 / 密钥缺失时解密返回空对象', () => {
    expect(decryptCookies('garbage')).toEqual({});
    expect(decryptCookies(null)).toEqual({});
    expect(decryptCookies('')).toEqual({});
    delete process.env.CRAWL_COOKIE_SECRET;
    const stored = `v1:${'0'.repeat(24)}:${'0'.repeat(32)}:${'0'.repeat(8)}`;
    expect(decryptCookies(stored)).toEqual({});
  });
});