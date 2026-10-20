import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// the @wasichai packages are links into ../../wasichai-ui: one copy of each shared library, or hooks break
const shared = ['react', 'react-dom', 'react-router', '@tanstack/react-query', 'i18next', 'react-i18next', 'maplibre-gl']

export default defineConfig({
    plugins: [react(), tailwindcss()],
    resolve: { dedupe: shared },
    optimizeDeps: { include: shared },
    server: {
        port: 5173,
        proxy: { '/api': process.env.API_URL ?? 'http://localhost:8090' }
    },
    preview: {
        port: 4173,
        proxy: { '/api': process.env.API_URL ?? 'http://localhost:8090' }
    }
})
