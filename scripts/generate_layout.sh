#!/bin/bash

# Garmin Connect IQ Layout Generator for Fenix 8 47mm Solar (MIP)
# Device Reference: https://developer.garmin.com/connect-iq/reference-guides/device-reference/#fenix8solar47mm

WIDTH=${1:-260}
HEIGHT=${2:-260}
MC_OUT="source/layoutGenerated.mc"

# Core Centers
CX=$((WIDTH / 2))
CY=$((HEIGHT / 2))

# Display Metrics
# Arcs are positioned 5px from the edge to avoid display clipping on some bezel variants
ARC_RADIUS=$((CX - 5))
SCREEN_RADIUS=$((CX - 1))

# Font Specifications (Pixel Heights for Fenix 8 47mm Solar)
# Source: https://developer.garmin.com/connect-iq/reference-guides/device-reference/#fenix8solar47mm
FONT_TIME_H=121   # FONT_NUMBER_THAI_HOT (Bionic Semibold)
FONT_SMALL_H=32   # FONT_SMALL (Roboto Condensed Bold)

# Geometric Layout Formulas:

# 1. TOP_Y: The horizontal line connecting the top-most points of the left/right arcs (at 45 degree angle).
# Calculation: CY - (Radius * sin(45°)) -> CY - (Radius * 0.7071)
# 0.70710678 = sin(45°)
TOP_Y=$(awk "BEGIN { print int($CY - ($ARC_RADIUS * 0.70710678) + 0.5) }")

# 2. ICON_Y: Centered vertically with the Date string for balanced glyph/text alignment.
# Date Y position logic: Top field (Time) + Time height - overlap padding for Date.
DATE_Y=$((TOP_Y + FONT_TIME_H - FONT_SMALL_H))
ICON_Y=$(awk "BEGIN { print int($DATE_Y + ($FONT_SMALL_H / 2) + 0.5) }")

# 3. Dynamic Field Y-Positions (Calculated relative to core metrics)
# Y_HR: Positioned above the clock, within the top arc span.
Y_HR=$(awk "BEGIN { print $TOP_Y - 30 }") 

# Y_TEMP: Positioned at the very bottom, just inside the screen boundary.
# Subtract height and add 1px buffer to ensure it doesn't clip the bottom edge.
Y_TEMP=$(awk "BEGIN { print $HEIGHT - $FONT_SMALL_H + 1 }")

# Y_COND: Positioned above the temperature with standard vertical spacing (26px offset).
Y_COND=$(awk "BEGIN { print $Y_TEMP - 26 }")

# Arcs (Angles in Degrees, standard Connect IQ 0-360 range)
ARC_PEN_WIDTH=6

# Left Arc: Battery (Centered at 180° [West], spanning 90°)
BATT_SPAN=90
BATT_CENTER=180
BATT_TRACK_START=$(awk "BEGIN { print $BATT_CENTER - ($BATT_SPAN / 2) }")
BATT_TRACK_END=$(awk "BEGIN { print $BATT_CENTER + ($BATT_SPAN / 2) }")
BATT_START=$BATT_TRACK_END

# Right Arc: Solar (Centered at 0° [East], spanning 90°)
SOLAR_SPAN=90
SOLAR_CENTER=0
# Note: SOLAR_TRACK_START will be -45 (315), handled by faceLogic.wrapAngle if needed, 
# but we'll calculate it statically for the jungle/generated constants.
SOLAR_TRACK_START=$(awk "BEGIN { start = $SOLAR_CENTER - ($SOLAR_SPAN / 2); if (start < 0) { start += 360 }; print start }")
SOLAR_TRACK_END=$(awk "BEGIN { print $SOLAR_CENTER + ($SOLAR_SPAN / 2) + 360 }") # Handle wrap for logic (405)

# Icon Dimensions (Optimized for readability on MIP)
BATT_W=10
BATT_H=18
BATT_FILL_MAX_H=16
SUN_R=5

# Icon Horizontal Positions (Calculated for symmetrical spacing from edges)
ICON_MARGIN=24
BX=$ICON_MARGIN
SX=$(awk "BEGIN { print $WIDTH - $ICON_MARGIN }")

# Pre-calculate Solar Rays (8 rays, each: x1, y1, x2, y2)
# Generates a static array to eliminate runtime trigonometric overhead.
SOLAR_RAYS_MC="["
for i in {0..7}; do
    ang=$(awk "BEGIN { print $i * 45 * 0.0174532925 }") # degrees to radians
    # Ray span: from R+3 to R+6
    x1=$(awk "BEGIN { print ($ang == 0 ? 8.0 : cos($ang) * 8.0) }")
    y1=$(awk "BEGIN { print ($ang == 0 ? 0 : sin($ang) * 8.0) }")
    x2=$(awk "BEGIN { print ($ang == 0 ? 11.0 : cos($ang) * 11.0) }")
    y2=$(awk "BEGIN { print ($ang == 0 ? 0 : sin($ang) * 11.0) }")
    
    SOLAR_RAYS_MC+="$(printf "[%.1f, %.1f, %.1f, %.1f]," $x1 $y1 $x2 $y2)"
done
SOLAR_RAYS_MC="${SOLAR_RAYS_MC%,}]"

# HR Layout (Static Alignment)
# Logic: Center the [Icon + Gap + Text] group horizontally.
# Approx width for 3-digit HR: 20 (icon) + 6 (gap) + 32 (text) = 58px.
# Start X = CX - (58 / 2) = CX - 29.
# HR_X (Icon Center) = Start X + 10 = CX - 19.
# HR_TEXT_X (Text Start) = Start X + 26 = CX - 3.
HR_X=$(awk "BEGIN { print $CX - 19 }")
HR_TEXT_X=$(awk "BEGIN { print $CX - 3 }")

cat << EOM > "$MC_OUT"
// Auto-generated layout constants for ${WIDTH}x${HEIGHT}
// Target Device: Fenix 8 47mm Solar (MIP)
// Generated on $(date)
module LayoutGenerated {
    const WIDTH = $WIDTH;
    const HEIGHT = $HEIGHT;
    const CX = $CX;
    const CY = $CY;
    const ARC_RADIUS = $ARC_RADIUS;
    const SCREEN_RADIUS = $SCREEN_RADIUS;
    const TOP_Y = $TOP_Y;
    
    const Y_HR = $Y_HR;
    const Y_COND = $Y_COND;
    const Y_TEMP = $Y_TEMP;

    const ARC_PEN_WIDTH = $ARC_PEN_WIDTH;
    const BATT_START = $BATT_START;
    const BATT_TRACK_START = $BATT_TRACK_START;
    const BATT_TRACK_END = $BATT_TRACK_END;
    const SOLAR_TRACK_START = $SOLAR_TRACK_START;
    const SOLAR_TRACK_END = $SOLAR_TRACK_END;

    const BX = $BX;
    const BY = $ICON_Y;
    const SX = $SX;
    const SY = $ICON_Y;

    const BATT_W = $BATT_W;
    const BATT_H = $BATT_H;
    const BATT_FILL_MAX_H = $BATT_FILL_MAX_H;
    const SUN_R = $SUN_R;

    const HR_X = $HR_X;
    const HR_TEXT_X = $HR_TEXT_X;
    
    const MAX_TEXT_WIDTH = 180;
    
    // Geometric constants
    const HEART_POLY = [[-10, -2], [10, -2], [0, 10]];
    const SOLAR_RAYS = $SOLAR_RAYS_MC;
}
EOM

echo "Generated $MC_OUT for ${WIDTH}x${HEIGHT} display."
