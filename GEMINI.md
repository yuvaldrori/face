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

## 2. Rendering Strategy & optimization

### The "Fenix 8 Solar Quirk": Partial vs. Full Updates
Research and empirical testing confirmed that `onPartialUpdate` is ineffective on Fenix 8 Solar (System 7/8).
- **Behavior:** The hardware frequently forces a full `onUpdate` refresh (1Hz) even when in low-power mode, bypassing the partial clipping state.
- **Strategy (Minimal Full Redraw):** Instead of fighting for partial updates, we use a "Minimal Full Redraw" model:
    - **Static Background Buffer:** A 4-bit (16-color) `BufferedBitmap` caches the ring tracks, icons, and labels. This is updated only once per minute or on wake.
    - **1Hz Redraw:** The main `onUpdate` loop performs a hardware-accelerated `drawBitmap` of the background and then overlays only the dynamic text (Clock, HR).
    - **Smart Polling:** Heart Rate polling is reduced to **once per minute** (on the minute change) when the watch is in low-power mode (`_isLowPower`). Live 1Hz HR polling occurs only when the user is actively viewing the face.

### Ultra-Safe Arcs (Hardware Stability)
Directly calling `dc.drawArc()` with large spans or crossing the 0/360-degree boundary can trigger a hardware driver failure that renders a muddy "orange circle" artifact.
- **Ultra-Granular Segments:** All arcs are drawn using `drawSafeArc`, breaking segments into **20-degree chunks**.
- **Angle Wrapping:** All angles are strictly wrapped to the `0-360` range.
- **Anti-Aliasing Shield:** Shape primitives (arcs, icons) are drawn with anti-aliasing **OFF** to prevent driver crashes. Anti-aliasing is enabled **ONLY** for fonts.

## 3. Automation & Spatial Math

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

## 5. Quality Assurance

- **Unit Tests:** `source/faceTests.mc` contains geometric validation and string logic tests. 
    - **`testWeatherWrappingExhaustive`**: Programmatically injects every SDK weather condition ID to verify that multi-line wrapping (`_isCondWrapped`) works correctly for all possible strings.
- **Memory Profiling:**
    - **`make heap-check`**: Runs the debug PRG in the simulator with the `-log` flag. This allows monitoring of peak memory usage. Aim to keep the watch face under **96KB** for maximum compatibility.
- **Visual Alignment:**
    - **`make run-align`**: Essential for verifying that bounding boxes correctly match the text offsets (e.g., `yTimeUp`).
- **Target Verification:** Always validate changes on the actual `fenix8solar47mm` hardware. Drivers differ significantly even between 260x260 models.
