#!/bin/bash

# Garmin Connect IQ Layout Generator for Fenix 8 47mm Solar (MIP) - REDESIGN
WIDTH=${1:-260}
HEIGHT=${2:-260}
MC_OUT="source/layoutGenerated.mc"

CX=$(awk "BEGIN { print int($WIDTH / 2) }")
CY=$(awk "BEGIN { print int($HEIGHT / 2) }")

# Ring Configuration (Three heavy touching rings, moved in by 4px)
RING_MARGIN=4
RING_WIDTH=18
# Ring 1: Outer (Solar) - ends at 130 - 4 = 126
RING_SOLAR_R=$(awk "BEGIN { print int(130 - $RING_MARGIN - ($RING_WIDTH / 2)) }")
# Ring 2: Middle (Steps)
RING_STEPS_R=$(awk "BEGIN { print int($RING_SOLAR_R - $RING_WIDTH) }")
# Ring 3: Inner (Battery)
RING_BATT_R=$(awk "BEGIN { print int($RING_STEPS_R - $RING_WIDTH) }")

# Custom Huge Digit Geometry (Block Rectangles [x, y, w, h])
# Each digit is defined in a 100x150 unit space
# We will draw them with fillRectangle
SCALE_X=0.9
SCALE_Y=1.3
S_W=$(awk "BEGIN { print 70 * $SCALE_X }")
S_H=$(awk "BEGIN { print 150 * $SCALE_Y }")

# X positions for 4 digits (HH:mm)
GAP=6
T1_X=$(awk "BEGIN { print int($CX - ($S_W * 2) - ($GAP * 1.5)) }")
T2_X=$(awk "BEGIN { print int($CX - $S_W - ($GAP * 0.5)) }")
T3_X=$(awk "BEGIN { print int($CX + ($GAP * 0.5)) }")
T4_X=$(awk "BEGIN { print int($CX + $S_W + ($GAP * 1.5)) }")
Y_TIME=$(awk "BEGIN { print int($CY - ($S_H / 2)) }")

# HR Positioning (Below center)
Y_HR=$(awk "BEGIN { print int($CY + 50) }")

# Digit Blocks (x, y, w, h) - 100x150 space
# Bar width is 30 units
BW=30
H_BW=15 # Half bar width
D_W=100
D_H=150

# Digit 0: Left, Right, Top, Bottom bars
D0="[[0,0,30,150],[70,0,30,150],[30,0,40,30],[30,120,40,30]]"
# Digit 1: One thick bar
D1="[[35,0,40,150]]"
# Digit 2: Top, Mid, Bot, Top-Right, Bot-Left
D2="[[0,0,100,30],[0,60,100,30],[0,120,100,30],[70,30,30,30],[0,90,30,30]]"
# Digit 3: Top, Mid, Bot, Right bar
D3="[[0,0,100,30],[0,60,100,30],[0,120,100,30],[70,0,30,150]]"
# Digit 4: Left-Top, Right, Mid
D4="[[0,0,30,90],[70,0,30,150],[30,60,40,30]]"
# Digit 5: Top, Mid, Bot, Top-Left, Bot-Right
D5="[[0,0,100,30],[0,60,100,30],[0,120,100,30],[0,30,30,30],[70,90,30,30]]"
# Digit 6: Left, Top, Mid, Bot, Bot-Right
D6="[[0,0,30,150],[30,0,70,30],[30,60,70,30],[30,120,70,30],[70,90,30,30]]"
# Digit 7: Top, Right
D7="[[0,0,100,30],[70,30,30,120]]"
# Digit 8: Left, Right, Top, Mid, Bot
D8="[[0,0,30,150],[70,0,30,150],[30,0,40,30],[30,60,40,30],[30,120,40,30]]"
# Digit 9: Right, Top, Mid, Left-Top
D9="[[70,0,30,150],[0,0,70,30],[0,60,70,30],[0,30,30,30]]"

scale_blocks() {
    python3 -c "
import json
blocks = json.loads('$1')
sx = $SCALE_X
sy = $SCALE_Y
res = []
for b in blocks:
    res.append([int(b[0]*sx), int(b[1]*sy), int(b[2]*sx), int(b[3]*sy)])
print(json.dumps(res))
"
}

SD0=$(scale_blocks "$D0")
SD1=$(scale_blocks "$D1")
SD2=$(scale_blocks "$D2")
SD3=$(scale_blocks "$D3")
SD4=$(scale_blocks "$D4")
SD5=$(scale_blocks "$D5")
SD6=$(scale_blocks "$D6")
SD7=$(scale_blocks "$D7")
SD8=$(scale_blocks "$D8")
SD9=$(scale_blocks "$D9")

# HR Layout
HR_ICON_W=24
HR_GAP=8
HR_TEXT_EST_W=40
HR_TOTAL_W=$(awk "BEGIN { print int($HR_ICON_W + $HR_GAP + $HR_TEXT_EST_W) }")
HR_START_X=$(awk "BEGIN { print int($CX - ($HR_TOTAL_W / 2)) }")
HR_X=$(awk "BEGIN { print int($HR_START_X + ($HR_ICON_W / 2)) }")
HR_TEXT_X=$(awk "BEGIN { print int($HR_START_X + $HR_ICON_W + $HR_GAP) }")

# Heart Icon
HEART_LOBE_R=6
HEART_LOBE_OFFSET=6
HEART_POLY_V_OFFSET=2
HEART_POLY_H_OFFSET=12
HEART_POLY_TIP_V=12
P1_X=$(awk "BEGIN { print int($HR_X - $HEART_POLY_H_OFFSET) }")
P1_Y=$(awk "BEGIN { print int($Y_HR + 15 - $HEART_POLY_V_OFFSET) }")
P2_X=$(awk "BEGIN { print int($HR_X + $HEART_POLY_H_OFFSET) }")
P2_Y=$(awk "BEGIN { print int($Y_HR + 15 - $HEART_POLY_V_OFFSET) }")
P3_X=$(awk "BEGIN { print int($HR_X) }")
P3_Y=$(awk "BEGIN { print int($Y_HR + 15 + $HEART_POLY_TIP_V) }")
HEART_POLY_MC="[[$P1_X, $P1_Y], [$P2_X, $P2_Y], [$P3_X, $P3_Y]]"

cat << EOM > "$MC_OUT"
module LayoutGenerated {
    const WIDTH = $WIDTH;
    const HEIGHT = $HEIGHT;
    const CX = $CX;
    const CY = $CY;
    
    const RING_WIDTH = $RING_WIDTH;
    const RING_SOLAR_R = $RING_SOLAR_R;
    const RING_STEPS_R = $RING_STEPS_R;
    const RING_BATT_R = $RING_BATT_R;

    const Y_TIME = $Y_TIME;
    const T1_X = $T1_X;
    const T2_X = $T2_X;
    const T3_X = $T3_X;
    const T4_X = $T4_X;

    const Y_HR = $Y_HR;
    const HR_X = $HR_X;
    const HR_TEXT_X = $HR_TEXT_X;
    const HEART_LOBE_R = $HEART_LOBE_R;
    const HEART_LOBE_L_X = $(awk "BEGIN { print int($HR_X - $HEART_LOBE_OFFSET) }");
    const HEART_LOBE_R_X = $(awk "BEGIN { print int($HR_X + $HEART_LOBE_OFFSET) }");
    const HEART_LOBE_Y = $(awk "BEGIN { print int($Y_HR + 15 - $HEART_LOBE_OFFSET) }");
    
    const HEART_POLY = $HEART_POLY_MC;

    const DIGITS = [ $SD0, $SD1, $SD2, $SD3, $SD4, $SD5, $SD6, $SD7, $SD8, $SD9 ];
}
EOM
