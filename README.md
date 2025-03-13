# Context2D to GPU Texture Performance Analysis

This project demonstrates and analyzes different methods of copying content from a CPU-based Canvas 2D context to a GPU texture, implemented across multiple modern graphics APIs: WebGL2, WebGPU, and Metal.

🔗 **[Live Demo (Web Implementations)](https://fjtrujy.github.io/context2DToGPUTex/)**

## Overview

The project explores various rendering strategies to understand the performance implications of different approaches to handling canvas content and GPU textures. Each web implementation provides three distinct rendering modes, while the Metal implementation provides native performance benchmarking on macOS.

### WebGL2 Implementation
1. **Two Canvas Mode**: Uses two HTMLCanvasElements - one for WebGL2 rendering and another for Context2D
2. **Canvas and Offscreen Mode**: Combines an HTMLCanvasElement for WebGL2 with an OffscreenCanvas for Context2D
3. **Canvas and Two Offscreen Mode**: Uses an HTMLCanvasElement with BitmapRenderer and two OffscreenCanvas instances for WebGL2 and Context2D

### WebGPU Implementation
1. **Two Canvas Mode**: Uses two HTMLCanvasElements - one for WebGPU rendering and another for Context2D
2. **Canvas and Offscreen Mode**: Combines an HTMLCanvasElement for WebGPU with an OffscreenCanvas for Context2D
3. **Canvas and Two Offscreen Mode**: Uses an HTMLCanvasElement with BitmapRenderer and two OffscreenCanvas instances for WebGPU and Context2D

### Metal Implementation
- Native macOS implementation using Metal for GPU rendering
- Direct comparison with web-based implementations
- Optimized for Apple Silicon and Intel-based Macs
- Requires macOS 12 (Monterey) or later

## Features

- Real-time FPS monitoring
- Dynamic mode switching (Web implementations)
- Start/Stop rendering control
- Automatic fallback for unsupported features
- Cross-browser compatibility (where APIs are supported)
- Native Metal performance on macOS

## System Requirements

### WebGL2 Demo
- Works in most modern browsers
- Requires WebGL2 support

### WebGPU Demo
- Requires Chrome/Edge 113+ or Firefox Nightly with WebGPU enabled
- Fallbacks gracefully when WebGPU is not supported

### Metal Implementation
- Requires macOS 12 (Monterey) or later
- Compatible with both Apple Silicon and Intel Macs
- Xcode 13+ for building from source

## Performance Considerations

The project demonstrates several key performance aspects:
- CPU to GPU texture transfer efficiency
- Impact of OffscreenCanvas usage in web implementations
- BitmapRenderer performance characteristics
- Memory usage patterns across different modes
- Native vs. web-based rendering performance
- Metal optimization on Apple Silicon

## Local Development

### Web Implementations
1. Clone the repository:
```bash
git clone https://github.com/fjtrujy/context2DToGPUTex.git
cd context2DToGPUTex
```

2. Install dependencies for both web implementations:
```bash
# For WebGL2
cd webGL2
yarn install

# For WebGPU
cd ../webGPU
yarn install
```

3. Run development servers:
```bash
# For WebGL2
cd webGL2
yarn dev

# For WebGPU
cd ../webGPU
yarn dev
```

### Metal Implementation
1. Open the Xcode project in the `metal` directory
2. Build and run using Xcode
3. Ensure you're running on macOS 12 or later

## Building for Production

### Web Implementations
```bash
# For WebGL2
cd webGL2
yarn build

# For WebGPU
cd ../webGPU
yarn build
```

### Metal Implementation
Build using Xcode in Release configuration for optimal performance.

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
