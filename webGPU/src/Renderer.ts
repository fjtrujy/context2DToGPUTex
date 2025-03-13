import { vertexShaderSource, fragmentShaderSource } from './shaders';

export enum RenderMode {
    TwoCanvas,           // 2 HTMLCanvasElement (WebGPU visible + Context2D)
    CanvasAndOffscreen, // 1 HTMLCanvasElement (WebGPU visible) + 1 OffscreenCanvas (Context2D)
    CanvasAndTwoOffscreen // 1 HTMLCanvasElement (BitmapRenderer) + 2 OffscreenCanvas (WebGPU + Context2D)
}

export class Renderer {
    private device!: GPUDevice;
    private context!: GPUCanvasContext;
    private pipeline!: GPURenderPipeline;
    private sampler!: GPUSampler;
    private bindGroup!: GPUBindGroup;
    private texture!: GPUTexture;
    private textureView!: GPUTextureView;
    private canvas2D!: HTMLCanvasElement | OffscreenCanvas;
    private ctx2D!: CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D;
    private visibleCanvas: HTMLCanvasElement;
    private offscreenWebGPU: OffscreenCanvas | null = null;
    private bitmapRenderer: ImageBitmapRenderingContext | null = null;
    private copySize: { width: number; height: number };
    private displaySize: { width: number; height: number };
    private onFPSUpdate: (fps: number) => void;
    private lastFrameTime: number = 0;
    private isRunning: boolean = false;
    private animationFrameId: number | null = null;
    private renderMode: RenderMode = RenderMode.TwoCanvas;
    private frameTimestamps: number[] = [];

    private constructor(
        copySize: { width: number; height: number },
        displaySize: { width: number; height: number },
        onFPSUpdate: (fps: number) => void
    ) {
        this.copySize = copySize;
        this.displaySize = displaySize;
        this.onFPSUpdate = onFPSUpdate;

        // Create initial visible canvas
        this.visibleCanvas = this.createAndSetupCanvas();
        document.body.appendChild(this.visibleCanvas);
    }

    public static async create(
        copySize: { width: number; height: number },
        displaySize: { width: number; height: number },
        onFPSUpdate: (fps: number) => void
    ): Promise<Renderer> {
        const renderer = new Renderer(copySize, displaySize, onFPSUpdate);
        await renderer.setupRenderMode(RenderMode.TwoCanvas);
        return renderer;
    }

    private async initializeWebGPU(canvas: HTMLCanvasElement): Promise<void> {
        if (!navigator.gpu) {
            throw new Error('WebGPU not supported');
        }

        const adapter = await navigator.gpu.requestAdapter();
        if (!adapter) {
            throw new Error('No appropriate GPUAdapter found');
        }

        this.device = await adapter.requestDevice();
        
        // Configure the canvas
        const context = canvas.getContext('webgpu');
        if (!context) {
            throw new Error('WebGPU context not available');
        }
        this.context = context;

        const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
        this.context.configure({
            device: this.device,
            format: canvasFormat,
            alphaMode: 'premultiplied',
        });

        // Create sampler
        this.sampler = this.device.createSampler({
            magFilter: 'linear',
            minFilter: 'linear',
        });

        // Create pipeline
        this.pipeline = this.device.createRenderPipeline({
            layout: 'auto',
            vertex: {
                module: this.device.createShaderModule({
                    code: vertexShaderSource,
                }),
                entryPoint: 'main'
            },
            fragment: {
                module: this.device.createShaderModule({
                    code: fragmentShaderSource,
                }),
                entryPoint: 'main',
                targets: [{
                    format: canvasFormat,
                }],
            },
            primitive: {
                topology: 'triangle-strip',
            },
        });

        // Create texture
        this.texture = this.device.createTexture({
            size: [this.copySize.width, this.copySize.height],
            format: 'rgba8unorm',
            usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
        });
        this.textureView = this.texture.createView();

        // Create bind group
        this.bindGroup = this.device.createBindGroup({
            layout: this.pipeline.getBindGroupLayout(0),
            entries: [
                {
                    binding: 0,
                    resource: this.sampler,
                },
                {
                    binding: 1,
                    resource: this.textureView,
                },
            ],
        });
    }

    private createAndSetupCanvas(): HTMLCanvasElement {
        const canvas = document.createElement('canvas');
        canvas.width = this.displaySize.width;
        canvas.height = this.displaySize.height;
        return canvas;
    }

    private async setupRenderMode(mode: RenderMode): Promise<void> {
        this.renderMode = mode;

        // Clean up existing resources
        if (this.offscreenWebGPU) {
            this.offscreenWebGPU = null;
        }
        if (this.bitmapRenderer) {
            this.bitmapRenderer = null;
        }

        // Remove current visible canvas and create a new one
        this.visibleCanvas.remove();
        this.visibleCanvas = this.createAndSetupCanvas();
        document.body.appendChild(this.visibleCanvas);

        // Setup based on mode
        switch (mode) {
            case RenderMode.TwoCanvas: {
                // Create Context2D canvas
                const canvas2D = document.createElement('canvas');
                canvas2D.width = this.copySize.width;
                canvas2D.height = this.copySize.height;
                const ctx = canvas2D.getContext('2d');
                if (!ctx) throw new Error('2D context not supported');
                this.canvas2D = canvas2D;
                this.ctx2D = ctx;

                // Setup WebGPU on the visible canvas
                await this.initializeWebGPU(this.visibleCanvas);
                break;
            }
            case RenderMode.CanvasAndOffscreen: {
                // Create Context2D offscreen canvas
                const offscreenCanvas = new OffscreenCanvas(this.copySize.width, this.copySize.height);
                const ctx = offscreenCanvas.getContext('2d');
                if (!ctx) throw new Error('Offscreen 2D context not supported');
                this.canvas2D = offscreenCanvas;
                this.ctx2D = ctx;

                // Setup WebGPU on the visible canvas
                await this.initializeWebGPU(this.visibleCanvas);
                break;
            }
            case RenderMode.CanvasAndTwoOffscreen: {
                // Create Context2D offscreen canvas
                const offscreenCanvas = new OffscreenCanvas(this.copySize.width, this.copySize.height);
                const ctx = offscreenCanvas.getContext('2d');
                if (!ctx) throw new Error('Offscreen 2D context not supported');
                this.canvas2D = offscreenCanvas;
                this.ctx2D = ctx;

                // Create WebGPU offscreen canvas
                this.offscreenWebGPU = new OffscreenCanvas(this.displaySize.width, this.displaySize.height);
                await this.initializeWebGPU(this.visibleCanvas);

                // Setup bitmap renderer on the visible canvas
                const bitmapRenderer = this.visibleCanvas.getContext('bitmaprenderer');
                if (!bitmapRenderer) throw new Error('BitmapRenderer not supported');
                this.bitmapRenderer = bitmapRenderer;
                break;
            }
        }
    }

    public async cycleRenderMode(): Promise<RenderMode> {
        const wasRunning = this.isRunning;
        if (wasRunning) {
            this.stop();
        }

        // Cycle through modes
        const nextMode = (this.renderMode + 1) % 3;
        await this.setupRenderMode(nextMode);

        if (wasRunning) {
            this.start();
        }

        return this.renderMode;
    }

    public getCurrentMode(): RenderMode {
        return this.renderMode;
    }

    private updateTexture(): void {
        // Copy Canvas2D content to WebGPU texture
        this.device.queue.copyExternalImageToTexture(
            { source: this.canvas2D },
            { texture: this.texture },
            [this.copySize.width, this.copySize.height]
        );

        // Get the current texture view for rendering
        const currentTextureView = this.context.getCurrentTexture().createView();

        // Create command encoder
        const commandEncoder = this.device.createCommandEncoder();
        const renderPass = commandEncoder.beginRenderPass({
            colorAttachments: [{
                view: currentTextureView,
                clearValue: { r: 1.0, g: 0.0, b: 0.0, a: 1.0 },
                loadOp: 'clear',
                storeOp: 'store',
            }],
        });

        // Draw the quad
        renderPass.setPipeline(this.pipeline);
        renderPass.setBindGroup(0, this.bindGroup);
        renderPass.draw(4, 1, 0, 0);
        renderPass.end();

        // Submit commands
        this.device.queue.submit([commandEncoder.finish()]);
    }

    private transferToBitmapRenderer(): void {
        if (!this.bitmapRenderer || !this.offscreenWebGPU) {
            return;
        }

        const bitmap = this.offscreenWebGPU.transferToImageBitmap();
        this.bitmapRenderer.transferFromImageBitmap(bitmap);
    }

    private drawFrame(): void {
        if (!this.isRunning) return;

        // Update 2D canvas content
        this.fillCanvas2DRandomColor();

        // Update texture and render
        this.updateTexture();
        
        // If using bitmap renderer, transfer the WebGPU result
        if (this.renderMode === RenderMode.CanvasAndTwoOffscreen) {
            this.transferToBitmapRenderer();
        }
        
        // Update FPS
        this.updateFPS();

        // Request next frame
        this.animationFrameId = requestAnimationFrame(() => this.drawFrame());
    }

    private fillCanvas2DRandomColor(): void {
        const red = Math.random();
        const green = Math.random();
        const blue = Math.random();

        // Fill background
        this.ctx2D.fillStyle = `rgb(${red * 255}, ${green * 255}, ${blue * 255})`;
        this.ctx2D.fillRect(0, 0, this.copySize.width, this.copySize.height);

        // Draw text
        this.ctx2D.fillStyle = `rgb(${(1 - red) * 255}, ${(1 - green) * 255}, ${(1 - blue) * 255})`;
        this.ctx2D.font = `${this.copySize.width / 10}px system-ui`;
        const text = 'Hello, World!';
        const metrics = this.ctx2D.measureText(text);
        const x = (this.copySize.width - metrics.width) / 2;
        const y = this.copySize.height / 2;
        this.ctx2D.fillText(text, x, y);
    }

    private updateFPS(): void {
        const currentTime = performance.now();
        
        // Add current timestamp
        this.frameTimestamps.push(currentTime);
        
        // Remove timestamps older than 1 second
        const oneSecondAgo = currentTime - 1000;
        while (this.frameTimestamps.length > 0 && this.frameTimestamps[0] < oneSecondAgo) {
            this.frameTimestamps.shift();
        }
        
        // Update FPS display only once per second
        if (currentTime - this.lastFrameTime >= 1000) {
            // Calculate average FPS over the last second
            const fps = this.frameTimestamps.length;
            this.onFPSUpdate(fps);
            this.lastFrameTime = currentTime;
        }
    }

    public start(): void {
        if (!this.isRunning) {
            this.isRunning = true;
            
            // Recreate and setup visible canvas if needed
            if (!document.body.contains(this.visibleCanvas)) {
                this.visibleCanvas = this.createAndSetupCanvas();
                document.body.appendChild(this.visibleCanvas);
                
                // Re-setup the appropriate context
                if (this.renderMode === RenderMode.CanvasAndTwoOffscreen) {
                    const bitmapRenderer = this.visibleCanvas.getContext('bitmaprenderer');
                    if (!bitmapRenderer) throw new Error('BitmapRenderer not supported');
                    this.bitmapRenderer = bitmapRenderer;
                } else {
                    this.initializeWebGPU(this.visibleCanvas).catch(error => {
                        console.error('Failed to initialize WebGPU:', error);
                        this.stop();
                    });
                }
            }

            this.drawFrame();
        }
    }

    public stop(): void {
        if (this.isRunning) {
            this.isRunning = false;
            if (this.animationFrameId !== null) {
                cancelAnimationFrame(this.animationFrameId);
                this.animationFrameId = null;
            }
        }
    }

    public toggle(): void {
        if (this.isRunning) {
            this.stop();
        } else {
            this.start();
        }
    }

    public isRendering(): boolean {
        return this.isRunning;
    }
}

console.log('GPU:', navigator.gpu);
console.log('User Agent:', navigator.userAgent);
