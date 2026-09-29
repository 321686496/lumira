// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.spec.ts
import { isPrivateAddress, extractPageImageUrl, extractPageImages, extractPageText } from './research-image-fetch';

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

describe('extractPageImages', () => {
  it('og:image 优先，且补充正文多张 <img>（相对路径转绝对）', () => {
    const html = `<head><meta property="og:image" content="https://cdn.a.com/o.jpg"></head><body><img src="/img/1.png"><img src="https://cdn.a.com/2.jpg"></body>`;
    const urls = extractPageImages(html, 'https://a.com/p', 4);
    expect(urls[0]).toBe('https://cdn.a.com/o.jpg');
    expect(urls).toContain('https://a.com/img/1.png');
    expect(urls).toContain('https://cdn.a.com/2.jpg');
  });

  it('忽略 data: 与锚点占位，不污染结果', () => {
    const html = `<img src="data:image/png;base64,AAAA"><img src="#placeholder"><img src="https://cdn.a.com/1.jpg">`;
    const urls = extractPageImages(html, 'https://a.com/p', 4);
    expect(urls).toEqual(['https://cdn.a.com/1.jpg']);
  });

  it('cap 截断到上限', () => {
    const html = Array.from({ length: 6 }, (_, i) => `<img src="https://cdn.a.com/${i}.jpg">`).join('');
    expect(extractPageImages(html, 'https://a.com/p', 3)).toHaveLength(3);
  });

  it('同一绝对地址去重（相对与绝对指向同一图只保留一次）', () => {
    const html = `<img src="/img/1.png"><img src="https://a.com/img/1.png">`;
    const urls = extractPageImages(html, 'https://a.com/p', 4);
    expect(urls.filter((u) => u === 'https://a.com/img/1.png')).toHaveLength(1);
  });

  it('无图时返回空数组', () => {
    expect(extractPageImages('<head></head>', 'https://a.com/p')).toEqual([]);
  });
});

describe('extractPageText', () => {
  it('提取 og:title/<title> 并剥离脚本/样式/标签后压缩空白', () => {
    const html = `<html><head><title>人像构图指南</title></head><body><script>var x=1;</script><style>.a{}</style><p>拍照时注意  光线方向，</p><img src="/img/1.png"><div>机位高低</div></body></html>`;
    const { title, text } = extractPageText(html, 'https://a.com/p');
    expect(title).toBe('人像构图指南');
    expect(text).toContain('光线方向');
    expect(text).toContain('机位高低');
    expect(text).not.toContain('var x=1');
    expect(text).not.toContain('.a{}');
    expect(text).not.toMatch(/\s{2,}/); // 空白已压缩
  });

  it('无正文（仅有 <title>）→ text 只含标题文本', () => {
    const { title, text } = extractPageText('<head><title>只有标题</title></head>', 'https://a.com/p');
    expect(title).toBe('只有标题');
    expect(text).toBe('只有标题'); // 标签剥离后标题文本仍在正文中
  });

  it('实体反转义：&nbsp;/&amp;/&lt; 等还原为可读文本', () => {
    const { text } = extractPageText('<p>侧逆光 &amp; 补反光板&nbsp;，3&nbsp;人</p>', 'https://a.com/p');
    expect(text).toContain('&');
    expect(text).not.toContain('&amp;');
    expect(text).not.toContain('&nbsp;');
  });
});
