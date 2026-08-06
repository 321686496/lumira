// src/lib/__tests__/asset-url.test.ts
import { describe, it, expect } from 'vitest';
import { toAssetUrl } from '../asset-url';

const BACKEND = 'http://localhost:3000';

describe('toAssetUrl', () => {
  it('extracts /uploads/ path from absolute http URL (Mixed Content fix)', () => {
    expect(toAssetUrl('http://localhost:3000/uploads/templates/a/cover.jpg', BACKEND)).toBe(
      '/uploads/templates/a/cover.jpg',
    );
  });

  it('extracts /uploads/ path from absolute https URL', () => {
    expect(toAssetUrl('https://api.example.com/uploads/categories/portrait/icon.png', BACKEND)).toBe(
      '/uploads/categories/portrait/icon.png',
    );
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
