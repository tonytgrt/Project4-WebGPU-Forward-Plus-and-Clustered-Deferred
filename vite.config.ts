import { defineConfig } from 'vite'

export default defineConfig({
    build: {
        target: 'esnext'
    },
    base: process.env.GITHUB_ACTIONS_BASE || '/',
    server: {
        host: '127.0.0.1',
        port: 5173,
        strictPort: true,
        allowedHosts: [
            'webgpu.tonyxtian.com',
            'localhost',
            '127.0.0.1'
        ]
    }
})