#!/bin/bash

# Garmin Connect IQ Layout Generator for Fenix 8 47mm Solar (MIP) - REDESIGN
WIDTH=${1:-260}
HEIGHT=${2:-260}
MC_OUT="source/layoutGenerated.mc"

CX=$(awk "BEGIN { print int($WIDTH / 2) }")
CY=$(awk "BEGIN { print int($HEIGHT / 2) }")

# Ring Configuration (Three heavy touching rings, moved out to clear HR line)
# Target radius around 100px (approx 75% of screen)
OUTER_R=108
RING_WIDTH=14
# Ring 1: Outer (Solar)
RING_SOLAR_R=$OUTER_R
# Ring 2: Middle (Steps)
RING_STEPS_R=$(awk "BEGIN { print int($OUTER_R - $RING_WIDTH) }")
# Ring 3: Inner (Battery)
RING_BATT_R=$(awk "BEGIN { print int($RING_STEPS_R - $RING_WIDTH) }")

# Huge Vector Font Positioning
HUGE_FONT_H=180
Y_TIME=$(awk "BEGIN { print int($CY - ($HUGE_FONT_H / 2) - 10) }")

# HR Positioning (Centered below time, with clearance)
Y_HR=$(awk "BEGIN { print int($CY + 60) }")

# HR Layout
HR_ICON_W=24
HR_GAP=8
HR_TEXT_EST_W=40
HR_TOTAL_W=$(awk "BEGIN { print int($HR_ICON_W + $HR_GAP + $HR_TEXT_EST_W) }")
HR_START_X=$(awk "BEGIN { print int($CX - ($HR_TOTAL_W / 2)) }")
HR_X=$(awk "BEGIN { print int($HR_START_X + ($HR_ICON_W / 2)) }")
HR_TEXT_X=$(awk "BEGIN { print int($HR_START_X + $HR_ICON_W + $HR_GAP) }")

# Smoother Heart Icon (Multiple circles + sharper polygon)
HEART_LOBE_R=7
HEART_LOBE_OFFSET=6
HEART_LOBE_Y_OFFSET=-2
HEART_POLY_V_OFFSET=0
HEART_POLY_H_OFFSET=13
HEART_POLY_TIP_V=14

# Heart Lobe Positions
HEART_LOBE_L_X=$(awk "BEGIN { print int($HR_X - $HEART_LOBE_OFFSET) }")
HEART_LOBE_R_X=$(awk "BEGIN { print int($HR_X + $HEART_LOBE_OFFSET) }")
HEART_LOBE_Y=$(awk "BEGIN { print int($Y_HR + 15 + $HEART_LOBE_Y_OFFSET) }")

# Pre-calculate Heart Polygon (Smoother transition from circles)
P1_X=$(awk "BEGIN { print int($HR_X - $HEART_POLY_H_OFFSET) }")
P1_Y=$(awk "BEGIN { print int($Y_HR + 15 + $HEART_LOBE_Y_OFFSET + 2) }")
P2_X=$(awk "BEGIN { print int($HR_X + $HEART_POLY_H_OFFSET) }")
P2_Y=$(awk "BEGIN { print int($Y_HR + 15 + $HEART_LOBE_Y_OFFSET + 2) }")
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
    const HUGE_FONT_SIZE = $HUGE_FONT_H;

    const Y_HR = $Y_HR;
    const HR_X = $HR_X;
    const HR_TEXT_X = $HR_TEXT_X;
    const HEART_LOBE_R = $HEART_LOBE_R;
    const HEART_LOBE_L_X = $HEART_LOBE_L_X;
    const HEART_LOBE_R_X = $HEART_LOBE_R_X;
    const HEART_LOBE_Y = $HEART_LOBE_Y;
    
    const HEART_POLY = $HEART_POLY_MC;
    
    const PEN_WIDTH_DEBUG = 1;
}
EOM
