import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

module faceLogic {

    function getHeartRateString(rate as Number?) as String {
        return Lang.format("❤️ $1$", [rate != null ? rate : "--"]);
    }

    function getBatteryString(batteryLevel as Float, batteryInDays as Float?) as String {
        var indicator = (batteryLevel <= 25.0) ? "🪫" : "🔋";
        var days = (batteryInDays != null) ? batteryInDays.format("%d") : "--";
        return Lang.format("$1$ $2$ days", [indicator, days]);
    }

    function getTimeString(hour as Number, min as Number) as String {
        return Lang.format("$1$:$2$", [hour, min.format("%02d")]);
    }

    function getDateString(info as Gregorian.Info) as String {
        return Lang.format("$1$ $2$ $3$ $4$", [info.day_of_week, info.month, info.day, info.year]);
    }

    function getTemperatureString(temp as Number?) as String {
        if (temp == null) {
            return "--°";
        }
        return Lang.format("$1$°", [temp.format("%d")]);
    }
}
