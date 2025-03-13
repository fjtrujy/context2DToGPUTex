import { defineConfig } from 'vite';
import glsl from 'vite-plugin-glsl';

function getBase(): string {
    // GitHub Pages
    if (process.env.GITHUB_PAGES === 'true') {
        return '/context2DToGPUTex/webgl2/';
    }

    // Local development or preview
    return './';
}

export default defineConfig({
    base: getBase(),
    plugins: [glsl()],
    server: {
        https: undefined, // Set to true if you need HTTPS
        host: true, // Expose to all network interfaces
        headers: {
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp',
        },
    },
});
