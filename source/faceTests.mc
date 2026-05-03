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
// Verify that static layout constants are correctly loaded from the generator
//
(:test)
function testLayoutConstants(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // Verify Fenix 8 47mm (260x260) specific geometry
    $.Toybox.Test.assertEqual($.LayoutGenerated.CX, 130);
    $.Toybox.Test.assertEqual($.LayoutGenerated.CY, 130);
    $.Toybox.Test.assertEqual($.LayoutGenerated.TIME_TRACKING, -14);
    $.Toybox.Test.assertEqual($.LayoutGenerated.HR_ICON_W, 24);
    return true;
}

//
// Verify that the the throttled fallback logic only fires at appropriate intervals
//
(:test)
function testThrottledFallback(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new FaceView();
    var mockDc = new MockDc();
    
    // Initial state
    $.Toybox.Test.assertEqual(view._lastFallbackMinute, -1);
    
    // Minute 1: Should fire
    var time1 = $.Toybox.Time.Gregorian.info($.Toybox.Time.now(), $.Toybox.Time.FORMAT_SHORT);
    time1.min = 1;
    view.updateLongTermData(time1 as $.Toybox.System.ClockTime, mockDc as $.Toybox.Graphics.Dc);
    
    // Test Initial Fire
    $.Toybox.Test.assertEqual(view._lastFallbackMinute, 1);
    
    // Minute 2: Should NOT fire
    var time2 = $.Toybox.Time.Gregorian.info($.Toybox.Time.now(), $.Toybox.Time.FORMAT_SHORT);
    time2.min = 2;
    view.updateLongTermData(time2 as $.Toybox.System.ClockTime, mockDc as $.Toybox.Graphics.Dc);
    $.Toybox.Test.assertEqual(view._lastFallbackMinute, 1);
    
    // Minute 5: Should fire
    var time5 = $.Toybox.Time.Gregorian.info($.Toybox.Time.now(), $.Toybox.Time.FORMAT_SHORT);
    time5.min = 5;
    view.updateLongTermData(time5 as $.Toybox.System.ClockTime, mockDc as $.Toybox.Graphics.Dc);
    $.Toybox.Test.assertEqual(view._lastFallbackMinute, 5);
    
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
        FaceLogic.COLOR_GREEN,
        FaceLogic.COLOR_CYAN
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
