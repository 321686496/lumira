// src/lib/__tests__/asset-url.test.ts
import { describe, it, expect } from 'vitest';
import {
  toAssetUrl,
  toCategoryThumbUrl,
  toCategoryThumbFallbackUrl,
  toTemplateThumbUrl,
  toTemplateThumbFallbackUrl,
  snapThumbWidth,
} from '../asset-url';

const BACKEND = 'http://localhost:3000';

describe('toAssetUrl', () => {
  it('extracts /uploads/ path from absolute http URL (Mixed Content fix)', () => {
    expect(toAssetUrl('http://localhost:3000/uploads/templates/a/cover.jpg', BACKEND)).toBe(
      '/uploads/templates/a/cover.jpg',
    );
  });

  it('keeps absolute HTTPS assets direct to avoid proxy overhead', () => {
    expect(toAssetUrl('https://api.example.com/uploads/categories/portrait/icon.png', BACKEND)).toBe(
      'https://api.example.com/uploads/categories/portrait/icon.png',
    );
  });

  it('uses backend origin for HTTPS-hosted relative assets', () => {
    expect(
      toAssetUrl('/uploads/templates/a/cover.jpg', 'https://lumira.example.com'),
    ).toBe('https://lumira.example.com/uploads/templates/a/cover.jpg');
  });

  it('keeps relative /uploads/ path unchanged', () => {
    expect(toAssetUrl('/uploads/templates/a/cover.jpg', BACKEND)).toBe('/uploads/templates/a/cover.jpg');
  });

  it('keeps absolute URL without /uploads/ unchanged', () => {
    expect(toAssetUrl('https://cdn.example.com/other.png', BACKEND)).toBe('https://cdn.example.com/other.png');
  });

  it('joins backend URL for non-slash relative path', () => {
    expect(toAssetUrl('uploads/templates/a/cover.jpg', BACKEND)).toBe(
      'http://localhost:3000/uploads/templates/a/cover.jpg',
    );
  });

  it('returns null for empty input', () => {
    expect(toAssetUrl(null, BACKEND)).toBeNull();
    expect(toAssetUrl(undefined, BACKEND)).toBeNull();
    expect(toAssetUrl('', BACKEND)).toBeNull();
  });
});

describe('snapThumbWidth', () => {
  it('snaps to the nearest ladder step', () => {
    expect(snapThumbWidth(100)).toBe(160);
    expect(snapThumbWidth(200)).toBe(160);
    expect(snapThumbWidth(280)).toBe(320);
    expect(snapThumbWidth(700)).toBe(640);
    expect(snapThumbWidth(1200)).toBe(1080);
  });

  it('takes the smaller step when distances tie', () => {
    // 240 距 160/320 各 80 → 取较小值 160
    expect(snapThumbWidth(240)).toBe(160);
    // 560 距 480/640 各 80 → 取较小值 480
    expect(snapThumbWidth(560)).toBe(480);
  });
});

describe('thumbnail URLs', () => {
  it('derives template thumbnails from the storage origin (HTTPS direct)', () => {
    expect(
      toTemplateThumbUrl(
        'https://lumira.example.com/uploads/templates/srv_a/image_0.png',
        'https://lumira.example.com',
        640,
      ),
    ).toBe('https://lumira.example.com/uploads/thumbs/templates/srv_a/image_0.w640.webp');
  });

  it('falls back to the same-origin relative path for an HTTP backend', () => {
    expect(
      toTemplateThumbUrl('http://localhost:3000/uploads/templates/srv_a/cover.jpg', BACKEND),
    ).toBe('/uploads/thumbs/templates/srv_a/cover.w480.webp');
  });

  it('builds category thumbnail URLs (width snapped to the ladder)', () => {
    expect(
      toCategoryThumbUrl(
        'https://lumira.example.com/uploads/categories/portrait/icon.png',
        'https://lumira.example.com',
        280,
      ),
    ).toBe('https://lumira.example.com/uploads/thumbs/categories/portrait/w320.jpg');
  });

  it('falls back to toAssetUrl for non-/uploads/ sources', () => {
    expect(
      toTemplateThumbUrl('https://cdn.example.com/cover.png', 'https://lumira.example.com', 480),
    ).toBe('https://cdn.example.com/cover.png');
  });

  it('builds template thumbnail fallback URLs (backend dynamic endpoint)', () => {
    expect(
      toTemplateThumbFallbackUrl('https://lumira.example.com/uploads/templates/srv_a/image_0.png', 640),
    ).toBe('/api/v1/thumbs/templates/srv_a/image_0.png?w=640');
  });

  it('builds category thumbnail fallback URLs (backend dynamic endpoint)', () => {
    expect(
      toCategoryThumbFallbackUrl('https://lumira.example.com/uploads/categories/portrait/icon.png', 280),
    ).toBe('/api/v1/thumbs/categories/portrait?w=320');
  });

  it('returns null thumbnails/fallbacks for empty input', () => {
    expect(toTemplateThumbUrl(null, BACKEND)).toBeNull();
    expect(toCategoryThumbUrl(null, BACKEND)).toBeNull();
    expect(toTemplateThumbFallbackUrl(null)).toBeNull();
    expect(toCategoryThumbFallbackUrl(null)).toBeNull();
  });
});
