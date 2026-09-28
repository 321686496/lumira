// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.spec.ts
import { isPrivateAddress, extractPageImageUrl } from './research-image-fetch';

describe('isPrivateAddress', () => {
  it('拦截 IPv4 私网 / 环回 / 链路本地 / 保留段', () => {
    for (const ip of ['10.1.2.3', '172.16.0.1', '172.31.255.254', '192.168.1.1', '127.0.0.1', '169.254.1.1', '0.0.0.0', '100.64.0.1', '198.18.0.1', '224.0.0.1', '240.0.0.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });

  it('放行公网 IPv4', () => {
    for (const ip of ['8.8.8.8', '1.1.1.1', '203.0.113.9']) {
      expect(isPrivateAddress(ip)).toBe(false);
    }
  });

  it('拦截 IPv6 环回 / ULA / 链路本地 / v4 映射私网', () => {
    for (const ip of ['::1', 'fc00::1', 'fd12:3456::1', 'fe80::1', '::ffff:192.168.1.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });

  it('放行公网 IPv6', () => {
    expect(isPrivateAddress('2001:4860:4860::8888')).toBe(false);
  });
});

describe('extractPageImageUrl', () => {
  it('优先 og:image', () => {
    const html = `<html><head><meta property="og:image" content="https://cdn.a.com/o.jpg"><meta name="twitter:image" content="https://cdn.a.com/t.jpg"></head></html>`;
    expect(extractPageImageUrl(html, 'https://a.com/p')).toBe('https://cdn.a.com/o.jpg');
  });

  it('无 og 时回退 twitter:image', () => {
    const html = `<head><meta name="twitter:image" content="https://cdn.a.com/t.jpg"></head>`;
    expect(extractPageImageUrl(html, 'https://a.com/p')).toBe('https://cdn.a.com/t.jpg');
  });

  it('相对路径解析为绝对地址', () => {
    const html = `<head><meta property="og:image" content="/img/o.png"></head>`;
    expect(extractPageImageUrl(html, 'https://a.com/p/q')).toBe('https://a.com/img/o.png');
  });

  it('都没有时返回 null', () => {
    expect(extractPageImageUrl('<head></head>', 'https://a.com/p')).toBeNull();
  });
});
