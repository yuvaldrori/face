# Fenix 8 Solar MIP Development Guide

This document serves as the foundational mandate for the development and maintenance of the Fenix 8 47mm Solar MIP (260x260) watch face. 

## 1. Hardware-Specific Constraints (Critical)

The Fenix 8 Solar hardware utilizes a Memory-In-Pixel (MIP) display with a specific graphics driver that exhibits unique behaviors and bugs.

### The "Orange Circle" Rendering Bug
Directly calling `dc.drawArc()` with large spans or crossing the 0/360-degree boundary can trigger a hardware driver failure that renders a muddy "orange circle" artifact covering the entire arc track. To prevent this:
- **Ultra-Granular Segments:** All arcs must be drawn using the `drawSafeArc` helper, which breaks segments into tiny **20-degree chunks**.
- **Angle Wrapping:** All angles MUST be strictly wrapped to the `0-360` range before being passed to the hardware. Values like `405` (even for CCW arcs) will trigger artifacts.
- **Anti-Aliasing Management:** Shape primitives (arcs, circles, lines) must be drawn with `dc.setAntiAlias(false)`. Anti-aliasing on MIP shapes is the primary trigger for driver crashes and color corruption.

### UI Layering & "Biting"
The display palette is limited. To prevent UI elements (like the Clock) from "biting" into or overwriting the side arcs:
- **Transparency:** All text and icons MUST use `$.Toybox.Graphics.COLOR_TRANSPARENT` as the background color. 
- **Anti-Aliasing for Text:** Anti-aliasing should be enabled **only** during font rendering to ensure smooth text, then immediately disabled for the next frame's shapes.

## 2. Automation & Optimization

To achieve a "Zero-Math" runtime loop and stay within the 30ms power budget:

### Layout Generation (`scripts/generate_layout.sh`)
- Spatial math (CX, CY, arc tracks, row positions) is pre-calculated at build time.
- The script generates `source/layoutGenerated.mc`. **NEVER** hardcode pixel coordinates in `faceView.mc`. Use the constants in `LayoutGenerated`.

### Weather Condition Strings (`scripts/generate_weather.sh`)
- Weather condition mappings are dynamically extracted from the SDK documentation.
- The script generates `source/weatherGenerated.mc` and the associated string resources.

## 3. Build & Workflow Automation (`Makefile`)

The project uses a comprehensive `Makefile` to orchestrate the complex build and generation pipeline.

### Core Targets
- **`make debug` / `make release`**: Standard builds. Automatically trigger the `generate` target first.
- **`make debug-align` / `make run-align`**: Specialized builds that use `debug.jungle` to enable the Alignment Overlay. These are essential for visual verification on hardware.
- **`make test`**: Builds and executes the unit test suite (`source/faceTests.mc`) in the simulator.
- **`make profile`**: Enables the `-k` compiler flag for performance profiling, critical for ensuring the 30ms power budget is maintained.
- **`make generate`**: Manually triggers the layout and weather string generation scripts.

### Simulator Management
The Makefile includes robust logic to manage the Garmin Simulator:
- Automatically starts the simulator if it's not running.
- Uses `ss` to wait for port `1234` to be ready before attempting to deploy a PRG.
- Provides `check-sim` and `wait-sim` helpers for CI/CD environments.

## 4. Debug & Alignment

The project maintains a professional-grade **Alignment Overlay** to verify geometric precision.
- **Toggle:** Controlled via the `debug_on` / `debug_off` annotations in `monkey.jungle` and `debug.jungle`.
- **Visibility:** Uses high-contrast `COLOR_RED` for crosshairs and `COLOR_GREEN` for bounding boxes. 
- **Sync:** The debug bounding boxes must always be updated to match the active vertical offsets (e.g., `yTimeUp`) used in the main rendering loop.

## 4. Quality Assurance

- **Unit Tests:** `source/faceTests.mc` contains geometric validation tests. Every layout change must be verified by running `make test`.
- **Target Target:** Always validate changes on the actual `fenix8solar47mm` hardware or simulator target. Values that look correct on other 260x260 devices (like Fenix 7) may fail on Fenix 8 due to the driver differences mentioned above.
