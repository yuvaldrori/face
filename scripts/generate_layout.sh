#!/bin/bash

# Garmin Connect IQ Layout Generator for Fenix 8 47mm Solar (MIP) - REDESIGN
WIDTH=${1:-260}
HEIGHT=${2:-260}
MC_OUT="source/layoutGenerated.mc"

CX=$(awk "BEGIN { print int($WIDTH / 2) }")
CY=$(awk "BEGIN { print int($HEIGHT / 2) }")

# --- Display Geometry Metrics ---
SCREEN_R=$(awk "BEGIN { print int($WIDTH / 2) - 1 }")

# --- Ring Configuration (Bottom arcs only) ---
OUTER_R=120
RING_WIDTH=12
INNER_RING_GAP=2

# Ring 1: Outer (Battery)
RING_BATT_R=$OUTER_R
# Ring 2: Inner (Steps)
RING_STEPS_R=$(awk "BEGIN { print int($OUTER_R - $RING_WIDTH - $INNER_RING_GAP) }")

# Arc Angles (Wider for clipping to horizontal)
ARC_START=200
ARC_END=340
# Vertical clip point for the top of the arcs
RING_CLIP_Y=190

# --- Huge Vector Font Positioning ---
HUGE_FONT_H=180
# Center the font vertically, then nudge up slightly to make room for footer data
TIME_V_OFFSET=10
Y_TIME=$(awk "BEGIN { print int($CY - ($HUGE_FONT_H / 2) - $TIME_V_OFFSET) }")

# --- HR Positioning (Above time) ---
# Fixed gap from the top of the Time bounding box
HR_V_GAP=22
Y_HR=$(awk "BEGIN { print int($Y_TIME - $HR_V_GAP) }")

# --- Weather Positioning (Below time) ---
# Nudge up slightly from the literal bottom of the huge font to tighten the layout
WEATHER_V_NUDGE=25
Y_WEATHER=$(awk "BEGIN { print int($Y_TIME + $HUGE_FONT_H - $WEATHER_V_NUDGE) }")

# --- HR Layout ---
HR_ICON_W=24
HR_GAP=8
HR_TEXT_EST_W=40
HR_TOTAL_W=$(awk "BEGIN { print int($HR_ICON_W + $HR_GAP + $HR_TEXT_EST_W) }")
HR_START_X=$(awk "BEGIN { print int($CX - ($HR_TOTAL_W / 2)) }")
HR_X=$(awk "BEGIN { print int($HR_START_X + ($HR_ICON_W / 2)) }")
HR_TEXT_X=$(awk "BEGIN { print int($HR_START_X + $HR_ICON_W + $HR_GAP) }")

# --- Weather Layout (Temperature Only - Centered) ---
TEMP_TEXT_EST_W=40
TEMP_X=$(awk "BEGIN { print int($CX - ($TEMP_TEXT_EST_W / 2)) }")

# --- Touch Targets ---
TOUCH_HR_W=80
TOUCH_HR_H=30
TOUCH_TEMP_W=60
TOUCH_TEMP_H=30

# --- Smooth Heart Icon (Using more points for a rounded look) ---
HEART_LOBE_R=7
HEART_LOBE_OFFSET=6
HEART_LOBE_Y_OFFSET=-2
HEART_POLY_H_OFFSET=13
HEART_POLY_TIP_V=14
# Internal vertical anchor for heart primitives
HEART_V_ANCHOR=15

# Heart Lobe Positions
HEART_LOBE_L_X=$(awk "BEGIN { print int($HR_X - $HEART_LOBE_OFFSET) }")
HEART_LOBE_R_X=$(awk "BEGIN { print int($HR_X + $HEART_LOBE_OFFSET) }")
HEART_LOBE_Y=$(awk "BEGIN { print int($Y_HR + $HEART_V_ANCHOR + $HEART_LOBE_Y_OFFSET) }")

# Pre-calculate Heart Polygon (Sharper, more vertices for smoothness)
P1_X=$(awk "BEGIN { print int($HR_X - $HEART_POLY_H_OFFSET) }")
P1_Y=$(awk "BEGIN { print int($Y_HR + $HEART_V_ANCHOR + $HEART_LOBE_Y_OFFSET + 2) }")
P2_X=$(awk "BEGIN { print int($HR_X + $HEART_POLY_H_OFFSET) }")
P2_Y=$(awk "BEGIN { print int($Y_HR + $HEART_V_ANCHOR + $HEART_LOBE_Y_OFFSET + 2) }")
P3_X=$(awk "BEGIN { print int($HR_X) }")
P3_Y=$(awk "BEGIN { print int($Y_HR + $HEART_V_ANCHOR + $HEART_POLY_TIP_V) }")
HEART_POLY_MC="[[$P1_X, $P1_Y], [$P2_X, $P2_Y], [$P3_X, $P3_Y]]"

cat << EOM > "$MC_OUT"
module LayoutGenerated {
    const WIDTH = $WIDTH;
    const HEIGHT = $HEIGHT;
    const CX = $CX;
    const CY = $CY;
    const SCREEN_R = $SCREEN_R;
    
    const RING_WIDTH = $RING_WIDTH;
    const RING_BATT_R = $RING_BATT_R;
    const RING_STEPS_R = $RING_STEPS_R;
    
    const ARC_START = $ARC_START;
    const ARC_END = $ARC_END;
    const RING_CLIP_Y = $RING_CLIP_Y;

    const Y_TIME = $Y_TIME;
    const HUGE_FONT_SIZE = $HUGE_FONT_H;
    const TIME_TRACKING = -14;

    const HR_ICON_W = $HR_ICON_W;
    const HR_GAP = $HR_GAP;
    const Y_HR = $Y_HR;
    const HR_X = $HR_X;
    const HR_TEXT_X = $HR_TEXT_X;
    const HEART_LOBE_R = $HEART_LOBE_R;
    const HEART_LOBE_L_X = $HEART_LOBE_L_X;
    const HEART_LOBE_R_X = $HEART_LOBE_R_X;
    const HEART_LOBE_Y = $HEART_LOBE_Y;
    
    const HEART_POLY = $HEART_POLY_MC;

    const Y_WEATHER = $Y_WEATHER;
    const TEMP_X = $TEMP_X;

    const TOUCH_HR_W = $TOUCH_HR_W;
    const TOUCH_HR_H = $TOUCH_HR_H;
    const TOUCH_TEMP_W = $TOUCH_TEMP_W;
    const TOUCH_TEMP_H = $TOUCH_TEMP_H;
    
    const PEN_WIDTH_DEBUG = 1;
}
EOM
