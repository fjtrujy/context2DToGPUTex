import { Renderer, RenderMode } from './Renderer';

// Constants matching the Metal implementation
const COPY_SIZE = { width: 4096, height: 4096 };
const WINDOW_SIZE = { width: 800, height: 600 };

// Get UI elements
const fpsElement = document.getElementById('fps') as HTMLDivElement;
const toggleButton = document.getElementById('toggleButton') as HTMLButtonElement;
const contextToggle = document.getElementById('contextToggle') as HTMLButtonElement;
const contextTypeElement = document.getElementById('contextType') as HTMLDivElement;

// Update context type display
function updateContextDisplay(mode: RenderMode) {
    let modeName: string;
    switch (mode) {
        case RenderMode.TwoCanvas:
            modeName = 'HTMLCanvas for Context2D and WebGPU';
            break;
        case RenderMode.CanvasAndOffscreen:
            modeName = 'HTMLCanvas for Context2D and OffscreenCanvas for WebGPU';
            break;
        case RenderMode.CanvasAndTwoOffscreen:
            modeName = 'HTMLCanvas for BitmapRenderer and 2x OffscreenCanvas for WebGPU and Context2D';
            break;
    }
    contextTypeElement.textContent = `Mode: ${modeName}`;
}

async function init() {
    try {
        // Create and start the renderer
        const renderer = await Renderer.create(COPY_SIZE, WINDOW_SIZE, (fps: number) => {
            fpsElement.textContent = `FPS: ${fps}`;
        });

        // Handle toggle button clicks
        toggleButton.addEventListener('click', () => {
            renderer.toggle();
            toggleButton.textContent = renderer.isRendering() ? 'Stop' : 'Start';
        });

        // Handle context type toggle
        contextToggle.addEventListener('click', async () => {
            const newMode = await renderer.cycleRenderMode();
            updateContextDisplay(newMode);
        });

        // Set initial context display
        updateContextDisplay(renderer.getCurrentMode());

        // Start the render loop
        renderer.start();
    } catch (error) {
        console.error('Failed to initialize:', error);
        contextTypeElement.textContent = 'WebGPU not supported';
        toggleButton.disabled = true;
        contextToggle.disabled = true;
    }
}

init();
