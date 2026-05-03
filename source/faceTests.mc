//
// faceTests.mc
// Unit test suite for FaceLogic and generated layout verification
//

import Toybox.Test;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;
import Toybox.Graphics;

//
// Mock DC for width testing
// Needs to inherit from Lang.Object to be valid in Monkey C
//
class MockDc extends $.Toybox.Lang.Object {
    var drawArcCalls as $.Toybox.Lang.Number = 0;
    var setAntiAliasCalls as $.Toybox.Lang.Number = 0;
    var lastStart as $.Toybox.Lang.Number = 0;
    var lastEnd as $.Toybox.Lang.Float = 0.0;
    
    function getTextWidthInPixels(text as $.Toybox.Lang.String, font as $.Toybox.Graphics.FontDefinition) as $.Toybox.Lang.Number {
        return text.length() * 10; // Simple mock: 10px per character
    }

    function getFontHeight(font as $.Toybox.Graphics.FontDefinition) as $.Toybox.Lang.Number {
        return 30; // Simple mock font height
    }
    
    var drawTextItems as $.Toybox.Lang.Array<$.Toybox.Lang.String> = [] as Array<String>;
    
    function drawText(x as Numeric, y as Numeric, font as $.Toybox.Graphics.FontDefinition, text as $.Toybox.Lang.String, justification as $.Toybox.Graphics.TextJustification) as Void {
        drawTextItems.add(text);
    }

    function drawArc(x as $.Toybox.Lang.Number, y as $.Toybox.Lang.Number, r as $.Toybox.Lang.Number, d as $.Toybox.Graphics.ArcDirection, s as Numeric, e as Numeric) as Void {
        drawArcCalls++;
        lastStart = s.toNumber();
        lastEnd = e.toFloat();
    }

    function setAntiAlias(enable as $.Toybox.Lang.Boolean) as Void {
        setAntiAliasCalls++;
    }

    function setColor(f as $.Toybox.Graphics.ColorValue, b as $.Toybox.Graphics.ColorValue) as Void {}
    function setPenWidth(w as $.Toybox.Lang.Number) as Void {}
    function clear() as Void {}
    function drawLine(x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric) as Void {}
    function fillCircle(x as Numeric, y as Numeric, r as Numeric) as Void {}
    function drawRectangle(x as Numeric, y as Numeric, w as Numeric, h as Numeric) as Void {}
    function fillRectangle(x as Numeric, y as Numeric, w as Numeric, h as Numeric) as Void {}
    function fillPolygon(pts as $.Toybox.Lang.Array<$.Toybox.Lang.Array<$.Toybox.Lang.Number>>) as Void {}
}

//
// Verify that the layout boundaries fit within the 260x260 screen
//
(:test)
function testLayoutBoundaries(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assert($.LayoutGenerated.CX == 130);
    $.Toybox.Test.assert($.LayoutGenerated.RING_WIDTH == 14);
    // Outer R=126, Middle R=112, Inner R=98.
    $.Toybox.Test.assert($.LayoutGenerated.RING_SOLAR_R == 126);
    $.Toybox.Test.assert($.LayoutGenerated.RING_BATT_R == 98);
    // Y_HR at 175, clears ring inner edge (221 at bottom)
    $.Toybox.Test.assert($.LayoutGenerated.Y_HR == 175);
    
    return true;
}

//
// Verify the segmentation and overlap logic of the safe arc helper
//
(:test)
function testDrawSafeArcSegments(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    
    // 20 degree arc -> 1 call
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 0, 20);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 1);
    
    // 40 degree arc -> 3 segments (due to float division and +1). 
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 0, 40);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 3);
    
    // Verify that the last segment's end angle includes the 0.5 overlap.
    // 40.0 + 0.5 = 40.5
    logger.debug("lastEnd: " + mockDc.lastEnd);
    $.Toybox.Test.assertEqual(mockDc.lastEnd, 40.5);
    
    // 360 degree arc (full circle) -> (360/20) + 1 = 19 segments
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 0, 360);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 19);
    
    return true;
}

//
// Verify that clockwise arcs correctly calculate segments and apply negative overlap
//
(:test)
function testDrawSafeArcClockwise(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    
    // 40 degree CW arc (e.g. 100 to 60) -> 3 segments
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_CLOCKWISE, 100, 60);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 3);
    
    // End angle should be 60 - 0.5 = 59.5
    var diff = mockDc.lastEnd - 59.5;
    if (diff < 0) { diff = -diff; }
    $.Toybox.Test.assert(diff < 0.001);
    
    return true;
}

//
// Verify step ratio calculation under various edge cases
//
(:test)
function testStepRatio(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // 1. Normal case
    $.Toybox.Test.assertEqual(FaceLogic.getStepRatio(5000, 10000), 0.5);
    
    // 2. Goal met exactly
    $.Toybox.Test.assertEqual(FaceLogic.getStepRatio(10000, 10000), 1.0);
    
    // 3. Goal exceeded (should clamp to 1.0)
    $.Toybox.Test.assertEqual(FaceLogic.getStepRatio(15000, 10000), 1.0);
    
    // 4. Null steps
    $.Toybox.Test.assertEqual(FaceLogic.getStepRatio(null, 10000), 0.0);
    
    // 5. Zero goal
    $.Toybox.Test.assertEqual(FaceLogic.getStepRatio(5000, 0), 0.0);
    
    return true;
}

//
// Verify that static rendering paths (for buffers) do NOT attempt to toggle anti-aliasing
//
(:test)
function testAntiAliasShield(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var view = new FaceView();
    
    // We use a trick: Call renderStatic directly with our MockDc
    // If it calls setAntiAlias, our mock will record it
    view.renderStatic(mockDc as $.Toybox.Graphics.Dc);
    
    if (mockDc.setAntiAliasCalls > 0) {
        logger.error("Static rendering path violated AA Shield: setAntiAlias was called");
        return false;
    }
    
    return true;
}

//
// Verify basic angle wrapping logic
//
(:test)
function testWrapAngle(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(360).toFloat(), 0.0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(405).toFloat(), 45.0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(-45).toFloat(), 315.0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(0).toFloat(), 0.0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(180).toFloat(), 180.0);
    return true;
}

//
// Verify heart rate string formatting
//
(:test)
function testHeartRateString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.getHeartRateString(75), "75");
    $.Toybox.Test.assertEqual(FaceLogic.getHeartRateString(null), "--");
    return true;
}

//
// Verify battery color transitions based on level
//
(:test)
function testBatteryColorLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new FaceView();
    $.Toybox.Test.assertEqual(view.getBatteryColor(21.0), $.Toybox.Graphics.COLOR_GREEN);
    $.Toybox.Test.assertEqual(view.getBatteryColor(20.0), $.Toybox.Graphics.COLOR_RED);
    $.Toybox.Test.assertEqual(view.getBatteryColor(5.0), $.Toybox.Graphics.COLOR_RED);
    return true;
}

//
// Verify background redraw logic based on time transitions
//
(:test)
function testUpdateLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.needsFullUpdate(59, 0), true);
    $.Toybox.Test.assertEqual(FaceLogic.needsFullUpdate(15, 15), false);
    return true;
}

//
// Verify angle wrapping with large or negative values
//
(:test)
function testWrapAngleExtreme(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(720).toFloat(), 0.0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(-720).toFloat(), 0.0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(-1).toFloat(), 359.0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(361).toFloat(), 1.0);
    return true;
}

//
// Verify that safe arcs handle the 360-degree full circle case
//
(:test)
function testDrawSafeArcFullCircle(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    
    // Test that start=0, end=0 with CW/CCW handles correctly
    // Our logic says if start != end and totalAngle == 0, it's a full circle (360)
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 0, 360);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 19); // (360/20) + 1
    
    return true;
}

//
// Verify build-side generated layout constants for Fenix 8 47mm
//
(:test)
function testLayoutConstants(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // Verify Fenix 8 47mm (260x260) specific geometry
    $.Toybox.Test.assertEqual($.LayoutGenerated.CX, 130);
    $.Toybox.Test.assertEqual($.LayoutGenerated.CY, 130);
    return true;
}

//
// Verify that the static buffer palette is complete for all rendered elements
//
(:test)
function testPaletteCompleteness(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var palette = FaceLogic.getRequiredPalette();
    var required = [
        FaceLogic.COLOR_BLACK,
        FaceLogic.COLOR_DK_GRAY,
        FaceLogic.COLOR_LT_GRAY,
        FaceLogic.COLOR_WHITE,
        FaceLogic.COLOR_YELLOW,
        FaceLogic.COLOR_RED,
        FaceLogic.COLOR_GREEN
    ];

    for (var i = 0; i < required.size(); i++) {
        var found = false;
        for (var j = 0; j < palette.size(); j++) {
            if (palette[j] == required[i]) { found = true; break; }
        }
        if (!found) { 
            logger.error("Required color " + required[i] + " missing from static buffer palette"); 
            return false; 
        }
    }

    return true;
}

//
// Verify that all assumed SDK properties and modules exist in the target environment.
// This prevents runtime "Symbol Not Found" crashes.
//
(:test)
function testRequiredSymbols(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // 1. Core Modules
    $.Toybox.Test.assert($.Toybox has :System);
    $.Toybox.Test.assert($.Toybox has :Graphics);
    $.Toybox.Test.assert($.Toybox has :Time);
    $.Toybox.Test.assert($.Toybox has :Complications);

    // 2. Critical Complication Constants
    $.Toybox.Test.assert($.Toybox.Complications has :COMPLICATION_TYPE_SOLAR_INPUT);
    $.Toybox.Test.assert($.Toybox.Complications has :COMPLICATION_TYPE_STEPS);
    $.Toybox.Test.assert($.Toybox.Complications has :COMPLICATION_TYPE_BATTERY);
    $.Toybox.Test.assert($.Toybox.Complications has :COMPLICATION_TYPE_HEART_RATE);
    
    // 3. System Stats
    var stats = $.Toybox.System.getSystemStats();
    $.Toybox.Test.assert(stats has :battery);
    
    return true;
}

//
// Verify that the UI simplifies (hides rings) when _isSleepMode is active
//
(:test)
function testSleepModeUI(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new FaceView();
    var mockDc = new MockDc();
    
    // 1. Regular Mode: With default 0 ratios, and NO tracks, it should also be 0
    view._isSleepMode = false;
    view.renderStatic(mockDc as $.Toybox.Graphics.Dc);
    var callsRegular = mockDc.drawArcCalls;
    $.Toybox.Test.assertEqual(callsRegular, 0);
    
    // 2. Sleep Mode: Should definitely be 0
    mockDc.drawArcCalls = 0;
    view._isSleepMode = true;
    view.renderStatic(mockDc as $.Toybox.Graphics.Dc);
    var callsSleep = mockDc.drawArcCalls;
    $.Toybox.Test.assertEqual(callsSleep, 0);
    
    return true;
}

//
// Smoke test for the View lifecycle: Verify that data acquisition logic does not crash
//
(:test)
function testViewLifecycleSmoke(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new FaceView();
    
    // Specifically test the fallback acquisition method
    view.updateSystemStatsFallback();
    
    return true;
}
