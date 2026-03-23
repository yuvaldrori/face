import Toybox.Test;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;
import Toybox.Graphics;

// Mock DC for width testing - needs to inherit from Lang.Object to be valid in Monkey C
class MockDc extends $.Toybox.Lang.Object {
    function getTextWidthInPixels(text as $.Toybox.Lang.String, font as $.Toybox.Graphics.FontDefinition) as $.Toybox.Lang.Number {
        return text.length() * 10; // Simple mock: 10px per character
    }
}

(:test)
function testHeartRateString(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(faceLogic.getHeartRateString(75), "75");
    $.Toybox.Test.assertEqual(faceLogic.getHeartRateString(null), "--");
    return true;
}

(:test)
function testBatteryColorLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(faceLogic.getBatteryColor(21.0), $.Toybox.Graphics.COLOR_GREEN);
    $.Toybox.Test.assertEqual(faceLogic.getBatteryColor(20.0), $.Toybox.Graphics.COLOR_RED);
    $.Toybox.Test.assertEqual(faceLogic.getBatteryColor(5.0), $.Toybox.Graphics.COLOR_RED);
    return true;
}

(:test)
function testBatteryShortFormat(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(faceLogic.getBatteryDaysShortString(20.5), "20d");
    $.Toybox.Test.assertEqual(faceLogic.getBatteryDaysShortString(1.0), "1d");
    $.Toybox.Test.assertEqual(faceLogic.getBatteryDaysShortString(null), "--d");
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
    var resShort = faceLogic.splitString(shortest, mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
    $.Toybox.Test.assertEqual(resShort[0], shortest);
    $.Toybox.Test.assertEqual(resShort[1], "");

    logger.debug("Testing longest weather string: " + longest);
    var resLong = faceLogic.splitString(longest, mockDc as $.Toybox.Graphics.Dc, $.Toybox.Graphics.FONT_SMALL, maxWidth);
    
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
    $.Toybox.Test.assertEqual(faceLogic.getDateString(info), "2026-01-01");
    return true;
}

(:test)
function testUpdateLogic(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    $.Toybox.Test.assertEqual(faceLogic.needsFullUpdate(59, 0), true);
    $.Toybox.Test.assertEqual(faceLogic.needsFullUpdate(15, 15), false);
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
function testLayoutConstants(logger as $.Toybox.Test.Logger) as $.Toybox.Lang.Boolean {
    // Verify Fenix 8 47mm (260x260) specific geometry
    $.Toybox.Test.assertEqual($.LayoutGenerated.CX, 130);
    $.Toybox.Test.assertEqual($.LayoutGenerated.CY, 130);
    $.Toybox.Test.assertEqual($.LayoutGenerated.ARC_RADIUS, 125);
    $.Toybox.Test.assertEqual($.LayoutGenerated.TOP_Y, 42);
    return true;
}
