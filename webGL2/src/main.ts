import { Renderer } from './Renderer';

// Constants matching the Metal implementation
const COPY_SIZE = { width: 4096, height: 4096 };
const WINDOW_SIZE = { width: 800, height: 600 };

// Get the canvas and resize it
const canvas = document.getElementById('glCanvas') as HTMLCanvasElement;
canvas.width = WINDOW_SIZE.width;
canvas.height = WINDOW_SIZE.height;

// Get UI elements
const fpsElement = document.getElementById('fps') as HTMLDivElement;
const toggleButton = document.getElementById('toggleButton') as HTMLButtonElement;
const contextToggle = document.getElementById('contextToggle') as HTMLButtonElement;
const contextTypeElement = document.getElementById('contextType') as HTMLDivElement;

// Create and start the renderer
const renderer = new Renderer(canvas, COPY_SIZE, (fps: number) => {
    fpsElement.textContent = `FPS: ${fps}`;
});

// Handle toggle button clicks
toggleButton.addEventListener('click', () => {
    renderer.toggle();
    toggleButton.textContent = renderer.isRendering() ? 'Stop' : 'Start';
});

// Handle context type toggle
contextToggle.addEventListener('click', () => {
    const isOffscreen = renderer.toggleContextType();
    contextToggle.textContent = isOffscreen ? 'Switch to Canvas2D' : 'Switch to Offscreen';
    contextTypeElement.textContent = `Context: ${isOffscreen ? 'Offscreen' : 'Canvas2D'}`;
});

// Start the render loop
renderer.start();
