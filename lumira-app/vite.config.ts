/**
 * uni-app 构建配置（dev:h5 / build:h5 使用）
 * 注意：uni-app 通过 @dcloudio/vite-plugin-uni 接管，配置极简
 */
import { defineConfig } from 'vite'
import uni from '@dcloudio/vite-plugin-uni'
import path from 'path'

export default defineConfig({
  plugins: [uni()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `@import "@/theme/tokens.scss";`,
      },
    },
  },
})
