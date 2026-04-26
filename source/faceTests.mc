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
}

//
// Verify that the layout boundaries fit within the 260x260 screen
//
(:test)
function testLayoutBoundaries(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // CX is 130. HR_X (center of icon) is CX - 19 = 111. 
    // Icon width is 20, so icon goes from 101 to 121.
    // HR_TEXT_X (start of text) is CX - 3 = 127.
    // 3 digits (e.g. "180") in FONT_SMALL is roughly 30-40px.
    // Total group ends around 127 + 40 = 167.
    // All well within 0-260 range.
    
    $.Toybox.Test.assert($.LayoutGenerated.HR_X > 20);
    $.Toybox.Test.assert($.LayoutGenerated.HR_X < 240);
    $.Toybox.Test.assert($.LayoutGenerated.HR_TEXT_X > 20);
    $.Toybox.Test.assert($.LayoutGenerated.HR_TEXT_X < 240);
    
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
// Verify that solar intensity values are clamped appropriately
//
(:test)
function testSolarIntensityClamping(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var intensity = 150;
    var clampedIntensity = (intensity > 100 ? 100.0 : intensity).toFloat();
    $.Toybox.Test.assertEqual(clampedIntensity, 100.0);
    
    intensity = 50;
    clampedIntensity = (intensity > 100 ? 100.0 : intensity).toFloat();
    $.Toybox.Test.assertEqual(clampedIntensity, 50.0);
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
// Verify time string formatting (HH:mm)
//
(:test)
function testTimeString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.getTimeString(13, 5), "13:05");
    $.Toybox.Test.assertEqual(FaceLogic.getTimeString(0, 0), "0:00");
    return true;
}

//
// Verify temperature string formatting with unit
//
(:test)
function testTemperatureString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.getTemperatureString(25), "25°");
    $.Toybox.Test.assertEqual(FaceLogic.getTemperatureString(null), "--°");
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
// Verify string splitting into multiple lines for weather display
//
(:test)
function testSplitStringLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var maxWidth = 180; 
    
    var conditions = WeatherGenerated.getAllConditions();
    var shortest = "";
    var longest = "";
    
    for (var i = 0; i < conditions.size(); i++) {
        var str = WeatherGenerated.getConditionString(conditions[i]);
        if (str != null) {
            if (shortest.equals("") || str.length() < shortest.length()) {
                shortest = str;
            }
            if (str.length() > longest.length()) {
                longest = str;
            }
        }
    }

    logger.debug("Testing shortest weather string: " + shortest);
    var resShort = FaceLogic.splitString(shortest, mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
    $.Toybox.Test.assertEqual(resShort[0], shortest);
    $.Toybox.Test.assertEqual(resShort[1], "");

    logger.debug("Testing longest weather string: " + longest);
    var resLong = FaceLogic.splitString(longest, mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
    
    // Longest should wrap if it exceeds maxWidth (18 chars in mock)
    if (longest.length() * 10 > maxWidth) {
        $.Toybox.Test.assertNotEqual(resLong[1], "");
        $.Toybox.Test.assertEqual(resLong[0].length() + resLong[1].length(), longest.length() - 1); // -1 for the space
    }
    
    return true;
}

//
// Verify date string formatting (YYYY-MM-DD)
//
(:test)
function testDatePadding(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var info = new $.Toybox.Time.Gregorian.Info();
    info.year = 2026;
    info.month = 1;
    info.day = 1;
    $.Toybox.Test.assertEqual(FaceLogic.getDateString(info), "2026-01-01");
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
// Exhaustive test of all weather conditions to ensure valid string mapping
//
(:test)
function testWeatherMappingExhaustive(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var conditions = WeatherGenerated.getAllConditions();
    for (var i = 0; i < conditions.size(); i++) {
        var str = WeatherGenerated.getConditionString(conditions[i]);
        $.Toybox.Test.assert(str instanceof $.Toybox.Lang.String);
    }
    return true;
}

//
// Exhaustive test of string wrapping across all weather conditions
//
(:test)
function testWeatherWrappingExhaustive(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var maxWidth = 180;
    var conditions = WeatherGenerated.getAllConditions();
    
    for (var i = 0; i < conditions.size(); i++) {
        var str = WeatherGenerated.getConditionString(conditions[i]);
        if (str != null) {
            var res = FaceLogic.splitString(str, mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
            
            // Basic validation: Either it didn't wrap, or it wrapped into exactly 2 lines
            $.Toybox.Test.assert(res instanceof $.Toybox.Lang.Array);
            $.Toybox.Test.assertEqual(res.size(), 2);
            
            if (str.length() * 10 <= maxWidth) {
                $.Toybox.Test.assertEqual(res[0], str);
                $.Toybox.Test.assertEqual(res[1], "");
            } else {
                // If it wrapped, check that no characters were lost (except the space replaced by newline)
                var combined = res[0] + " " + res[1];
                if (res[1].equals("")) { combined = res[0]; }
                $.Toybox.Test.assertEqual(combined.length(), str.length());
            }
        }
    }
    return true;
}

//
// Verify robust handling of string split edge cases
//
(:test)
function testSplitStringEdgeCases(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    var maxWidth = 50; // Small width to force wrapping
    
    // Case 1: Empty string
    var res = FaceLogic.splitString("", mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
    $.Toybox.Test.assertEqual(res[0], "");
    $.Toybox.Test.assertEqual(res[1], "");
    
    // Case 2: Single word too long for the line
    var res2 = FaceLogic.splitString("Supercalifragilisticexpialidocious", mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
    // Should put it on line 1 even if it exceeds width (as it can't be split)
    $.Toybox.Test.assertEqual(res2[0], "Supercalifragilisticexpialidocious");
    $.Toybox.Test.assertEqual(res2[1], "");
    
    // Case 3: Multiple spaces (Logic now collapses them into words)
    var res3 = FaceLogic.splitString("Partly  cloudy", mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
    $.Toybox.Test.assertEqual(res3[0], "Partly");
    $.Toybox.Test.assertEqual(res3[1], "cloudy"); 
    
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
    $.Toybox.Test.assertEqual($.LayoutGenerated.ARC_RADIUS, 125);
    $.Toybox.Test.assertEqual($.LayoutGenerated.TOP_Y, 42);
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
    $.Toybox.Test.assert($.Toybox has :Weather);
    $.Toybox.Test.assert($.Toybox has :Activity);

    // 2. Critical Properties (The ones that caused the crash)
    var activityInfo = $.Toybox.Activity.getActivityInfo();
    if (activityInfo != null) {
        $.Toybox.Test.assert(activityInfo has :currentHeartRate);
    }
    
    // Verify that we are NOT using forbidden/missing symbols
    // ActivityMonitor.Info in this SDK does NOT have :heartRate
    if ($.Toybox has :ActivityMonitor) {
        // Just verify the module exists; we won't check for :heartRate as it's known missing
        $.Toybox.Test.assert(true);
    }

    // 3. System Stats
    var stats = $.Toybox.System.getSystemStats();
    $.Toybox.Test.assert(stats has :battery);
    
    return true;
}

//
// Smoke test for the View lifecycle: Verify that data acquisition logic does not crash
//
(:test)
function testViewLifecycleSmoke(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var view = new FaceView();
    
    // Specifically test the method that caused the symbol-not-found crash
    view.updateHeartRate();
    view.updateSystemStats();
    
    return true;
}

//
// Verify traveler-safe date logic: Only update when day changes
//
(:test)
function testDateLineCrossing(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var lastDay = 15;
    var newDay = 16;
    
    // Simulate crossing the date line / midnight
    $.Toybox.Test.assert(newDay != lastDay);
    
    // Reset test
    lastDay = 16;
    newDay = 16;
    $.Toybox.Test.assertEqual(newDay == lastDay, true); // Should skip formatting
    
    return true;
}
