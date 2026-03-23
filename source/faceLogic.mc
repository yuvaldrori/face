import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.Graphics;

module faceLogic {
    // Icons will be drawn manually in faceView.mc to avoid font compatibility issues
    
    function getHeartRateString(rate as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return (rate != null ? rate.toString() : "--");
    }

    function getBatteryString(batteryLevel as $.Toybox.Lang.Float, batteryInDays as $.Toybox.Lang.Float?) as $.Toybox.Lang.String {
        var days = (batteryInDays != null) ? batteryInDays.format("%d") : "--";
        return $.Toybox.Lang.format("$1$ days", [days]);
    }

    function getBatteryDaysShortString(batteryInDays as $.Toybox.Lang.Float?) as $.Toybox.Lang.String {
        return (batteryInDays != null ? batteryInDays.format("%d") : "--") + "d";
    }

    function getBatteryColor(level as $.Toybox.Lang.Float) as $.Toybox.Graphics.ColorValue {
        return (level <= 20.0) ? $.Toybox.Graphics.COLOR_RED : $.Toybox.Graphics.COLOR_GREEN;
    }

    function getTimeString(hour as $.Toybox.Lang.Number, min as $.Toybox.Lang.Number) as $.Toybox.Lang.String {
        return $.Toybox.Lang.format("$1$:$2$", [hour.toString(), min.format("%02d")]);
    }

    function getDateString(info as $.Toybox.Time.Gregorian.Info) as $.Toybox.Lang.String {
        return $.Toybox.Lang.format("$1$-$2$-$3$", [
            info.year.toString(),
            (info.month as $.Toybox.Lang.Number).format("%02d"),
            (info.day as $.Toybox.Lang.Number).format("%02d")
        ]);
    }

    function getTemperatureString(temp as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return $.Toybox.Lang.format("$1$°", [temp != null ? temp.format("%d") : "--"]);
    }

    function needsFullUpdate(lastMinute as $.Toybox.Lang.Number, currentMinute as $.Toybox.Lang.Number) as $.Toybox.Lang.Boolean {
        return lastMinute != currentMinute;
    }

    // Moved from faceView for testability
    function splitString(str as $.Toybox.Lang.String, dc as $.Toybox.Graphics.Dc, font as $.Toybox.Graphics.FontDefinition, maxWidth as $.Toybox.Lang.Number) as [$.Toybox.Lang.String, $.Toybox.Lang.String] {
        var words = [] as Array<String>;
        var currentWord = "";
        for (var i = 0; i < str.length(); i++) {
            var char = str.substring(i, i+1);
            if (char != null && char.equals(" ")) {
                words.add(currentWord);
                currentWord = "";
            } else if (char != null) {
                currentWord += char;
            }
        }
        words.add(currentWord);

        var line1 = "";
        var line2 = "";
        var line1Full = false;

        for (var i = 0; i < words.size(); i++) {
            if (!line1Full) {
                var testLine = (line1.length() == 0) ? words[i] : line1 + " " + words[i];
                if (dc.getTextWidthInPixels(testLine, font) <= maxWidth) {
                    line1 = testLine;
                } else {
                    line1Full = true;
                    line2 = words[i];
                }
            } else {
                line2 = (line2.length() == 0) ? words[i] : line2 + " " + words[i];
            }
        }
        return [line1, line2];
    }
}
