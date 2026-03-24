import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Graphics;

module faceLogic {
    // Icons will be drawn manually in faceView.mc to avoid font compatibility issues
    
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

    function getHeartRateString(rate as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return (rate != null ? rate.toString() : "--");
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

    function wrapAngle(angle as $.Toybox.Lang.Number) as $.Toybox.Lang.Number {
        var a = angle;
        while (a < 0) { a += 360; }
        while (a >= 360) { a -= 360; }
        return a;
    }

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
