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

// Create and start the renderer
const renderer = new Renderer(canvas, COPY_SIZE, (fps: number) => {
    fpsElement.textContent = `FPS: ${fps}`;
});

// Start the render loop
renderer.drawFrame();
