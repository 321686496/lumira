// vitest.config.ts
// Set TZ=UTC so timezone-sensitive tests (e.g. toUnixSeconds interpreting
// '2024-01-01T00:00' as local time) behave as the brief's UTC-based assertions expect.
process.env.TZ = 'UTC';

import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: [],
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
