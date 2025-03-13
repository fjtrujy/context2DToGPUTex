import { vertexShaderSource, fragmentShaderSource } from './shaders';

export enum RenderMode {
    TwoCanvas,           // 2 HTMLCanvasElement (WebGL2 visible + Context2D)
    CanvasAndOffscreen, // 1 HTMLCanvasElement (WebGL2 visible) + 1 OffscreenCanvas (Context2D)
    CanvasAndTwoOffscreen // 1 HTMLCanvasElement (BitmapRenderer) + 2 OffscreenCanvas (WebGL2 + Context2D)
}

export class Renderer {
    private gl!: WebGL2RenderingContext;
    private program!: WebGLProgram;
    private texture!: WebGLTexture;
    private canvas2D!: HTMLCanvasElement | OffscreenCanvas;
    private ctx2D!: CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D;
    private visibleCanvas: HTMLCanvasElement;
    private offscreenWebGL: OffscreenCanvas | null = null;
    private bitmapRenderer: ImageBitmapRenderingContext | null = null;
    private copySize: { width: number; height: number };
    private displaySize: { width: number; height: number };
    private onFPSUpdate: (fps: number) => void;
    private lastFrameTime: number = 0;
    private isRunning: boolean = false;
    private animationFrameId: number | null = null;
    private renderMode: RenderMode = RenderMode.TwoCanvas;
    private frameTimestamps: number[] = [];

    constructor(
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

        // Set up initial mode (TwoCanvas)
        this.setupRenderMode(RenderMode.TwoCanvas);
    }

    private createAndSetupCanvas(): HTMLCanvasElement {
        const canvas = document.createElement('canvas');
        canvas.width = this.displaySize.width;
        canvas.height = this.displaySize.height;
        return canvas;
    }

    private setupRenderMode(mode: RenderMode): void {
        this.renderMode = mode;

        // Clean up existing resources
        if (this.offscreenWebGL) {
            this.offscreenWebGL = null;
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

                // Setup WebGL2 on the visible canvas
                const gl = this.visibleCanvas.getContext('webgl2');
                if (!gl) throw new Error('WebGL2 not supported');
                this.gl = gl;
                break;
            }
            case RenderMode.CanvasAndOffscreen: {
                // Create Context2D offscreen canvas
                const offscreenCanvas = new OffscreenCanvas(this.copySize.width, this.copySize.height);
                const ctx = offscreenCanvas.getContext('2d');
                if (!ctx) throw new Error('Offscreen 2D context not supported');
                this.canvas2D = offscreenCanvas;
                this.ctx2D = ctx;

                // Setup WebGL2 on the visible canvas
                const gl = this.visibleCanvas.getContext('webgl2');
                if (!gl) throw new Error('WebGL2 not supported');
                this.gl = gl;
                break;
            }
            case RenderMode.CanvasAndTwoOffscreen: {
                // Create Context2D offscreen canvas
                const offscreenCanvas = new OffscreenCanvas(this.copySize.width, this.copySize.height);
                const ctx = offscreenCanvas.getContext('2d');
                if (!ctx) throw new Error('Offscreen 2D context not supported');
                this.canvas2D = offscreenCanvas;
                this.ctx2D = ctx;

                // Create WebGL2 offscreen canvas with display size
                const offscreenWebGL = new OffscreenCanvas(this.displaySize.width, this.displaySize.height);
                const gl = offscreenWebGL.getContext('webgl2');
                if (!gl) throw new Error('WebGL2 not supported in OffscreenCanvas');
                this.offscreenWebGL = offscreenWebGL;
                this.gl = gl;

                // Setup bitmap renderer on the visible canvas
                const bitmapRenderer = this.visibleCanvas.getContext('bitmaprenderer');
                if (!bitmapRenderer) throw new Error('BitmapRenderer not supported');
                this.bitmapRenderer = bitmapRenderer;
                break;
            }
        }

        // Setup WebGL resources
        this.gl.viewport(0, 0, this.displaySize.width, this.displaySize.height);
        this.program = this.createShaderProgram();
        this.texture = this.createTexture();
    }

    public cycleRenderMode(): RenderMode {
        const wasRunning = this.isRunning;
        if (wasRunning) {
            this.stop();
        }

        // Cycle through modes
        const nextMode = (this.renderMode + 1) % 3;
        this.setupRenderMode(nextMode);

        if (wasRunning) {
            this.start();
        }

        return this.renderMode;
    }

    public getCurrentMode(): RenderMode {
        return this.renderMode;
    }

    private updateTexture(): void {
        this.gl.bindTexture(this.gl.TEXTURE_2D, this.texture);
        
        // Copy Canvas2D content to WebGL texture
        this.gl.texImage2D(
            this.gl.TEXTURE_2D,
            0,
            this.gl.RGBA,
            this.gl.RGBA,
            this.gl.UNSIGNED_BYTE,
            this.canvas2D
        );

        // Render WebGL content
        this.gl.clearColor(1.0, 0.0, 0.0, 1.0);
        this.gl.clear(this.gl.COLOR_BUFFER_BIT);
        this.gl.useProgram(this.program);
        this.gl.drawArrays(this.gl.TRIANGLE_STRIP, 0, 4);
    }

    private transferToBitmapRenderer(): void {
        if (!this.bitmapRenderer || !this.offscreenWebGL) {
            return;
        }

        const bitmap = this.offscreenWebGL.transferToImageBitmap();
        this.bitmapRenderer.transferFromImageBitmap(bitmap);
    }

    private drawFrame(): void {
        if (!this.isRunning) return;

        // Update 2D canvas content
        this.fillCanvas2DRandomColor();

        // Update texture and render
        this.updateTexture();
        
        // If using bitmap renderer, transfer the WebGL result
        if (this.renderMode === RenderMode.CanvasAndTwoOffscreen) {
            this.transferToBitmapRenderer();
        }
        
        // Update FPS
        this.updateFPS();

        // Request next frame
        this.animationFrameId = requestAnimationFrame(() => this.drawFrame());
    }

    private createShaderProgram(): WebGLProgram {
        const vertexShader = this.createShader(this.gl.VERTEX_SHADER, vertexShaderSource);
        const fragmentShader = this.createShader(this.gl.FRAGMENT_SHADER, fragmentShaderSource);

        const program = this.gl.createProgram();
        if (!program) {
            throw new Error('Unable to create shader program');
        }

        this.gl.attachShader(program, vertexShader);
        this.gl.attachShader(program, fragmentShader);
        this.gl.linkProgram(program);

        if (!this.gl.getProgramParameter(program, this.gl.LINK_STATUS)) {
            throw new Error(
                'Unable to initialize the shader program: ' + this.gl.getProgramInfoLog(program)
            );
        }

        // Create and set up vertex buffer
        const vertices = new Float32Array([
            -1.0, -1.0,  // Bottom left
             1.0, -1.0,  // Bottom right
            -1.0,  1.0,  // Top left
             1.0,  1.0   // Top right
        ]);

        const vertexBuffer = this.gl.createBuffer();
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, vertexBuffer);
        this.gl.bufferData(this.gl.ARRAY_BUFFER, vertices, this.gl.STATIC_DRAW);

        // Set up vertex attributes
        const positionAttribLocation = 0; // matches layout(location = 0) in vertex shader
        this.gl.enableVertexAttribArray(positionAttribLocation);
        this.gl.vertexAttribPointer(positionAttribLocation, 2, this.gl.FLOAT, false, 0, 0);

        return program;
    }

    private createShader(type: number, source: string): WebGLShader {
        const shader = this.gl.createShader(type);
        if (!shader) {
            throw new Error('Unable to create shader');
        }

        this.gl.shaderSource(shader, source);
        this.gl.compileShader(shader);

        if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) {
            const error = this.gl.getShaderInfoLog(shader);
            this.gl.deleteShader(shader);
            throw new Error('An error occurred compiling the shaders: ' + error);
        }

        return shader;
    }

    private createTexture(): WebGLTexture {
        const texture = this.gl.createTexture();
        if (!texture) {
            throw new Error('Unable to create texture');
        }

        this.gl.bindTexture(this.gl.TEXTURE_2D, texture);

        // Set the parameters so we can render any size image
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_S, this.gl.CLAMP_TO_EDGE);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_T, this.gl.CLAMP_TO_EDGE);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.LINEAR);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.LINEAR);

        return texture;
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
                    const gl = this.visibleCanvas.getContext('webgl2');
                    if (!gl) throw new Error('WebGL2 not supported');
                    this.gl = gl;
                    // Reinitialize WebGL resources
                    this.gl.viewport(0, 0, this.displaySize.width, this.displaySize.height);
                    this.program = this.createShaderProgram();
                    this.texture = this.createTexture();
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
