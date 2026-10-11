import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// En desarrollo, /api y /v1 van al VPS (mismo origen que en producción tras Traefik).
const target = process.env.DIEGOMUSIC_API ?? 'https://music.diegocainzos.cv'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': { target, changeOrigin: true },
      '/v1': { target, changeOrigin: true },
    },
  },
})
