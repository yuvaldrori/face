# Fenix 8 Solar MIP Development Guide

This document serves as the foundational mandate for the development and maintenance of the Fenix 8 47mm Solar MIP (260x260) watch face. 

## 1. Hardware-Specific Constraints (Critical)

The Fenix 8 Solar hardware utilizes a Memory-In-Pixel (MIP) display with a specific graphics driver that exhibits unique behaviors and bugs.

### The "Orange Circle" Rendering Bug (Historical Note)
Directly calling `dc.drawArc()` with large spans or crossing the 0/360-degree boundary was previously reported to trigger a hardware driver failure that renders a muddy "orange circle" artifact. **Per user request, the complex `drawSafeArc` segmentation logic has been removed in favor of direct API calls.**
- **Anti-Aliasing Management:** 
    - **Main DC:** Shape primitives (arcs, circles, lines) must be drawn with `dc.setAntiAlias(false)`. However, **Vector Fonts** MUST use `dc.setAntiAlias(true)` on the Main DC to ensure smooth edges at large scales (180px).
    - **Buffer DC:** Do NOT call `setAntiAlias()` on paletted `BufferedBitmap` objects; these buffers do not support anti-aliasing and will throw an unhandled exception.
- **Rendering Strategy for Text:** To prevent "biting" and jagged edges, large vector fonts (Time display) MUST be rendered to the **Main DC** using `COLOR_TRANSPARENT`. Do not attempt to render large vector fonts into paletted buffers as they lose transparency support and anti-aliasing.

### UI Layering & "Biting"
The display palette is limited. To prevent UI elements (like the Clock) from "biting" into or overwriting the side arcs:
- **Transparency:** All text and icons MUST use `$.Toybox.Graphics.COLOR_TRANSPARENT` as the background color. 
- **Anti-Aliasing for Text:** Anti-aliasing should be enabled **only** during font rendering to ensure smooth text, then immediately disabled for the next frame's shapes.
- **Palette Integrity:** When using a paletted `BufferedBitmap`, all colors returned by rendering logic (e.g., `FaceLogic.getBatteryColor()`) MUST be present in the palette. Missing colors will be mapped by the hardware driver to the "nearest" match, which can cause elements to appear gray or invisible.

## 2. Rendering Strategy & Optimization

### Reactive Data Model & Smart Redraw
The watch face utilizes the **Toybox.Complications** API for primary data streams (Solar, Steps, Battery, Heart Rate). 
- **Gaze-Activated Refresh:** To maximize battery life, background rings (Solar, Steps, Battery) are pre-rendered into a static buffer. This buffer is updated **only** when the user looks at the watch (`onExitSleep`) or when the minute changes.
- **Selective Redraw:** Sensor updates received via `onComplicationChanged` only trigger a background buffer refresh if the watch is NOT in sleep mode.
- **Throttled Fallback:** The `updateSystemStatsFallback()` method is throttled to **5-minute intervals** to prevent redundant CPU wakeups while ensuring data consistency.

### Huge Vector Typography & Caching
To achieve a bold, screen-filling time display that exceeds standard font limits:
- **Vector Fonts:** The time is rendered using `Graphics.getVectorFont` (RobotoCondensedBold) at **180px**.
- **Custom Tracking (Kerning):** Character spacing is manually tightened using a custom rendering loop (e.g., **-14px** tracking via `$.LayoutGenerated.TIME_TRACKING`).
- **Width Caching (Performance):** Vector font width calculations are computationally expensive. Character widths and total string dimensions are **cached once per minute** (or when the time string changes) to minimize per-frame overhead.

### The "Fenix 8 Solar Quirk": Sleep & Focus Detection
Research on actual fenix 8 hardware confirms that Focus Mode flags (like `focusMode == 1`) are not consistently exposed to third-party watch faces.
- **The Standard Trigger:** Sleep visuals (dimming, hiding rings) must rely on the system `doNotDisturb` flag.
- **Lifecycle Sync:** The `onEnterSleep()` and `onExitSleep()` callbacks provide the primary trigger for low-power state transitions, synced with the `_isSleepMode` state.

## 3. Automation & Spatial Math

The project uses a comprehensive `Makefile` to orchestrate the complex build and generation pipeline.

### UI Generation & Static Layout
To maintain peak performance, all UI layout constants MUST be managed via `scripts/generate_layout.sh`.
- **Zero Runtime Math:** Source code (`source/`) MUST NOT perform layout-related arithmetic. This includes character tracking, icon dimensions, heart lobe centers, and ray offsets. All such values must be consumed as pre-calculated constants from `$.LayoutGenerated`.
- **Software Math Only:** The script must perform all geometric and trigonometric calculations using tools (e.g., `awk`). 
- **No Magic Comments:** Never use manual calculations in comments to derive numbers. Every value must be programmatically derived from core display metrics or documented font heights.

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
- **Sync:** The debug bounding boxes for the "Huge" digits must be derived using the same cached width logic as the visual output to ensure absolute parity.

## 5. Quality Assurance

- **Unit Tests:** `source/faceTests.mc` contains geometric validation, reactive logic, and palette integrity tests. 
    - **`testThrottledFallback`**: formally verifies that system data refreshes are restricted to appropriate intervals.
    - **`testStepRatio`**: Validates the math for the Step ring, including null handling and goal over-achievement.
    - **`testPaletteCompleteness`**: Ensures all colors (including **Cyan**) are explicitly defined in the static buffer's 4-bit palette.
- **Memory Profiling:**
    - **`make heap-check`**: Runs the debug PRG in the simulator with the `-log` flag. Aim to keep the watch face under **96KB** for maximum compatibility.
- **Target Verification:** Always validate changes on the actual `fenix8solar47mm` hardware. Drivers differ significantly even between 260x260 models.
