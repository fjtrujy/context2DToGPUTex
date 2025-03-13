import { defineConfig } from 'vite';

export default defineConfig({
    assetsInclude: ['**/*.wgsl'],
    server: {
        https: false, // Set to true if you need HTTPS
        host: true, // Expose to all network interfaces
        headers: {
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp'
        }
    }
});
