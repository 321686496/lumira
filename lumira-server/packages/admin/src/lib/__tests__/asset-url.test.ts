// src/lib/__tests__/asset-url.test.ts
import { describe, it, expect } from 'vitest';
import { toAssetUrl, toCategoryThumbUrl, toTemplateThumbUrl } from '../asset-url';

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

describe('thumbnail URLs', () => {
  it('loads template thumbnails directly from an HTTPS backend', () => {
    expect(
      toTemplateThumbUrl(
        'https://lumira.example.com/uploads/templates/srv_a/image_0.png',
        'https://lumira.example.com',
        640,
      ),
    ).toBe('https://lumira.example.com/api/v1/thumbs/templates/srv_a/image_0.png?w=640');
  });

  it('uses the same-origin proxy for an HTTP backend', () => {
    expect(
      toTemplateThumbUrl('http://localhost:3000/uploads/templates/srv_a/cover.jpg', BACKEND),
    ).toBe('/api/v1/thumbs/templates/srv_a/cover.jpg?w=480');
  });

  it('builds category thumbnail URLs', () => {
    expect(
      toCategoryThumbUrl(
        'https://lumira.example.com/uploads/categories/portrait/icon.png',
        'https://lumira.example.com',
        280,
      ),
    ).toBe('https://lumira.example.com/api/v1/thumbs/categories/portrait?w=280');
  });
});
