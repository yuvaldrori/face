#!/bin/bash

WIDTH=${1:-260}
HEIGHT=${2:-260}
MC_OUT="source/layoutGenerated.mc"

CX=$((WIDTH / 2))
CY=$((HEIGHT / 2))
# Arcs are 5px in from the edge
ARC_RADIUS=$((CX - 5))
SCREEN_RADIUS=$((CX - 1))

# Formulas:
# 1. TOP_Y: Geometric top limit for the arcs (45 degrees).
TOP_Y=$(awk "BEGIN { print int($CY - ($ARC_RADIUS * 0.70710678) + 0.5) }")

# 2. ICON_Y: Aligned with the center of the date string.
# On Fenix 8 47mm (260x260): 
# FONT_NUMBER_THAI_HOT height is ~96px. FONT_SMALL height is ~26px.
# Date Y = (TOP_Y + TIME_H) - DATE_H = (42 + 96) - 26 = 112.
# Date Center = 112 + (26/2) = 112 + 13 = 125.
ICON_Y=125

# Additional UI positions
Y_HR=12
Y_COND=203
Y_TEMP=229

# Arcs
ARC_PEN_WIDTH=6
BATT_START=225
BATT_TRACK_START=135
BATT_TRACK_END=225
SOLAR_TRACK_START=315
SOLAR_TRACK_END=405 # 315 + 90 (handles wrap-around)

# Icon dimensions (Static)
BATT_W=10
BATT_H=18
BATT_FILL_MAX_H=16
SUN_R=5

# Icon positions
BX=24
BY=$ICON_Y
SX=$((WIDTH - 24))
SY=$ICON_Y

# Pre-calculate Solar Rays (8 rays, each: x1, y1, x2, y2)
SOLAR_RAYS_MC="["
for i in {0..7}; do
    ang=$(awk "BEGIN { print $i * 45 * 0.0174532925 }") # degrees to radians
    x1=$(awk "BEGIN { print ($ang == 0 ? 8.0 : cos($ang) * 8.0) }")
    y1=$(awk "BEGIN { print ($ang == 0 ? 0 : sin($ang) * 8.0) }")
    x2=$(awk "BEGIN { print ($ang == 0 ? 11.0 : cos($ang) * 11.0) }")
    y2=$(awk "BEGIN { print ($ang == 0 ? 0 : sin($ang) * 11.0) }")
    
    # Rounded to 1 decimal place to minimize string size, converted to Number at runtime if needed, 
    # but let's just use int if they are close. Or Float is fine.
    SOLAR_RAYS_MC+="$(printf "[%.1f, %.1f, %.1f, %.1f]," $x1 $y1 $x2 $y2)"
done
SOLAR_RAYS_MC="${SOLAR_RAYS_MC%,}]"

# HR Layout (Static Alignment)
# Assuming typical 2-3 digit HR (average width ~32px)
# Icon (20) + Gap (6) + Text (~32) = 58px total
# CX - (58/2) = CX - 29
HR_X=$((CX - 19)) # Center of 20px icon is 10px from start
HR_TEXT_X=$((CX + 7)) # Start of text (CX - 29 + 20 + 6) = CX - 3, wait.
# Let's re-calculate:
# Start = CX - 29
# Icon Center = Start + 10 = CX - 19
# Text Start = Start + 20 + 6 = CX - 29 + 26 = CX - 3
HR_X=$((CX - 19))
HR_TEXT_X=$((CX - 3))

cat << EOM > "$MC_OUT"
// Auto-generated layout constants for ${WIDTH}x${HEIGHT}
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
    const BY = $BY;
    const SX = $SX;
    const SY = $SY;

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
