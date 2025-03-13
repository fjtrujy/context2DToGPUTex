import { defineConfig } from 'vite';

function getBase() {
    // GitHub Pages
    if (process.env.GITHUB_PAGES === 'true') {
        return '/context2DToGPUTex/webgpu/';
    }
    
    // Local development or preview
    return './';
}

export default defineConfig({
    base: getBase(),
    assetsInclude: ['**/*.wgsl'],
    server: {
        https: undefined, // Set to true if you need HTTPS
        host: true, // Expose to all network interfaces
        headers: {
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp'
        }
    }
});
