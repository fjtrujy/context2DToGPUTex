import { vertexShaderSource, fragmentShaderSource } from './shaders';

export class Renderer {
    private gl: WebGL2RenderingContext;
    private program: WebGLProgram;
    private texture: WebGLTexture;
    private canvas2D: HTMLCanvasElement;
    private ctx2D: CanvasRenderingContext2D;
    private copySize: { width: number; height: number };
    private onFPSUpdate: (fps: number) => void;
    private lastFrameTime: number = 0;

    constructor(
        canvas: HTMLCanvasElement,
        copySize: { width: number; height: number },
        onFPSUpdate: (fps: number) => void
    ) {
        this.copySize = copySize;
        this.onFPSUpdate = onFPSUpdate;

        // Initialize WebGL2
        const gl = canvas.getContext('webgl2');
        if (!gl) {
            throw new Error('WebGL2 not supported');
        }
        this.gl = gl;

        // Create and setup the 2D canvas
        this.canvas2D = document.createElement('canvas');
        this.canvas2D.width = copySize.width;
        this.canvas2D.height = copySize.height;
        const ctx = this.canvas2D.getContext('2d');
        if (!ctx) {
            throw new Error('2D context not supported');
        }
        this.ctx2D = ctx;

        // Create and setup the shader program
        this.program = this.createShaderProgram();

        // Create and setup the texture
        this.texture = this.createTexture();

        // Set viewport
        gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
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
        if (this.lastFrameTime !== 0) {
            const deltaTime = currentTime - this.lastFrameTime;
            const fps = Math.round(1000 / deltaTime);
            this.onFPSUpdate(fps);
        }
        this.lastFrameTime = currentTime;
    }

    public drawFrame(): void {
        // Update 2D canvas content
        this.fillCanvas2DRandomColor();

        // Copy 2D canvas to WebGL texture
        this.gl.bindTexture(this.gl.TEXTURE_2D, this.texture);
        this.gl.texImage2D(
            this.gl.TEXTURE_2D,
            0,
            this.gl.RGBA,
            this.gl.RGBA,
            this.gl.UNSIGNED_BYTE,
            this.canvas2D
        );

        // Clear the canvas
        this.gl.clearColor(0.0, 0.0, 0.0, 1.0);
        this.gl.clear(this.gl.COLOR_BUFFER_BIT);

        // Use our shader program
        this.gl.useProgram(this.program);

        // Draw
        this.gl.drawArrays(this.gl.TRIANGLE_STRIP, 0, 4);

        // Update FPS
        this.updateFPS();

        // Request next frame
        requestAnimationFrame(() => this.drawFrame());
    }
}
