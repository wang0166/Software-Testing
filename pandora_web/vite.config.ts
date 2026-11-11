import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// 开发代理：浏览器请求 /api 转发到后端，彻底绕开 CORS。
// 后端端口不是 8080 就改下面的 target，或者用后端真实地址。
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  const backend = process.env.VITE_PROXY_TARGET || env.VITE_PROXY_TARGET || 'http://localhost:8080';
  return {
  plugins: [react()],
  server: {
    port: 5174,
    proxy: {
      '/api': {
        target: backend,
        changeOrigin: true,
        secure: false,
      },
    },
  },
  };
});
