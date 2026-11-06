import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['logo-senco-32.png', 'logo-senco-96.png'],
      manifest: {
        name: 'Despesas Senco',
        short_name: 'Despesas',
        description: 'Envio de despesas para o financeiro da Senco',
        lang: 'pt-BR',
        start_url: '/',
        display: 'standalone',
        theme_color: '#211261',
        background_color: '#FFFFFF',
        icons: [
          { src: 'logo-senco-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'logo-senco-512.png', sizes: '512x512', type: 'image/png' },
        ],
      },
    }),
  ],
  server: {
    proxy: { '/api': 'http://localhost:3000' },
  },
});
