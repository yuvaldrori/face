import Toybox.Test;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;
import Toybox.Graphics;

// Mock DC for width testing - needs to inherit from Lang.Object to be valid in Monkey C
class MockDc extends $.Toybox.Lang.Object {
    var drawArcCalls as $.Toybox.Lang.Number = 0;
    
    function getTextWidthInPixels(text as $.Toybox.Lang.String, font as $.Toybox.Graphics.FontDefinition) as $.Toybox.Lang.Number {
        return text.length() * 10; // Simple mock: 10px per character
    }
    
    function drawArc(x as $.Toybox.Lang.Number, y as $.Toybox.Lang.Number, r as $.Toybox.Lang.Number, d as $.Toybox.Graphics.ArcDirection, s as $.Toybox.Lang.Number, e as $.Toybox.Lang.Number) as Void {
        drawArcCalls++;
    }
}

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

(:test)
function testDrawSafeArcSegments(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var mockDc = new MockDc();
    
    // 20 degree arc -> 1 call
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 0, 20);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 1);
    
    // 45 degree arc -> (45/20) + 1 = 3 segments
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 0, 45);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 3);
    
    // 360 degree arc (full circle) -> (360/20) + 1 = 19 segments (since 360/20 is 18.0)
    mockDc.drawArcCalls = 0;
    FaceLogic.drawSafeArc(mockDc as $.Toybox.Graphics.Dc, 130, 130, 125, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 0, 360);
    $.Toybox.Test.assertEqual(mockDc.drawArcCalls, 19);
    
    return true;
}

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

(:test)
function testWrapAngle(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(360), 0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(405), 45);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(-45), 315);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(0), 0);
    $.Toybox.Test.assertEqual(FaceLogic.wrapAngle(180), 180);
    return true;
}

(:test)
function testTimeString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.getTimeString(13, 5), "13:05");
    $.Toybox.Test.assertEqual(FaceLogic.getTimeString(0, 0), "0:00");
    return true;
}

(:test)
function testTemperatureString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.getTemperatureString(25), "25°");
    $.Toybox.Test.assertEqual(FaceLogic.getTemperatureString(null), "--°");
    return true;
}

(:test)
function testHeartRateString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.getHeartRateString(75), "75");
    $.Toybox.Test.assertEqual(FaceLogic.getHeartRateString(null), "--");
    return true;
}

(:test)
function testBatteryColorLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.getBatteryColor(21.0), $.Toybox.Graphics.COLOR_GREEN);
    $.Toybox.Test.assertEqual(FaceLogic.getBatteryColor(20.0), $.Toybox.Graphics.COLOR_RED);
    $.Toybox.Test.assertEqual(FaceLogic.getBatteryColor(5.0), $.Toybox.Graphics.COLOR_RED);
    return true;
}

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

(:test)
function testDatePadding(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var info = new $.Toybox.Time.Gregorian.Info();
    info.year = 2026;
    info.month = 1;
    info.day = 1;
    $.Toybox.Test.assertEqual(FaceLogic.getDateString(info), "2026-01-01");
    return true;
}

(:test)
function testUpdateLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(FaceLogic.needsFullUpdate(59, 0), true);
    $.Toybox.Test.assertEqual(FaceLogic.needsFullUpdate(15, 15), false);
    return true;
}

(:test)
function testWeatherMappingExhaustive(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var conditions = WeatherGenerated.getAllConditions();
    for (var i = 0; i < conditions.size(); i++) {
        var str = WeatherGenerated.getConditionString(conditions[i]);
        $.Toybox.Test.assert(str instanceof $.Toybox.Lang.String);
    }
    return true;
}

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

(:test)
function testLayoutConstants(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // Verify Fenix 8 47mm (260x260) specific geometry
    $.Toybox.Test.assertEqual($.LayoutGenerated.CX, 130);
    $.Toybox.Test.assertEqual($.LayoutGenerated.CY, 130);
    $.Toybox.Test.assertEqual($.LayoutGenerated.ARC_RADIUS, 125);
    $.Toybox.Test.assertEqual($.LayoutGenerated.TOP_Y, 42);
    return true;
}
(:test)
function testPaletteCompleteness(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    var palette = FaceLogic.getRequiredPalette();
    
    // Check Battery Colors
    var lowBatt = FaceLogic.getBatteryColor(10.0);
    var highBatt = FaceLogic.getBatteryColor(50.0);
    
    var foundLow = false;
    var foundHigh = false;
    for (var i = 0; i < palette.size(); i++) {
        if (palette[i] == lowBatt) { foundLow = true; }
        if (palette[i] == highBatt) { foundHigh = true; }
    }
    
    if (!foundLow) { logger.error("Battery LOW color (RED) missing from palette"); return false; }
    if (!foundHigh) { logger.error("Battery HIGH color (GREEN) missing from palette"); return false; }
    
    // Check Solar color (Yellow)
    var foundYellow = false;
    for (var i = 0; i < palette.size(); i++) {
        if (palette[i] == $.Toybox.Graphics.COLOR_YELLOW) { foundYellow = true; }
    }
    if (!foundYellow) { logger.error("Solar color (YELLOW) missing from palette"); return false; }

    return true;
}
