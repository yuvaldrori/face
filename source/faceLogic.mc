//
// FaceLogic.mc
// Stateless business logic and geometric calculations
//

import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Graphics;

module FaceLogic {
    
    //
    // Get the required 16-color palette for the static background buffer
    //
    function getRequiredPalette() as Array<$.Toybox.Graphics.ColorValue> {
        return [
            $.Toybox.Graphics.COLOR_BLACK,
            $.Toybox.Graphics.COLOR_DK_GRAY,
            $.Toybox.Graphics.COLOR_LT_GRAY,
            $.Toybox.Graphics.COLOR_WHITE,
            $.Toybox.Graphics.COLOR_YELLOW,
            $.Toybox.Graphics.COLOR_RED,
            $.Toybox.Graphics.COLOR_GREEN
        ];
    }

    //
    // Format heart rate as a string, handling null values
    //
    function getHeartRateString(rate as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return (rate != null ? rate.toString() : "--");
    }

    //
    // Determine battery color based on remaining percentage
    //
    function getBatteryColor(level as $.Toybox.Lang.Float) as $.Toybox.Graphics.ColorValue {
        return (level <= 20.0) ? $.Toybox.Graphics.COLOR_RED : $.Toybox.Graphics.COLOR_GREEN;
    }

    //
    // Format time string (HH:mm)
    //
    function getTimeString(hour as $.Toybox.Lang.Number, min as $.Toybox.Lang.Number) as $.Toybox.Lang.String {
        return $.Toybox.Lang.format("$1$:$2$", [hour.toString(), min.format("%02d")]);
    }

    //
    // Format date string (YYYY-MM-DD)
    //
    function getDateString(info as $.Toybox.Time.Gregorian.Info) as $.Toybox.Lang.String {
        return $.Toybox.Lang.format("$1$-$2$-$3$", [
            info.year.toString(),
            (info.month as $.Toybox.Lang.Number).format("%02d"),
            (info.day as $.Toybox.Lang.Number).format("%02d")
        ]);
    }

    //
    // Format temperature string with degree symbol
    //
    function getTemperatureString(temp as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return $.Toybox.Lang.format("$1$°", [temp != null ? temp.format("%d") : "--"]);
    }

    //
    // Check if a full background update is required based on minute change
    //
    function needsFullUpdate(lastMinute as $.Toybox.Lang.Number, currentMinute as $.Toybox.Lang.Number) as $.Toybox.Lang.Boolean {
        return lastMinute != currentMinute;
    }

    //
    // Strictly wrap an angle into the 0-360 range for hardware driver stability
    //
    function wrapAngle(angle as $.Toybox.Lang.Number) as $.Toybox.Lang.Number {
        var a = angle;
        while (a < 0) { a += 360; }
        while (a >= 360) { a -= 360; }
        return a;
    }

    //
    // Draw an arc in 20-degree segments to prevent the Fenix 8 Solar driver bug
    //
    function drawSafeArc(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, radius as Number, direction as $.Toybox.Graphics.ArcDirection, start as Number, end as Number) as Void {
        var totalAngle = 0;
        if (direction == Graphics.ARC_COUNTER_CLOCKWISE) {
            totalAngle = end - start;
        } else {
            totalAngle = start - end;
        }
        while (totalAngle < 0) { totalAngle += 360; }
        if (totalAngle <= 0) { return; }

        if (totalAngle <= 20) {
            dc.drawArc(x, y, radius, direction, wrapAngle(start), wrapAngle(end));
        } else {
            var segments = (totalAngle / 20.0).toNumber() + 1;
            var step = totalAngle.toFloat() / segments.toFloat();
            var current = start.toFloat();
            for (var i = 0; i < segments; i++) {
                var next = (direction == Graphics.ARC_COUNTER_CLOCKWISE) ? (current + step) : (current - step);
                dc.drawArc(x, y, radius, direction, wrapAngle(current.toNumber()), wrapAngle(next.toNumber()));
                current = next;
            }
        }
    }

    //
    // Split a string into two lines based on a maximum pixel width
    //
    function splitString(str as $.Toybox.Lang.String, dc as $.Toybox.Graphics.Dc, font as $.Toybox.Graphics.FontDefinition, maxWidth as $.Toybox.Lang.Number) as [$.Toybox.Lang.String, $.Toybox.Lang.String] {
        var words = [] as Array<String>;
        var remaining = str;
        var spaceIdx = remaining.find(" ");
        
        while (spaceIdx != null) {
            words.add(remaining.substring(0, spaceIdx) as String);
            remaining = remaining.substring(spaceIdx + 1, remaining.length()) as String;
            spaceIdx = remaining.find(" ");
        }
        words.add(remaining);

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
