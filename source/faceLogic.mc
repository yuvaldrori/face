//
// FaceLogic.mc
// Stateless business logic and geometric calculations
//

import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Graphics;

module FaceLogic {
    
    // Hardware-verified Palette Constants
    const COLOR_BLACK = $.Toybox.Graphics.COLOR_BLACK as $.Toybox.Graphics.ColorValue;
    const COLOR_DK_GRAY = $.Toybox.Graphics.COLOR_DK_GRAY as $.Toybox.Graphics.ColorValue;
    const COLOR_LT_GRAY = $.Toybox.Graphics.COLOR_LT_GRAY as $.Toybox.Graphics.ColorValue;
    const COLOR_WHITE = $.Toybox.Graphics.COLOR_WHITE as $.Toybox.Graphics.ColorValue;
    const COLOR_YELLOW = $.Toybox.Graphics.COLOR_YELLOW as $.Toybox.Graphics.ColorValue;
    const COLOR_RED = $.Toybox.Graphics.COLOR_RED as $.Toybox.Graphics.ColorValue;
    const COLOR_GREEN = $.Toybox.Graphics.COLOR_GREEN as $.Toybox.Graphics.ColorValue;

    // Constants for business logic
    const BATT_THRESHOLD_LOW = 20.0;
    const PERCENT_MAX = 100.0;
    const ARC_SEGMENT_DEGREES = 20;
    const FULL_CIRCLE_DEGREES = 360;

    const STR_EMPTY = "";
    const STR_DASHES = "--";
    const STR_TEMP_DASHES = "--°";
    const STR_SPACE = " ";

    //
    // Get the required 16-color palette for the static background buffer
    //
    function getRequiredPalette() as Array<$.Toybox.Graphics.ColorValue> {
        return [
            COLOR_BLACK,
            COLOR_DK_GRAY,
            COLOR_LT_GRAY,
            COLOR_WHITE,
            COLOR_YELLOW,
            COLOR_RED,
            COLOR_GREEN
        ];
    }

    //
    // Format heart rate as a string, handling null values
    //
    function getHeartRateString(rate as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return (rate != null ? rate.toString() : STR_DASHES);
    }

    //
    // Determine battery color based on remaining percentage
    //
    function getBatteryColor(level as $.Toybox.Lang.Float) as $.Toybox.Graphics.ColorValue {
        return (level <= BATT_THRESHOLD_LOW) ? COLOR_RED : COLOR_GREEN;
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
        return (temp != null) ? $.Toybox.Lang.format("$1$°", [temp.format("%d")]) : STR_TEMP_DASHES;
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
        var a = angle % FULL_CIRCLE_DEGREES;
        if (a < 0) { a += FULL_CIRCLE_DEGREES; }
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
        
        totalAngle %= FULL_CIRCLE_DEGREES;
        if (totalAngle < 0) { totalAngle += FULL_CIRCLE_DEGREES; }
        if (totalAngle == 0 && start != end) { totalAngle = FULL_CIRCLE_DEGREES; } // Handle full circle case
        if (totalAngle <= 0) { return; }

        if (totalAngle <= ARC_SEGMENT_DEGREES) {
            dc.drawArc(x, y, radius, direction, wrapAngle(start), wrapAngle(end));
        } else {
            var segments = (totalAngle / (ARC_SEGMENT_DEGREES * 1.0)).toNumber() + 1;
            var step = totalAngle.toFloat() / segments.toFloat();
            var current = start.toFloat();
            for (var i = 0; i < segments; i++) {
                var next = (direction == Graphics.ARC_COUNTER_CLOCKWISE) ? (current + step) : (current - step);
                // Add 0.5 degree overlap to prevent pixel gaps on MIP displays
                var overlap = (direction == Graphics.ARC_COUNTER_CLOCKWISE) ? 0.5 : -0.5;
                dc.drawArc(x, y, radius, direction, wrapAngle(current.toNumber()), wrapAngle((next + overlap).toNumber()));
                current = next;
            }
        }
    }

    //
    // Split a string into two lines based on a maximum pixel width
    //
    function splitString(str as $.Toybox.Lang.String, dc as $.Toybox.Graphics.Dc, font as $.Toybox.Graphics.FontDefinition, maxWidth as $.Toybox.Lang.Number) as [$.Toybox.Lang.String, $.Toybox.Lang.String] {
        var words = [] as Array<String>;
        var searchStart = 0;
        var spaceIdx = str.find(STR_SPACE);
        
        while (spaceIdx != null) {
            var word = str.substring(searchStart, spaceIdx);
            if (word != null && word.length() > 0) {
                words.add(word);
            }
            searchStart = spaceIdx + 1;
            var remaining = str.substring(searchStart, str.length());
            if (remaining != null) {
                spaceIdx = remaining.find(STR_SPACE);
                if (spaceIdx != null) {
                    spaceIdx += searchStart;
                }
            } else {
                spaceIdx = null;
            }
        }
        
        var lastWord = str.substring(searchStart, str.length());
        if (lastWord != null && lastWord.length() > 0) {
            words.add(lastWord);
        }

        var line1 = STR_EMPTY;
        var line2 = STR_EMPTY;
        var line1Full = false;
        if (words.size() == 0) { return [STR_EMPTY, STR_EMPTY]; }

        for (var i = 0; i < words.size(); i++) {
            if (!line1Full) {
                var testLine = (line1.length() == 0) ? words[i] : line1 + STR_SPACE + words[i];
                if (dc.getTextWidthInPixels(testLine, font) <= maxWidth) {
                    line1 = testLine;
                } else {
                    if (line1.length() == 0) {
                        line1 = words[i];
                        line1Full = true;
                    } else {
                        line1Full = true;
                        line2 = words[i];
                    }
                }
            } else {
                line2 = (line2.length() == 0) ? words[i] : line2 + STR_SPACE + words[i];
            }
        }
        return [line1, line2];
    }
}
