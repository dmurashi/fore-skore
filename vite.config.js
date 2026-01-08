import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig({
  plugins: [vue()],

  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },

  server: {
  proxy: {
    '/data': {
      target: 'https://data.fore-skore.com',
      changeOrigin: true,
      rewrite: p => p.replace(/^\/data/, ''),
      },
    },
  },

})
