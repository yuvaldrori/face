#!/bin/bash

# Garmin Connect IQ Layout Generator for Fenix 8 47mm Solar (MIP)
# Main Device Reference: https://developer.garmin.com/connect-iq/device-reference/
# Specific Device Specs: https://developer.garmin.com/connect-iq/device-reference/fenix8solar47mm/

WIDTH=${1:-260}
HEIGHT=${2:-260}
MC_OUT="source/layoutGenerated.mc"

# Core Centers
CX=$(awk "BEGIN { print int($WIDTH / 2) }")
CY=$(awk "BEGIN { print int($HEIGHT / 2) }")

# Math Constants
PI=$(awk "BEGIN { print atan2(0, -1) }")
DEG_TO_RAD=$(awk "BEGIN { print $PI / 180 }")

# Display Metrics
# Arcs are positioned 5px from the edge to avoid display clipping on some bezel variants
ARC_MARGIN=5
ARC_RADIUS=$(awk "BEGIN { print int($CX - $ARC_MARGIN) }")
SCREEN_RADIUS=$(awk "BEGIN { print int($CX - 1) }")

# Font Specifications (Pixel Heights for Fenix 8 47mm Solar)
# Source: https://developer.garmin.com/connect-iq/device-reference/fenix8solar47mm/
FONT_TIME_H=121   # FONT_NUMBER_THAI_HOT (Bionic Semibold)
FONT_SMALL_H=32   # FONT_SMALL (Roboto Condensed Bold)

# Geometric Layout Formulas:

# 1. TOP_Y: The horizontal line connecting the top-most points of the left/right arcs (at 45 degree angle).
# Calculation: CY - (Radius * sin(45°))
SIN_45=$(awk "BEGIN { print sin(45 * $DEG_TO_RAD) }")
TOP_Y=$(awk "BEGIN { print int($CY - ($ARC_RADIUS * $SIN_45) + 0.5) }")

# 2. ICON_Y: Centered vertically with the Date string for balanced glyph/text alignment.
# Date Y position logic: Top field (Time) + Time height - overlap padding for Date.
DATE_Y=$(awk "BEGIN { print int($TOP_Y + $FONT_TIME_H - $FONT_SMALL_H) }")
ICON_Y=$(awk "BEGIN { print int($DATE_Y + ($FONT_SMALL_H / 2) + 0.5) }")

# 3. Dynamic Field Y-Positions (Calculated relative to core metrics)
# Y_HR: Positioned above the clock, within the top arc span.
HR_V_OFFSET=30
Y_HR=$(awk "BEGIN { print int($TOP_Y - $HR_V_OFFSET) }") 

# Y_TEMP: Positioned at the very bottom, just inside the screen boundary.
# Subtract height and add 1px buffer to ensure it doesn't clip the bottom edge.
Y_TEMP=$(awk "BEGIN { print int($HEIGHT - $FONT_SMALL_H + 1) }")

# Y_COND: Positioned above the temperature with standard vertical spacing (26px offset).
COND_V_SPACING=26
Y_COND=$(awk "BEGIN { print int($Y_TEMP - $COND_V_SPACING) }")

# Weather wrap offset (vertical spacing for second line)
COND_WRAP_V_OFFSET=24

# Arcs (Angles in Degrees, standard Connect IQ 0-360 range)
ARC_PEN_WIDTH=6

# Universal Arc Span (Degrees)
DATA_ARC_SPAN=90

# Left Arc: Battery (Centered at 180° [West])
BATT_CENTER=180
BATT_TRACK_START=$(awk "BEGIN { print int($BATT_CENTER - ($DATA_ARC_SPAN / 2)) }")
BATT_TRACK_END=$(awk "BEGIN { print int($BATT_CENTER + ($DATA_ARC_SPAN / 2)) }")
BATT_START=$BATT_TRACK_END

# Right Arc: Solar (Centered at 0° [East])
SOLAR_CENTER=0
SOLAR_TRACK_START=$(awk "BEGIN { start = $SOLAR_CENTER - ($DATA_ARC_SPAN / 2); if (start < 0) { start += 360 }; print int(start) }")
SOLAR_TRACK_END=$(awk "BEGIN { print int($SOLAR_CENTER + ($DATA_ARC_SPAN / 2) + 360) }") # Handle wrap for logic (405)

# Icon Dimensions (Optimized for readability on MIP)
BATT_W=10
BATT_H=18
BATT_FILL_MAX_H=16
BATT_FILL_PADDING_X=1
BATT_FILL_PADDING_Y=1
# Battery Tip Dimensions
BATT_TIP_W=4
BATT_TIP_H=2

SUN_R=5

# Icon Horizontal Positions (Calculated for symmetrical spacing from edges)
ICON_MARGIN=24
BX=$ICON_MARGIN
SX=$(awk "BEGIN { print int($WIDTH - $ICON_MARGIN) }")

# Battery Icon Pre-calculations
BATT_RECT_X=$(awk "BEGIN { print int($BX - ($BATT_W / 2)) }")
BATT_RECT_Y=$(awk "BEGIN { print int($ICON_Y - ($BATT_H / 2)) }")
BATT_TIP_RECT_X=$(awk "BEGIN { print int($BX - ($BATT_TIP_W / 2)) }")
BATT_TIP_RECT_Y=$(awk "BEGIN { print int($BATT_RECT_Y - $BATT_TIP_H) }")
BATT_FILL_X=$(awk "BEGIN { print int($BATT_RECT_X + $BATT_FILL_PADDING_X) }")
BATT_FILL_Y_BASE=$(awk "BEGIN { print int($BATT_RECT_Y + $BATT_H - $BATT_FILL_PADDING_Y) }")
BATT_FILL_W=$(awk "BEGIN { print int($BATT_W - (2 * $BATT_FILL_PADDING_X)) }")

# Pre-calculate Solar Rays (8 rays, each: x1, y1, x2, y2)
# Generates a static array to eliminate runtime trigonometric overhead.
SOLAR_RAYS_MC="["
RAY_INNER_R=$(awk "BEGIN { print $SUN_R + 3 }")
RAY_OUTER_R=$(awk "BEGIN { print $SUN_R + 6 }")
for i in {0..7}; do
    ang=$(awk "BEGIN { print $i * 45 * $DEG_TO_RAD }")
    x1=$(awk "BEGIN { res = cos($ang) * $RAY_INNER_R; printf \"%.1f\", (res > -0.05 && res < 0.05) ? 0 : res }")
    y1=$(awk "BEGIN { res = sin($ang) * $RAY_INNER_R; printf \"%.1f\", (res > -0.05 && res < 0.05) ? 0 : res }")
    x2=$(awk "BEGIN { res = cos($ang) * $RAY_OUTER_R; printf \"%.1f\", (res > -0.05 && res < 0.05) ? 0 : res }")
    y2=$(awk "BEGIN { res = sin($ang) * $RAY_OUTER_R; printf \"%.1f\", (res > -0.05 && res < 0.05) ? 0 : res }")
    
    SOLAR_RAYS_MC+="[$x1, $y1, $x2, $y2],"
done
SOLAR_RAYS_MC="${SOLAR_RAYS_MC%,}]"

# HR Layout (Static Alignment)
# Logic: Center the [Icon + Gap + Text] group horizontally.
HR_ICON_W=20
HR_GAP=6
HR_TEXT_EST_W=32
HR_TOTAL_W=$(awk "BEGIN { print int($HR_ICON_W + $HR_GAP + $HR_TEXT_EST_W) }")
HR_START_X=$(awk "BEGIN { print int($CX - ($HR_TOTAL_W / 2)) }")

HR_X=$(awk "BEGIN { print int($HR_START_X + ($HR_ICON_W / 2)) }")
HR_TEXT_X=$(awk "BEGIN { print int($HR_START_X + $HR_ICON_W + $HR_GAP) }")

# Heart Icon Vertical Alignment
HR_ICON_V_OFFSET=14
HR_ICON_Y=$(awk "BEGIN { print int($Y_HR + $HR_ICON_V_OFFSET) }")

# Heart Lobe Geometry
HEART_LOBE_R=5
HEART_LOBE_OFFSET=5
HEART_POLY_V_OFFSET=2
HEART_POLY_H_OFFSET=10
HEART_POLY_TIP_V=10

# Pre-calculate Heart Polygon
P1_X=$(awk "BEGIN { print int($HR_X - $HEART_POLY_H_OFFSET) }")
P1_Y=$(awk "BEGIN { print int($HR_ICON_Y - $HEART_POLY_V_OFFSET) }")
P2_X=$(awk "BEGIN { print int($HR_X + $HEART_POLY_H_OFFSET) }")
P2_Y=$(awk "BEGIN { print int($HR_ICON_Y - $HEART_POLY_V_OFFSET) }")
P3_X=$(awk "BEGIN { print int($HR_X) }")
P3_Y=$(awk "BEGIN { print int($HR_ICON_Y + $HEART_POLY_TIP_V) }")
HEART_POLY_MC="[[$P1_X, $P1_Y], [$P2_X, $P2_Y], [$P3_X, $P3_Y]]"

# Debug Constants
DEBUG_GUIDE_R=12

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
    const DATE_Y = $DATE_Y;
    const COND_WRAP_V_OFFSET = $COND_WRAP_V_OFFSET;

    const ARC_PEN_WIDTH = $ARC_PEN_WIDTH;
    const BATT_START = $BATT_START;
    const BATT_TRACK_START = $BATT_TRACK_START;
    const BATT_TRACK_END = $BATT_TRACK_END;
    const SOLAR_TRACK_START = $SOLAR_TRACK_START;
    const SOLAR_TRACK_END = $SOLAR_TRACK_END;
    const DATA_ARC_SPAN = $DATA_ARC_SPAN;

    const BX = $BX;
    const BY = $ICON_Y;
    const SX = $SX;
    const SY = $ICON_Y;

    const BATT_W = $BATT_W;
    const BATT_H = $BATT_H;
    const BATT_RECT_X = $BATT_RECT_X;
    const BATT_RECT_Y = $BATT_RECT_Y;
    const BATT_TIP_RECT_X = $BATT_TIP_RECT_X;
    const BATT_TIP_RECT_Y = $BATT_TIP_RECT_Y;
    const BATT_FILL_X = $BATT_FILL_X;
    const BATT_FILL_Y_BASE = $BATT_FILL_Y_BASE;
    const BATT_FILL_W = $BATT_FILL_W;
    const BATT_FILL_MAX_H = $BATT_FILL_MAX_H;
    const BATT_TIP_W = $BATT_TIP_W;
    const BATT_TIP_H = $BATT_TIP_H;
    
    const SUN_R = $SUN_R;

    const HR_X = $HR_X;
    const HR_ICON_W = $HR_ICON_W;
    const HR_GAP = $HR_GAP;
    const HR_ICON_Y = $HR_ICON_Y;
    const HR_TEXT_X = $HR_TEXT_X;
    const HEART_LOBE_R = $HEART_LOBE_R;
    const HEART_LOBE_L_X = $(awk "BEGIN { print int($HR_X - $HEART_LOBE_OFFSET) }");
    const HEART_LOBE_R_X = $(awk "BEGIN { print int($HR_X + $HEART_LOBE_OFFSET) }");
    const HEART_LOBE_Y = $(awk "BEGIN { print int($HR_ICON_Y - $HEART_LOBE_OFFSET) }");
    
    const MAX_TEXT_WIDTH = 180;
    const DEBUG_GUIDE_R = $DEBUG_GUIDE_R;
    
    // Geometric constants
    const HEART_POLY = $HEART_POLY_MC;
    const SOLAR_RAYS = $SOLAR_RAYS_MC;
}
EOM

echo "Generated $MC_OUT for ${WIDTH}x${HEIGHT} display."
