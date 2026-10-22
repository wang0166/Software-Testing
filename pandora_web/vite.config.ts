import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// 开发代理：浏览器请求 /api 转发到后端，彻底绕开 CORS。
// 后端端口不是 8080 就改下面的 target，或者用后端真实地址。
const BACKEND = process.env.VITE_PROXY_TARGET || 'http://localhost:8080';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5174,
    proxy: {
      '/api': {
        target: BACKEND,
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
