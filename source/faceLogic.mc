//
// FaceLogic.mc
// Stateless business logic and geometric calculations
//

import Toybox.Lang;
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
    const COLOR_CYAN = 0x00FFFF as $.Toybox.Graphics.ColorValue;

    // Constants for business logic
    const PERCENT_MAX = 100.0;
    const BATT_THRESHOLD_LOW = 20.0;
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
            COLOR_GREEN,
            COLOR_CYAN
        ];
    }

    //
    // Format heart rate as a string, handling null values
    //
    function getHeartRateString(rate as $.Toybox.Lang.Number?) as $.Toybox.Lang.String {
        return (rate != null ? rate.toString() : STR_DASHES);
    }

    //
    // Calculate ratio of steps vs goal (clamped 0.0 to 1.0)
    //
    function getStepRatio(steps as Numeric?, goal as Numeric?) as Float {
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
