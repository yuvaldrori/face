import Toybox.Test;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

(:test)
function testHeartRateString(logger as Logger) as Boolean {
    Test.assertEqual(faceLogic.getHeartRateString(75), "❤️ 75");
    Test.assertEqual(faceLogic.getHeartRateString(null), "❤️ --");
    return true;
}

(:test)
function testBatteryString(logger as Logger) as Boolean {
    // Low battery
    Test.assertEqual(faceLogic.getBatteryString(15.0, 2.5), "🪫 2 days");
    // High battery
    Test.assertEqual(faceLogic.getBatteryString(80.0, 12.1), "🔋 12 days");
    // Null days
    Test.assertEqual(faceLogic.getBatteryString(50.0, null), "🔋 -- days");
    return true;
}

(:test)
function testTimeString(logger as Logger) as Boolean {
    Test.assertEqual(faceLogic.getTimeString(13, 5), "13:05");
    Test.assertEqual(faceLogic.getTimeString(9, 45), "9:45");
    return true;
}

(:test)
function testDateString(logger as Logger) as Boolean {
    var info = new Gregorian.Info();
    info.day_of_week = "Mon";
    info.month = "Mar";
    info.day = 15;
    info.year = 2026;
    
    Test.assertEqual(faceLogic.getDateString(info), "Mon Mar 15 2026");
    return true;
}

(:test)
function testTemperatureString(logger as Logger) as Boolean {
    Test.assertEqual(faceLogic.getTemperatureString(22), "22°");
    Test.assertEqual(faceLogic.getTemperatureString(null), "--°");
    return true;
}

(:test)
function testUpdateLogic(logger as Logger) as Boolean {
    // Minute changed: Full update
    Test.assertEqual(faceLogic.needsFullUpdate(15, 16), true);
    // Minute same: Partial update
    Test.assertEqual(faceLogic.needsFullUpdate(15, 15), false);
    // New minute: Full update
    Test.assertEqual(faceLogic.needsFullUpdate(-1, 0), true);
    return true;
}

(:test)
function testClipRect(logger as Logger) as Boolean {
    var rect = faceLogic.getHeartRateClipRect(240);
    Test.assertEqual(rect.size(), 4);
    Test.assertEqual(rect[0], 0);   // x
    Test.assertEqual(rect[1], 0);   // y
    Test.assertEqual(rect[2], 240); // width
    Test.assertEqual(rect[3], 30);  // height
    return true;
}

(:test)
function testWeatherMapping(logger as Logger) as Boolean {
    var map = WeatherGenerated.getMap();
    
    // Verify some known keys exist and have correct labels
    var conditions = [
        [Weather.CONDITION_CLEAR, "Clear"],
        [Weather.CONDITION_PARTLY_CLOUDY, "Partly cloudy"],
        [Weather.CONDITION_THUNDERSTORMS, "Thunderstorms"],
        [Weather.CONDITION_UNKNOWN, "Unknown"]
    ];
    
    for (var i = 0; i < conditions.size(); i++) {
        var id = conditions[i][0] as Number;
        var expected = conditions[i][1] as String;
        
        Test.assert(map.hasKey(id));
        var resId = map[id] as ResourceId;
        var actual = WatchUi.loadResource(resId) as String;
        Test.assertEqualMessage(actual, expected, "Condition " + id + " string mismatch");
    }
    
    return true;
}
