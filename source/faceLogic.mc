//
// FaceLogic.mc
// Stateless business logic and geometric calculations
//

import Toybox.Lang;
import Toybox.Graphics;

module FaceLogic {
    
    // Hardware-verified Palette Constants (Saturated for MIP)
    const COLOR_BLACK = $.Toybox.Graphics.COLOR_BLACK as $.Toybox.Graphics.ColorValue;
    const COLOR_DK_GRAY = $.Toybox.Graphics.COLOR_DK_GRAY as $.Toybox.Graphics.ColorValue;
    const COLOR_LT_GRAY = $.Toybox.Graphics.COLOR_LT_GRAY as $.Toybox.Graphics.ColorValue;
    const COLOR_WHITE = $.Toybox.Graphics.COLOR_WHITE as $.Toybox.Graphics.ColorValue;
    const COLOR_YELLOW = 0xFFAA00 as $.Toybox.Graphics.ColorValue; // Amber/Gold
    const COLOR_RED = 0xAA0000 as $.Toybox.Graphics.ColorValue;    // Primary Red
    const COLOR_GREEN = 0x00AA00 as $.Toybox.Graphics.ColorValue;  // Primary Green
    const COLOR_CYAN = 0x00AAFF as $.Toybox.Graphics.ColorValue;   // Vivid Blue/Teal

    // Constants for business logic
    const PERCENT_MAX = 100.0;
    const BATT_THRESHOLD_LOW = 20.0;

    const STR_EMPTY = "";
    const STR_DASHES = "--";
    const STR_TEMP_DASHES = "--°";
    const STR_SPACE = " ";

    //
    // Format temperature as a string
    //
    function getTempString(temp as $.Toybox.Lang.Numeric?) as $.Toybox.Lang.String {
        return (temp != null ? temp.toNumber().toString() + "°" : STR_TEMP_DASHES);
    }

    //
    // Get the required 16-color palette for the static background buffer
    //
    function getRequiredPalette() as $.Toybox.Lang.Array<$.Toybox.Graphics.ColorValue> {
        return [
            COLOR_BLACK,
            COLOR_DK_GRAY,
            COLOR_LT_GRAY,
            COLOR_WHITE,
            COLOR_YELLOW,
            COLOR_RED,
            COLOR_GREEN,
            COLOR_CYAN
        ] as $.Toybox.Lang.Array<$.Toybox.Graphics.ColorValue>;
    }

    //
    // Format hour and minute into a 4-digit string (e.g. 0905)
    //
    function getTimeString(hour as $.Toybox.Lang.Number, min as $.Toybox.Lang.Number) as $.Toybox.Lang.String {
        return $.Toybox.Lang.format("$1$$2$", [hour.format("%02d"), min.format("%02d")]);
    }

    //
    // Format heart rate as a string, handling null values
    //
    function getHeartRateString(rate as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return (rate != null ? rate.toString() : STR_DASHES);
    }

    //
    // Calculate ratio of solar intensity (clamped 0.0 to 1.0)
    //
    function getSolarRatio(intensity as $.Toybox.Lang.Numeric?) as $.Toybox.Lang.Float {
        if (intensity == null) { return 0.0; }
        var floatVal = intensity.toFloat();
        if (floatVal < 0) { return 0.0; }
        return (floatVal > PERCENT_MAX) ? 1.0 : (floatVal / PERCENT_MAX);
    }

    //
    // Calculate ratio of steps vs goal (clamped 0.0 to 1.0)
    //
    function getStepRatio(steps as $.Toybox.Lang.Numeric?, goal as $.Toybox.Lang.Numeric?) as $.Toybox.Lang.Float {
        if (steps == null || goal == null || goal == 0) { return 0.0; }
        var ratio = steps.toFloat() / goal.toFloat();
        return (ratio > 1.0) ? 1.0 : ratio;
    }

    //
    // Get color for steps ring
    //
    function getStepColor() as $.Toybox.Graphics.ColorValue {
        return COLOR_CYAN;
    }

    //
    // Check if a full background update is required based on minute change
    //
    function needsFullUpdate(lastMinute as $.Toybox.Lang.Number, currentMinute as $.Toybox.Lang.Number) as $.Toybox.Lang.Boolean {
        return lastMinute != currentMinute;
    }

}
