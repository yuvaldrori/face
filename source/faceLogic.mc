import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

module faceLogic {

    function getHeartRateString(rate as Number?) as String {
        return "❤️ " + (rate != null ? rate.toString() : "--");
    }

    function getBatteryString(batteryLevel as Float, batteryInDays as Float?) as String {
        var indicator = (batteryLevel <= 25.0) ? "🪫" : "🔋";
        var days = (batteryInDays != null) ? batteryInDays.format("%d") : "--";
        return indicator + " " + days + " days";
    }

    function getTimeString(hour as Number, min as Number) as String {
        return hour.toString() + ":" + min.format("%02d");
    }

    function getDateString(info as Gregorian.Info) as String {
        return info.year.toString() + "-" + 
               (info.month as Number).format("%02d") + "-" + 
               (info.day as Number).format("%02d");
    }

    function getTemperatureString(temp as Number?) as String {
        return (temp != null ? temp.format("%d") : "--") + "°";
    }

    function needsFullUpdate(lastMinute as Number, currentMinute as Number) as Boolean {
        return lastMinute != currentMinute;
    }
}
