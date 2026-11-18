import { fileURLToPath } from 'node:url';
import react from '@vitejs/plugin-react';
import { defineConfig, loadEnv, type ProxyOptions } from 'vite';

const repoRoot = fileURLToPath(new URL('../../', import.meta.url));

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, repoRoot, ['PORT', 'WEB_API_TARGET']);
  const target = env.WEB_API_TARGET || `http://127.0.0.1:${env.PORT || '3000'}`;
  const apiProxy: ProxyOptions = {
    target,
    changeOrigin: true,
    configure(proxy) {
      // Mark proxy-generated failures without conflating them with API HTTP errors.
      proxy.on('error', (_error, _request, response) => {
        if ('writeHead' in response && !response.headersSent && !response.writableEnded) {
          response.writeHead(502, { 'X-WorldPulse-Proxy-Error': 'upstream-unreachable' }).end();
        }
      });
    },
  };
  const localServer = {
    host: '127.0.0.1',
    port: 5173,
    strictPort: true,
    proxy: { '/api': apiProxy },
  };

  return {
    plugins: [react()],
    server: localServer,
    preview: localServer,
  };
});
