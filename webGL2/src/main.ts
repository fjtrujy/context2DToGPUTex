import { Renderer, RenderMode } from './Renderer';

// Constants matching the Metal implementation
const WINDOW_SIZE = { width: 800, height: 600 };

type Size = { width: number; height: number };
type SizeKey = '4x' | '2x' | '1x';

// Available sizes for CPU Context
const SIZES: Record<SizeKey, Size> = {
    '4x': { width: 4096, height: 4096 },
    '2x': { width: 2048, height: 2048 },
    '1x': { width: 1024, height: 1024 }
};

// Create UI container
const container = document.createElement('div');
container.id = 'container';
container.style.position = 'fixed';
container.style.top = '10px';
container.style.left = '10px';
container.style.padding = '15px';
container.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
container.style.color = 'white';
container.style.borderRadius = '5px';
container.style.fontFamily = 'system-ui, -apple-system, sans-serif';
container.style.minWidth = '300px';
document.body.appendChild(container);

// Create UI elements
const fpsElement = document.createElement('div');
fpsElement.id = 'fps';
fpsElement.style.fontSize = '24px';
fpsElement.style.fontWeight = 'bold';
fpsElement.style.marginBottom = '15px';

// Create size selector
const sizeSelector = document.createElement('select');
sizeSelector.id = 'sizeSelector';
sizeSelector.style.padding = '5px';
sizeSelector.style.marginLeft = '10px';
sizeSelector.style.borderRadius = '3px';
Object.keys(SIZES).forEach(size => {
    const option = document.createElement('option');
    option.value = size;
    option.text = `${size} (${SIZES[size as SizeKey].width}x${SIZES[size as SizeKey].height})`;
    if (size === '4x') option.selected = true;
    sizeSelector.appendChild(option);
});

// Add size selector container
const sizeContainer = document.createElement('div');
sizeContainer.style.marginBottom = '15px';
sizeContainer.style.display = 'flex';
sizeContainer.style.alignItems = 'center';
const sizeLabel = document.createElement('span');
sizeLabel.textContent = 'Context2D Size:';
sizeContainer.appendChild(sizeLabel);
sizeContainer.appendChild(sizeSelector);

const contextTypeElement = document.createElement('div');
contextTypeElement.id = 'contextType';
contextTypeElement.style.marginBottom = '15px';

// Create buttons with consistent styling
const createStyledButton = (text: string, id: string) => {
    const button = document.createElement('button');
    button.id = id;
    button.textContent = text;
    button.style.padding = '8px 16px';
    button.style.borderRadius = '4px';
    button.style.border = 'none';
    button.style.backgroundColor = '#4CAF50';
    button.style.color = 'white';
    button.style.cursor = 'pointer';
    button.style.width = '100%';
    button.style.marginBottom = '10px';
    button.style.fontSize = '14px';
    return button;
};

const contextToggle = createStyledButton('Next Mode', 'contextToggle');
const toggleButton = createStyledButton('Stop', 'toggleButton');

// Add all elements to container in the specified order
container.appendChild(fpsElement);
container.appendChild(sizeContainer);
container.appendChild(contextTypeElement);
container.appendChild(contextToggle);
container.appendChild(toggleButton);

// Create and start the renderer
let renderer = new Renderer(SIZES['4x'], WINDOW_SIZE, (fps: number) => {
    fpsElement.textContent = `FPS: ${fps}`;
});

// Handle size changes
sizeSelector.addEventListener('change', async () => {
    const wasRunning = renderer.isRendering();
    if (wasRunning) renderer.stop();
    
    // Remove old canvas elements
    const canvases = document.querySelectorAll('canvas');
    canvases.forEach(canvas => canvas.remove());
    
    // Create new renderer with selected size
    const selectedSize = SIZES[sizeSelector.value as SizeKey];
    renderer = new Renderer(selectedSize, WINDOW_SIZE, (fps: number) => {
        fpsElement.textContent = `FPS: ${fps}`;
    });
    
    updateContextDisplay(renderer.getCurrentMode());
    if (wasRunning) renderer.start();
});

// Handle toggle button clicks
toggleButton.addEventListener('click', () => {
    renderer.toggle();
    toggleButton.textContent = renderer.isRendering() ? 'Stop' : 'Start';
    toggleButton.style.backgroundColor = renderer.isRendering() ? '#f44336' : '#4CAF50';
});

// Update context type display
function updateContextDisplay(mode: RenderMode): void {
    let modeName: string;
    switch (mode) {
        case RenderMode.TwoCanvas:
            modeName = 'HTMLCanvas for Context2D and WebGL2';
            break;
        case RenderMode.CanvasAndOffscreen:
            modeName = 'HTMLCanvas for Context2D and OffscreenCanvas for WebGL2';
            break;
        case RenderMode.CanvasAndTwoOffscreen:
            modeName =
                'HTMLCanvas for BitmapRenderer and 2x OffscreenCanvas for WebGL2 and Context2D';
            break;
    }
    contextTypeElement.textContent = `Mode: ${modeName}`;
}

// Handle context type toggle
contextToggle.addEventListener('click', () => {
    const newMode = renderer.cycleRenderMode();
    updateContextDisplay(newMode);
});

// Set initial context display
updateContextDisplay(renderer.getCurrentMode());

// Start the render loop
renderer.start();
