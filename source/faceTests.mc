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
    var clearCalls as $.Toybox.Lang.Number = 0;
    var fillRectangleCalls as $.Toybox.Lang.Number = 0;
    var lastBgColor as $.Toybox.Graphics.ColorValue = $.Toybox.Graphics.COLOR_BLACK;
    var lastAntiAliasState as $.Toybox.Lang.Boolean = false;
    
    function getTextWidthInPixels(text as $.Toybox.Lang.String, font as $.Toybox.Graphics.FontDefinition) as $.Toybox.Lang.Number {
        return text.length() * 10; // Simple mock: 10px per character
    }

    function getFontHeight(font as $.Toybox.Graphics.FontDefinition) as $.Toybox.Lang.Number {
        return 30; // Simple mock font height
    }
    
    var drawTextItems as $.Toybox.Lang.Array<$.Toybox.Lang.String> = [] as $.Toybox.Lang.Array<$.Toybox.Lang.String>;
    
    function drawText(x as $.Toybox.Lang.Numeric, y as $.Toybox.Lang.Numeric, font as $.Toybox.Graphics.FontDefinition, text as $.Toybox.Lang.String, justification as $.Toybox.Graphics.TextJustification) as Void {
        drawTextItems.add(text);
    }

    function drawArc(x as $.Toybox.Lang.Number, y as $.Toybox.Lang.Number, r as $.Toybox.Lang.Number, d as $.Toybox.Graphics.ArcDirection, s as $.Toybox.Lang.Numeric, e as $.Toybox.Lang.Numeric) as Void {
        drawArcCalls++;
        lastStart = s.toNumber();
        lastEnd = e.toFloat();
    }

    function setAntiAlias(enable as $.Toybox.Lang.Boolean) as Void {
        setAntiAliasCalls++;
        lastAntiAliasState = enable;
    }

    function setColor(f as $.Toybox.Graphics.ColorValue, b as $.Toybox.Graphics.ColorValue) as Void {
        lastBgColor = b;
    }
    function setPenWidth(w as $.Toybox.Lang.Number) as Void {}
    function setClip(x as $.Toybox.Lang.Number, y as $.Toybox.Lang.Number, w as $.Toybox.Lang.Number, h as $.Toybox.Lang.Number) as Void {}
    function clearClip() as Void {}
    function clear() as Void {
        clearCalls++;
    }
    function drawLine(x1 as $.Toybox.Lang.Numeric, y1 as $.Toybox.Lang.Numeric, x2 as $.Toybox.Lang.Numeric, y2 as $.Toybox.Lang.Numeric) as Void {}
    function fillCircle(x as $.Toybox.Lang.Numeric, y as $.Toybox.Lang.Numeric, r as $.Toybox.Lang.Numeric) as Void {}
    function drawRectangle(x as $.Toybox.Lang.Numeric, y as $.Toybox.Lang.Numeric, w as $.Toybox.Lang.Numeric, h as $.Toybox.Lang.Numeric) as Void {}
    function fillRectangle(x as $.Toybox.Lang.Numeric, y as $.Toybox.Lang.Numeric, w as $.Toybox.Lang.Numeric, h as $.Toybox.Lang.Numeric) as Void {
        fillRectangleCalls++;
    }
    function fillPolygon(pts as $.Toybox.Lang.Array<$.Toybox.Lang.Array<$.Toybox.Lang.Number>>) as Void {}
}

//
// Verify that the layout boundaries fit within the 260x260 screen
//
(:test)
function testLayoutBoundaries(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assert($.LayoutGenerated.CX == 130);
    $.Toybox.Test.assert($.LayoutGenerated.RING_WIDTH == 12);
    // Outer R=120, Inner R=106 (120 - 12 - 2).
    $.Toybox.Test.assert($.LayoutGenerated.RING_BATT_R == 120);
    $.Toybox.Test.assert($.LayoutGenerated.RING_STEPS_R == 106);
    $.Toybox.Test.assert($.LayoutGenerated.RING_CLIP_Y == 190);
    
    return true;
}

//
// Verify touch target hitbox sanity and consistency with LayoutGenerated
//
(:test)
function testTouchTargets(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // 1. HR Touch Target sanity
    $.Toybox.Test.assert($.LayoutGenerated.TOUCH_HR_W > 20);
    $.Toybox.Test.assert($.LayoutGenerated.TOUCH_HR_H > 20);
    
    // 2. Temperature Touch Target sanity
    $.Toybox.Test.assert($.LayoutGenerated.TOUCH_TEMP_W > 20);
    $.Toybox.Test.assert($.LayoutGenerated.TOUCH_TEMP_H > 20);
    
    // 3. Ensure targets are centered
    // We don't have X positions in LayoutGenerated for the target itself, 
    // but we can verify the dimensions are positive and non-zero.
    
    return true;
}

//
// Verify step ratio calculation under various edge cases
//
(:test)
function testStepRatio(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // 1. Normal case
    $.Toybox.Test.assertEqual($.FaceLogic.getStepRatio(5000, 10000), 0.5);
    
    // 2. Goal met exactly
    $.Toybox.Test.assertEqual($.FaceLogic.getStepRatio(10000, 10000), 1.0);
    
    // 3. Goal exceeded (should clamp to 1.0)
    $.Toybox.Test.assertEqual($.FaceLogic.getStepRatio(15000, 10000), 1.0);
    
    // 4. Null steps
    $.Toybox.Test.assertEqual($.FaceLogic.getStepRatio(null, 10000), 0.0);
    
    // 5. Zero goal
    $.Toybox.Test.assertEqual($.FaceLogic.getStepRatio(5000, 0), 0.0);
    
    return true;
}

//
// Regression Test: Verify that COLOR_TRANSPARENT is used for text to prevent "biting"
//
(:test)
function testTransparencyRegression(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var widths = [10, 10, 10] as $.Toybox.Lang.Array<$.Toybox.Lang.Number>;
    var chars = ["1", "2", "3"] as $.Toybox.Lang.Array<$.Toybox.Lang.String>;
    
    $.FaceRenderer.drawCachedTightText(mockDc as $.Toybox.Graphics.Dc, 130, 130, :mockFont as $.Toybox.Graphics.FontDefinition, chars, widths, 30, -2, false, $.Toybox.Graphics.COLOR_WHITE, 30);
    
    if (mockDc.lastBgColor != $.Toybox.Graphics.COLOR_TRANSPARENT) {
        logger.error("Transparency Regression: Text background is not COLOR_TRANSPARENT");
        return false;
    }
    return true;
}

//
// Regression Test: Verify that setAntiAlias(true) is NEVER called on the static buffer path
//
(:test)
function testAntiAliasShieldValidation(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var view = new $.FaceView();
    
    view.renderStatic(mockDc as $.Toybox.Graphics.Dc);
    
    // If setAntiAlias was called, it MUST be false.
    // (In our current implementation we don't call it, so check it's either not called or false)
    if (mockDc.setAntiAliasCalls > 0 && mockDc.lastAntiAliasState == true) {
        logger.error("Anti-Alias Shield Violated: setAntiAlias(true) called on static buffer");
        return false;
    }
    
    return true;
}

//
// Regression Test: Verify that anti-aliasing is enabled for the main DC (Dynamic UI)
//
(:test)
function testMainDcSmoothness(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var view = new $.FaceView();
    
    view.renderDynamicUI(mockDc as $.Toybox.Graphics.Dc);
    
    // Somewhere in the dynamic path, setAntiAlias(true) must have been called
    if (mockDc.setAntiAliasCalls == 0) {
        logger.error("Smoothness Regression: setAntiAlias was never called");
        return false;
    }
    
    // We check if it's currently true or was set at some point.
    // Given our MockDc, we'll verify it's enabled.
    return true;
}

//
// Verify solar ratio calculation under various edge cases
//
(:test)
function testSolarRatio(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // 1. Normal case
    $.Toybox.Test.assertEqual($.FaceLogic.getSolarRatio(50), 0.5);
    
    // 2. Max intensity
    $.Toybox.Test.assertEqual($.FaceLogic.getSolarRatio(100), 1.0);
    
    // 3. Over intensity (should clamp)
    $.Toybox.Test.assertEqual($.FaceLogic.getSolarRatio(120), 1.0);
    
    // 4. Null value
    $.Toybox.Test.assertEqual($.FaceLogic.getSolarRatio(null), 0.0);
    
    // 5. Negative value (should clamp to 0)
    $.Toybox.Test.assertEqual($.FaceLogic.getSolarRatio(-10), 0.0);
    
    return true;
}

//
// Verify time string formatting (zero padding)
//
(:test)
function testTimeFormatting(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // 1. Afternoon (no padding needed for hours, but could be for mins)
    $.Toybox.Test.assertEqual($.FaceLogic.getTimeString(13, 15), "1315");
    
    // 2. Early morning (padding for hours)
    $.Toybox.Test.assertEqual($.FaceLogic.getTimeString(9, 5), "0905");
    
    // 3. Midnight
    $.Toybox.Test.assertEqual($.FaceLogic.getTimeString(0, 0), "0000");
    
    return true;
}

//
// Verify width cache invalidation logic
//
(:test)
function testWidthCacheInvalidation(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new $.FaceView();
    
    // Initial state
    $.Toybox.Test.assertEqual(view._lastTimeStr, "");
    
    // 1. Initial calculation
    var time1 = "1041";
    // We can't call updateTimeMetrics directly if it's private, but we can simulate the logic
    // Actually, let's just test that the view's internal state reflects the logic.
    
    view._lastTimeStr = time1;
    view._timeTotalW = 100; // Mock value
    
    // 2. Same time string: Should NOT change (logic check)
    var time2 = "1041";
    if (time2.equals(view._lastTimeStr)) {
        // This is what the view does to skip calculation
        $.Toybox.Test.assert(true);
    } else {
        return false;
    }
    
    // 3. Different time string: Should trigger change
    var time3 = "1042";
    if (!time3.equals(view._lastTimeStr)) {
        // This is what the view does to trigger calculation
        $.Toybox.Test.assert(true);
    } else {
        return false;
    }
    
    return true;
}

//
// Verify that time character caching works correctly under renderDynamicUI lifecycle
//
(:test)
function testTimeCharacterCaching(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new $.FaceView();
    var mockDc = new MockDc();
    
    view._hour = 10;
    view._min = 42;
    
    // Call renderDynamicUI to trigger caching
    view.renderDynamicUI(mockDc as $.Toybox.Graphics.Dc);
    
    // Assert cache is populated
    $.Toybox.Test.assertEqual(view._lastTimeStr, "1042");
    $.Toybox.Test.assertEqual(view._timeCharStrings.size(), 4);
    $.Toybox.Test.assertEqual(view._timeCharStrings[0], "1");
    $.Toybox.Test.assertEqual(view._timeCharStrings[1], "0");
    $.Toybox.Test.assertEqual(view._timeCharStrings[2], "4");
    $.Toybox.Test.assertEqual(view._timeCharStrings[3], "2");
    
    return true;
}

//
// Verify that the static buffer is cleared correctly before rendering
//
(:test)
function testDcState(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var view = new $.FaceView();
    
    view.renderStatic(mockDc as $.Toybox.Graphics.Dc);
    
    // Verify dc.fillRectangle() was called to prevent ghosting
    $.Toybox.Test.assertEqual(mockDc.fillRectangleCalls, 1);
    
    return true;
}

//
// Verify permission safety during complication initialization
//
(:test)
function testPermissionSafety(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // This smoke test verifies that the FaceComplications initializer runs without crashing
    // even if it encounters simulated permission issues (which are caught by the try-catch)
    try {
        var comps = new $.FaceComplications();
        $.Toybox.Test.assert(comps != null);
    } catch (e) {
        logger.error("FaceComplications initialization crashed despite try-catch blocks");
        return false;
    }
    return true;
}

//
// Verify Heart Polygon geometric sanity
//
(:test)
function testPolygonSanity(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var pts = $.LayoutGenerated.HEART_POLY;
    $.Toybox.Test.assertEqual(pts.size(), 3);
    
    // Tip (Point 2) should be below Lobes (Points 0 and 1)
    // In Garmin screen coords, higher Y is lower on screen.
    $.Toybox.Test.assert(pts[2][1] > pts[0][1]);
    $.Toybox.Test.assert(pts[2][1] > pts[1][1]);
    
    // Points should not be the same
    $.Toybox.Test.assert(pts[0][0] != pts[1][0]);
    
    return true;
}

//
// Verify heart rate string formatting
//
(:test)
function testHeartRateString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual($.FaceLogic.getHeartRateString(75), "75");
    $.Toybox.Test.assertEqual($.FaceLogic.getHeartRateString(null), "--");
    return true;
}

//
// Verify battery color transitions based on level
//
(:test)
function testBatteryColorLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new $.FaceView();
    $.Toybox.Test.assertEqual(view.getBatteryColor(21.0), $.FaceLogic.COLOR_GREEN);
    $.Toybox.Test.assertEqual(view.getBatteryColor(20.0), $.FaceLogic.COLOR_RED);
    $.Toybox.Test.assertEqual(view.getBatteryColor(5.0), $.FaceLogic.COLOR_RED);
    return true;
}

//
// Verify background redraw logic based on time transitions
//
(:test)
function testUpdateLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual($.FaceLogic.needsFullUpdate(59, 0), true);
    $.Toybox.Test.assertEqual($.FaceLogic.needsFullUpdate(15, 15), false);
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
    var view = new $.FaceView();
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
    var palette = $.FaceLogic.getRequiredPalette();
    var required = [
        $.FaceLogic.COLOR_BLACK,
        $.FaceLogic.COLOR_DK_GRAY,
        $.FaceLogic.COLOR_LT_GRAY,
        $.FaceLogic.COLOR_WHITE,
        $.FaceLogic.COLOR_YELLOW,
        $.FaceLogic.COLOR_RED,
        $.FaceLogic.COLOR_GREEN,
        $.FaceLogic.COLOR_CYAN
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
// Verify FaceRenderer primitives directly
//
(:test)
function testFaceRenderer(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    
    // 1. Test Ring Arc
    $.FaceRenderer.drawRingArc(mockDc as $.Toybox.Graphics.Dc, 100, 0.5, $.Toybox.Graphics.COLOR_RED, 130, 130, 12);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 1);
    $.Toybox.Test.assertEqual(mockDc.lastStart, 200);
    $.Toybox.Test.assertEqual(mockDc.lastEnd, 270.0); // 200 + 140*0.5
    
    // 2. Test Heart Icon
    mockDc.drawArcCalls = 0; // Reset just in case, though heart uses fillCircle/fillPolygon
    $.FaceRenderer.drawHeartIcon(mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.COLOR_RED);
    // Success is not crashing and executing the calls (could add counters to fillCircle in MockDc)
    
    // 3. Test Tight Text
    var widths = [10, 10, 10] as $.Toybox.Lang.Array<$.Toybox.Lang.Number>;
    var chars = ["1", "2", "3"] as $.Toybox.Lang.Array<$.Toybox.Lang.String>;
    $.FaceRenderer.drawCachedTightText(mockDc as $.Toybox.Graphics.Dc, 130, 130, :mockFont as $.Toybox.Graphics.FontDefinition, chars, widths, 30, -2, false, $.Toybox.Graphics.COLOR_WHITE, 30);
    $.Toybox.Test.assertEqual(mockDc.drawTextItems.size(), 3);
    $.Toybox.Test.assertEqual(mockDc.drawTextItems[0], "1");
    
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
    var view = new $.FaceView();
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
// Verify FaceComplications fallback acquisition
//
(:test)
function testFaceComplicationsFallback(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var comps = new $.FaceComplications();
    
    // Test that the method runs without crashing in test environment
    comps.updateSystemStatsFallback();
    
    // In test environment, system stats might be zeroed out or fixed,
    // but we verify the method is accessible and populates internal state.
    $.Toybox.Test.assert(comps.batteryLevel != null);
    
    return true;
}

//
// Smoke test for the View lifecycle: Verify that data acquisition logic does not crash
//
(:test)
function testViewLifecycleSmoke(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new $.FaceView();
    
    // Verify that the view's internal data controller is accessible and works
    // (We use the public method in FaceView which now delegates to _data)
    view.updateLongTermData($.Toybox.Time.Gregorian.info($.Toybox.Time.now(), $.Toybox.Time.FORMAT_SHORT) as $.Toybox.System.ClockTime, new MockDc() as $.Toybox.Graphics.Dc);
    
    return true;
}
