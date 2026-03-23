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

# Icon positions
BX=18
BY=$CY
SX=$((WIDTH - 18))
SY=$CY

# HR Icon/Text Layout (Static pre-calculation)
# Heart icon is roughly 20px wide
# Assuming Font height/width for planning (will be refined by dirty checking)
# Let's anchor the HR group at CX
HR_ICON_X=$((CX - 25))
HR_TEXT_X=$((CX - 2))

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
    
    const HR_ICON_X = $HR_ICON_X;
    const HR_TEXT_X = $HR_TEXT_X;
    
    const MAX_TEXT_WIDTH = 180;
}
EOM

echo "Generated $MC_OUT for ${WIDTH}x${HEIGHT} display."
