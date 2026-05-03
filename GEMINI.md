# Fenix 8 Solar MIP Development Guide

This document serves as the foundational mandate for the development and maintenance of the Fenix 8 47mm Solar MIP (260x260) watch face. 

## 1. Hardware-Specific Constraints (Critical)

The Fenix 8 Solar hardware utilizes a Memory-In-Pixel (MIP) display with a specific graphics driver that exhibits unique behaviors and bugs.

### The "Orange Circle" Rendering Bug (Historical Note)
Directly calling `dc.drawArc()` with large spans or crossing the 0/360-degree boundary was previously reported to trigger a hardware driver failure that renders a muddy "orange circle" artifact. Per user request, the complex `drawSafeArc` segmentation logic has been removed in favor of direct API calls.
- **Anti-Aliasing Management:** Shape primitives (arcs, circles, lines) must be drawn with `dc.setAntiAlias(false)` on the main display DC. Anti-aliasing on MIP shapes is the primary trigger for driver crashes and color corruption. 
    - **Note:** Do NOT call `setAntiAlias()` on paletted `BufferedBitmap` objects; these buffers do not support anti-aliasing and will throw an unhandled exception if the method is called.

### UI Layering & "Biting"
The display palette is limited. To prevent UI elements (like the Clock) from "biting" into or overwriting the side arcs:
- **Transparency:** All text and icons MUST use `$.Toybox.Graphics.COLOR_TRANSPARENT` as the background color. 
- **Anti-Aliasing for Text:** Anti-aliasing should be enabled **only** during font rendering to ensure smooth text, then immediately disabled for the next frame's shapes.
- **Palette Integrity:** When using a paletted `BufferedBitmap`, all colors returned by rendering logic (e.g., `FaceLogic.getBatteryColor()`) MUST be present in the palette. Missing colors will be mapped by the hardware driver to the "nearest" match, which can cause elements to appear gray or invisible.

## 2. Rendering Strategy & Optimization

### Reactive Data Model (Complications API)
The watch face utilizes the **Toybox.Complications** API for primary data streams (Solar, Steps, Battery, Heart Rate). 
- **Event-Driven:** Data is updated via the `onComplicationChanged` callback, eliminating the power cost of continuous polling.
- **Immediate Redraw:** The App class implements `onSettingsChanged()` to trigger an immediate `requestUpdate()`. This ensures the UI reacts instantly to system toggles like **Do Not Disturb (DND)**.
- **Fallback acquisition:** The `updateSystemStatsFallback()` method ensures data is populated immediately upon startup before the first complication event fires.

### Huge Vector Typography & Tracking
To achieve a bold, screen-filling time display that exceeds standard font limits:
- **Vector Fonts:** The time is rendered using `Graphics.getVectorFont` (RobotoCondensedBold) at **180px**.
- **Custom Tracking (Kerning):** Character spacing is manually tightened using a custom rendering loop (e.g., **-14px** tracking). This ensures the "Huge" digits feel dense and centered.
- **Consolidated Logic:** Rendering and debug overlay calculations MUST use the shared `drawTightText` helper to ensure visual and diagnostic synchronization.

### The "Fenix 8 Solar Quirk": Sleep & Focus Detection
Research on actual fenix 8 hardware confirms that Focus Mode flags (like `focusMode == 1`) are not consistently exposed to third-party watch faces.
- **The Standard Trigger:** Sleep visuals (dimming, hiding rings) must rely on the system `doNotDisturb` flag.
- **Lifecycle Sync:** The `onEnterSleep()` and `onExitSleep()` callbacks provide the primary trigger for low-power state transitions, synced with the `_isSleepMode` state.

## 3. Automation & Spatial Math

The project uses a comprehensive `Makefile` to orchestrate the complex build and generation pipeline.

### Core Targets
- **`make help`**: Displays a comprehensive list of all available build targets and utilities.
- **`make debug` / `make release`**: Standard builds. Automatically trigger the `generate` target first.
- **`make debug-align` / `make run-align`**: Specialized builds that use `debug.jungle` to enable the Alignment Overlay. These are essential for visual verification on hardware.
- **`make test`**: Builds and executes the unit test suite (`source/faceTests.mc`) in the simulator.
- **`make profile`**: Enables the `-k` compiler flag for performance profiling, critical for ensuring the 30ms power budget is maintained.
- **`make generate`**: Manually triggers the layout and weather string generation scripts.

### UI Generation & Static Layout
To maintain peak performance, all UI layout constants MUST be managed via `scripts/generate_layout.sh`.
- **Software Math Only:** The script must perform all geometric and trigonometric calculations using tools (e.g., `awk`). This includes icon dimensions, heart lobe centers, and ray offsets.
- **Zero Runtime Math:** Source code (`source/`) MUST NOT perform layout-related arithmetic. All positions, dimensions, and static geometric structures (like the Heart Polygon) must be consumed as pre-calculated constants from `$.LayoutGenerated`.
- **No Magic Comments:** Never use manual calculations in comments to derive numbers. Every value must be programmatically derived from core display metrics or documented font heights.

### Simulator Management
The Makefile includes robust logic to manage the Garmin Simulator:
- Automatically starts the simulator if it's not running.
- Uses `ss` to wait for port `1234` to be ready before attempting to deploy a PRG.
- Provides `check-sim` and `wait-sim` helpers for CI/CD environments.

## 4. Coding Standards

All contributions must strictly adhere to the [official Garmin Monkey C Coding Conventions](https://developer.garmin.com/connect-iq/monkey-c/coding-conventions/).

### Key Requirements:
- **Naming:** `CamelCase` for Classes/Modules, `camelCase` for functions and public members, and `_underscoreCamelCase` for private member variables.
- **Architecture:** Always call the superclass `initialize()` method on the first line of any `initialize` function.
- **Formatting:** Use 4-space indentation and same-line opening braces.
- **Structure:** Maintain a strict "one class per file" policy.
## 5. Debug & Alignment

The project maintains a professional-grade **Alignment Overlay** to verify geometric precision.
- **Toggle:** Controlled via the `debug_on` / `debug_off` annotations in `monkey.jungle` and `debug.jungle`.
- **Visibility:** Uses high-contrast `COLOR_RED` for crosshairs and **green bounding boxes** for character-level alignment. 
- **Sync:** The debug bounding boxes for the "Huge" digits must be derived using the same `drawTightText` logic as the visual output to ensure absolute parity.

## 6. Quality Assurance

- **Unit Tests:** `source/faceTests.mc` contains geometric validation, reactive logic, and palette integrity tests. 
    - **`testStepRatio`**: Validates the math for the Step ring, including null handling and goal over-achievement.
    - **`testPaletteCompleteness`**: Ensures all colors (including **Cyan**) are explicitly defined in the static buffer's 4-bit palette.
    - **`testRequiredSymbols`**: Verifies the presence of the **Complications** module and its native type constants in the target environment.
- **Memory Profiling:**
...

    - **`make heap-check`**: Runs the debug PRG in the simulator with the `-log` flag. This allows monitoring of peak memory usage. Aim to keep the watch face under **96KB** for maximum compatibility.
- **Visual Alignment:**
    - **`make run-align`**: Essential for verifying that bounding boxes correctly match the text offsets (e.g., `yTimeUp`).
- **Target Verification:** Always validate changes on the actual `fenix8solar47mm` hardware. Drivers differ significantly even between 260x260 models.
