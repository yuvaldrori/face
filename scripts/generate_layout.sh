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

# Custom Huge Digit Geometry (Line Segments)
# Scaled to be huge (approx 180px tall)
# Digits will overlap slightly for a "stenciled" look
SCALE=1.2
S_W=$(awk "BEGIN { print 70 * $SCALE }")
S_H=$(awk "BEGIN { print 150 * $SCALE }")

# X positions for 4 digits (HH:mm) - tighter gap to keep them centered
GAP=2
T1_X=$(awk "BEGIN { print int($CX - ($S_W * 2) - ($GAP * 1.5)) }")
T2_X=$(awk "BEGIN { print int($CX - $S_W - ($GAP * 0.5)) }")
T3_X=$(awk "BEGIN { print int($CX + ($GAP * 0.5)) }")
T4_X=$(awk "BEGIN { print int($CX + $S_W + ($GAP * 1.5)) }")
Y_TIME=$(awk "BEGIN { print int($CY - ($S_H / 2)) }")

# HR Positioning (Below center of digits)
Y_HR=$(awk "BEGIN { print int($CY + 40) }")

# Digit Lines (Simplified segments for 100x150 space)
D0="[[0,0,100,0],[100,0,100,150],[100,150,0,150],[0,150,0,0]]"
D1="[[100,0,100,150]]"
D2="[[0,0,100,0],[100,0,100,75],[100,75,0,75],[0,75,0,150],[0,150,100,150]]"
D3="[[0,0,100,0],[100,0,100,150],[100,150,0,150],[0,75,100,75]]"
D4="[[0,0,0,75],[0,75,100,75],[100,0,100,150]]"
D5="[[100,0,0,0],[0,0,0,75],[0,75,100,75],[100,75,100,150],[100,150,0,150]]"
D6="[[100,0,0,0],[0,0,0,150],[0,150,100,150],[100,150,100,75],[100,75,0,75]]"
D7="[[0,0,100,0],[100,0,100,150]]"
D8="[[0,0,100,0],[100,0,100,150],[100,150,0,150],[0,150,0,0],[0,75,100,75]]"
D9="[[100,150,100,0],[100,0,0,0],[0,0,0,75],[0,75,100,75]]"

scale_lines() {
    python3 -c "import re; p='$1'; s=$SCALE; w_s=0.7; print(re.sub(r'(\d+)', lambda m: str(int(int(m.group(1)) * (s if int(m.group(0)) > 100 or '150' in p else w_s*s))), p))"
}
# Actually let's use a simpler scaler for width and height specifically
scale_lines_fixed() {
    python3 -c "
import json
poly = json.loads('$1')
scale_x = $SCALE * 0.7
scale_y = $SCALE
res = []
for line in poly:
    res.append([int(line[0]*scale_x), int(line[1]*scale_y), int(line[2]*scale_x), int(line[3]*scale_y)])
print(json.dumps(res))
"
}

SD0=$(scale_lines_fixed "$D0")
SD1=$(scale_lines_fixed "$D1")
SD2=$(scale_lines_fixed "$D2")
SD3=$(scale_lines_fixed "$D3")
SD4=$(scale_lines_fixed "$D4")
SD5=$(scale_lines_fixed "$D5")
SD6=$(scale_lines_fixed "$D6")
SD7=$(scale_lines_fixed "$D7")
SD8=$(scale_lines_fixed "$D8")
SD9=$(scale_lines_fixed "$D9")

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
    const DIGIT_W = $(awk "BEGIN { print int($S_W * 0.7) }");
    const DIGIT_H = $(awk "BEGIN { print int($S_H) }");

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
