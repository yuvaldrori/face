#!/bin/bash

WIDTH=${1:-260}
HEIGHT=${2:-260}
MC_OUT="source/layoutGenerated.mc"

CX=$((WIDTH / 2))
CY=$((HEIGHT / 2))
# Arcs are 5px in from the edge
ARC_RADIUS=$((CX - 5))
# Screen boundary for intersection calculation
OUTER_RADIUS=$((CX - 1))

# Formulas:
# 1. TOP_Y: The horizontal line at 45 degrees from the center
# y = CY - (ARC_RADIUS * sin(45))
TOP_Y=$(awk "BEGIN { print int($CY - ($ARC_RADIUS * 0.70710678) + 0.5) }")

# 2. OUTER_X_LEFT: Intersection of TOP_Y line and OUTER_RADIUS circle
# (x - CX)^2 + (TOP_Y - CY)^2 = OUTER_RADIUS^2
# x = CX - sqrt(OUTER_RADIUS^2 - (TOP_Y - CY)^2)
DIST_Y=$(awk "BEGIN { print $CY - $TOP_Y }")
OUTER_X_LEFT=$(awk "BEGIN { print int($CX - sqrt($OUTER_RADIUS^2 - $DIST_Y^2) + 0.5) }")

# 3. BATT_END_ANGLE: Angle at the bottom of the FONT_TINY bounding box
# FONT_TINY height is roughly 22px on Fenix 8
FONT_TINY_HEIGHT=22
BATT_END_Y=$(awk "BEGIN { print $TOP_Y + $FONT_TINY_HEIGHT }")
# Calculate angle: asin((CY - BATT_END_Y) / ARC_RADIUS) in degrees
# Since it's in the top-left quadrant, angle is 180 - asin_deg
# Or using acos for the X coordinate, but let's use the Y delta
DY_BATT=$(awk "BEGIN { print $CY - $BATT_END_Y }")
# asin expects value between -1 and 1
# angle = (asin(DY_BATT / ARC_RADIUS) * 180 / PI)
BATT_END_ANGLE=$(awk "BEGIN { pi = 3.14159265; val = $DY_BATT / $ARC_RADIUS; if(val>1) val=1; if(val<-1) val=-1; angle = atan2(val, sqrt(1-val*val)) * 180 / pi; print int(180 - angle + 0.5) }")

cat << EOM > "$MC_OUT"
// Auto-generated layout constants for ${WIDTH}x${HEIGHT}
// Generated on $(date)
module LayoutGenerated {
    const CX = $CX;
    const CY = $CY;
    const ARC_RADIUS = $ARC_RADIUS;
    const TOP_Y = $TOP_Y;
    const OUTER_X_LEFT = $OUTER_X_LEFT;
    const BATT_END_ANGLE = $BATT_END_ANGLE;
}
EOM

echo "Generated $MC_OUT for ${WIDTH}x${HEIGHT} display."
chmod +x "$MC_OUT"
