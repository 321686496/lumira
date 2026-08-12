import { describe, expect, it } from 'vitest';
import {
  BUILTIN_SILHOUETTES,
  BUILTIN_SILHOUETTE_KEYS,
} from '@/lib/builtin-silhouettes';

describe('builtin silhouettes', () => {
  it('exposes 12 keys and excludes none', () => {
    expect(BUILTIN_SILHOUETTE_KEYS).toHaveLength(12);
    expect(BUILTIN_SILHOUETTE_KEYS).not.toContain('none');
  });

  it('maps every key to a non-empty SVG with 1:2 viewBox and currentColor fill', () => {
    for (const key of BUILTIN_SILHOUETTE_KEYS) {
      const svg = BUILTIN_SILHOUETTES[key];
      expect(svg, `key ${key} missing`).toBeTruthy();
      expect(svg).toContain('viewBox="0 0 100 200"');
      expect(svg).toContain('fill="currentColor"');
    }
  });
});
