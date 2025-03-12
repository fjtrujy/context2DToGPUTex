import { Renderer } from './Renderer';

// Constants matching the Metal implementation
const COPY_SIZE = { width: 4096, height: 4096 };
const WINDOW_SIZE = { width: 800, height: 600 };

// Get the canvas and resize it
const canvas = document.getElementById('glCanvas') as HTMLCanvasElement;
canvas.width = WINDOW_SIZE.width;
canvas.height = WINDOW_SIZE.height;

// FPS display element
const fpsElement = document.getElementById('fps') as HTMLDivElement;

// Toggle button element
const toggleButton = document.getElementById('toggleButton') as HTMLButtonElement;

// Create and start the renderer
const renderer = new Renderer(canvas, COPY_SIZE, (fps: number) => {
    fpsElement.textContent = `FPS: ${fps}`;
});

// Handle toggle button clicks
toggleButton.addEventListener('click', () => {
    renderer.toggle();
    toggleButton.textContent = renderer.isRendering() ? 'Stop' : 'Start';
});

// Start the render loop
renderer.start();
