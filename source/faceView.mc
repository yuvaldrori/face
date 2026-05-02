//
// FaceView.mc
// Specialized Watch Face View for Fenix 8 Solar 47mm (MIP)
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Activity;

class FaceView extends $.Toybox.WatchUi.WatchFace {

    // Lifecycle and state tracking
    private var _lastUpdateMinute as $.Toybox.Lang.Number = -1;
    private var _hasAntiAlias as $.Toybox.Lang.Boolean = false;
    private var _batteryLevel as $.Toybox.Lang.Float = 0.0;
    private var _batteryRatio as $.Toybox.Lang.Float = 0.0;
    private var _solarRatio as $.Toybox.Lang.Float = 0.0;
    private var _stepRatio as $.Toybox.Lang.Float = 0.0;
    private var _isLowPower as $.Toybox.Lang.Boolean = true;
    public var _isSleepMode as $.Toybox.Lang.Boolean = false;
    
    private var _lastHrValue as $.Toybox.Lang.Number = -1;
    private var _lastHrStr as $.Toybox.Lang.String = FaceLogic.STR_DASHES;
    private var _hour as $.Toybox.Lang.Number = 0;
    private var _min as $.Toybox.Lang.Number = 0;

    // Layout Constants (Optimized for 260x260 MIP)
    private const CX = $.LayoutGenerated.CX; 
    private const CY = $.LayoutGenerated.CY;
    
    private const FONT_SMALL = $.Toybox.Graphics.FONT_SMALL;
    private const COLOR_MAIN as $.Toybox.Graphics.ColorValue = FaceLogic.COLOR_WHITE;
    private const COLOR_BG as $.Toybox.Graphics.ColorValue = FaceLogic.COLOR_BLACK;
    private const COLOR_HEART as $.Toybox.Graphics.ColorValue = FaceLogic.COLOR_RED;

    private const Y_TIME = $.LayoutGenerated.Y_TIME;
    private const Y_HR = $.LayoutGenerated.Y_HR;
    
    private const RING_WIDTH = $.LayoutGenerated.RING_WIDTH;
    
    private const BATT_THRESHOLD_LOW = 20.0;

    // Static Background Buffer (Track arcs)
    private var _staticBuffer as $.Toybox.Graphics.BufferedBitmapReference? = null;
    private var _lastBufferMinute as $.Toybox.Lang.Number = -1;

    function initialize() {
        WatchFace.initialize();
        _hasAntiAlias = ($.Toybox.Graphics has :setAntiAlias);
        _lastHrStr = FaceLogic.STR_DASHES;
    }

    //
    // Helper to safely set anti-aliasing if supported
    //
    private function setAntiAliasSafe(dc as $.Toybox.Graphics.Dc, enable as $.Toybox.Lang.Boolean) as Void {
        if (_hasAntiAlias) {
            dc.setAntiAlias(enable);
        }
    }

    //
    // Set up UI component dimensions and initial data
    //
    function onLayout(dc as $.Toybox.Graphics.Dc) as Void {
        initializeStaticBuffer();
        var clockTime = $.Toybox.System.getClockTime();
        updateLongTermData(clockTime, dc);
        updateHeartRate();
    }

    //
    // Initialize the off-screen buffer for static elements
    //
    private function initializeStaticBuffer() as Void {
        if (_staticBuffer != null && _staticBuffer.get() != null) { return; }
        if ($.Toybox.Graphics has :createBufferedBitmap) {
            _staticBuffer = $.Toybox.Graphics.createBufferedBitmap({
                :width => $.LayoutGenerated.WIDTH,
                :height => $.LayoutGenerated.HEIGHT,
                :palette => FaceLogic.getRequiredPalette()
            });
        }
    }

    //
    // Main Rendering Loop (1Hz Update)
    //
    function onUpdate(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, false);
        dc.clearClip();
        
        var settings = $.Toybox.System.getDeviceSettings();
        var inSleep = false;
        if (settings has :doNotDisturb && settings.doNotDisturb) { inSleep = true; }
        if (!inSleep && settings has :isNightModeEnabled && settings.isNightModeEnabled) { inSleep = true; }

        if (inSleep != _isSleepMode) {
            _isSleepMode = inSleep;
            _lastUpdateMinute = -1;
        }

        var clockTime = $.Toybox.System.getClockTime();
        var isFullUpdate = FaceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);

        if (!_isLowPower) { updateHeartRate(); }

        if (isFullUpdate) {
            _lastUpdateMinute = clockTime.min;
            updateLongTermData(clockTime, dc);
            if (_isLowPower) { updateHeartRate(); }
        }

        if (isFullUpdate || _staticBuffer == null || _lastBufferMinute != clockTime.min) {
            updateStaticBuffer();
            _lastBufferMinute = clockTime.min;
        }

        var bufferRef = _staticBuffer;
        var buffer = (bufferRef != null) ? bufferRef.get() : null;
        if (buffer instanceof $.Toybox.Graphics.BufferedBitmap) {
            dc.drawBitmap(0, 0, buffer);
        } else {
            renderStatic(dc);
        }

        renderDynamicUI(dc);
        if ($.DEBUG_ALIGNMENT) { drawDebugOverlay(dc); }
    }

    public function getBatteryColor(level as $.Toybox.Lang.Float) as $.Toybox.Graphics.ColorValue {
        return (level <= BATT_THRESHOLD_LOW) ? COLOR_HEART : FaceLogic.COLOR_GREEN;
    }

    private function updateStaticBuffer() as Void {
        var bufferRef = _staticBuffer;
        if (bufferRef == null) { return; }
        var buffer = bufferRef.get();
        if (!(buffer instanceof $.Toybox.Graphics.BufferedBitmap)) { return; }
        renderStatic(buffer.getDc());
    }

    public function renderStatic(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();
        
        if (!_isSleepMode) {
            renderAllRings(dc);
        }
    }

    private function renderAllRings(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setPenWidth(RING_WIDTH);

        // 1. Solar Ring (Outer)
        dc.setColor(FaceLogic.COLOR_DK_GRAY, COLOR_BG);
        FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_SOLAR_R, Graphics.ARC_COUNTER_CLOCKWISE, 0, 360);
        if (_solarRatio > 0) {
            dc.setColor(FaceLogic.COLOR_YELLOW, COLOR_BG);
            FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_SOLAR_R, Graphics.ARC_COUNTER_CLOCKWISE, 90, (90 + (360 * _solarRatio)).toNumber());
        }

        // 2. Steps Ring (Middle)
        dc.setColor(FaceLogic.COLOR_DK_GRAY, COLOR_BG);
        FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_STEPS_R, Graphics.ARC_COUNTER_CLOCKWISE, 0, 360);
        if (_stepRatio > 0) {
            dc.setColor(0x00FFFF, COLOR_BG); // Cyan for Steps
            FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_STEPS_R, Graphics.ARC_COUNTER_CLOCKWISE, 90, (90 + (360 * _stepRatio)).toNumber());
        }

        // 3. Battery Ring (Inner)
        dc.setColor(FaceLogic.COLOR_DK_GRAY, COLOR_BG);
        FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_BATT_R, Graphics.ARC_COUNTER_CLOCKWISE, 0, 360);
        if (_batteryRatio > 0) {
            dc.setColor(getBatteryColor(_batteryLevel), COLOR_BG);
            FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_BATT_R, Graphics.ARC_COUNTER_CLOCKWISE, 90, (90 + (360 * _batteryRatio)).toNumber());
        }
    }

    public function renderDynamicUI(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, true);
        
        var mainColor = _isSleepMode ? FaceLogic.COLOR_DK_GRAY : COLOR_MAIN;
        dc.setColor(mainColor, $.Toybox.Graphics.COLOR_TRANSPARENT);

        // Huge Vector Time
        var h1 = _hour / 10;
        var h2 = _hour % 10;
        var m1 = _min / 10;
        var m2 = _min % 10;

        dc.setPenWidth(16); // Bold digits
        drawDigit(dc, $.LayoutGenerated.T1_X, Y_TIME, h1);
        drawDigit(dc, $.LayoutGenerated.T2_X, Y_TIME, h2);
        drawDigit(dc, $.LayoutGenerated.T3_X, Y_TIME, m1);
        drawDigit(dc, $.LayoutGenerated.T4_X, Y_TIME, m2);
        
        if (!_isSleepMode) {
            dc.setPenWidth(1); // Reset for heart
            drawHeartIcon(dc, COLOR_HEART);
            dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
            dc.drawText($.LayoutGenerated.HR_TEXT_X, Y_HR, FONT_SMALL, _lastHrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
        }

        setAntiAliasSafe(dc, false);
    }

    private function drawDigit(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, digit as Number) as Void {
        var segments = $.LayoutGenerated.DIGITS[digit] as Array<Array<Number>>;
        for (var i = 0; i < segments.size(); i++) {
            var s = segments[i];
            dc.drawLine(x + s[0], y + s[1], x + s[2], y + s[3]);
        }
    }

    private function drawDebugOverlay(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, false);
        dc.setColor(FaceLogic.COLOR_RED, COLOR_BG);
        dc.drawLine(CX, 0, CX, $.LayoutGenerated.HEIGHT); 
        dc.drawLine(0, CY, $.LayoutGenerated.WIDTH, CY);
    }

    private function drawHeartIcon(dc as $.Toybox.Graphics.Dc, color as Number) as Void {
        dc.setColor(color, COLOR_BG);
        var r = $.LayoutGenerated.HEART_LOBE_R;
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_L_X, $.LayoutGenerated.HEART_LOBE_Y, r); 
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_R_X, $.LayoutGenerated.HEART_LOBE_Y, r);
        dc.fillPolygon($.LayoutGenerated.HEART_POLY);
    }

    public function updateHeartRate() as Void {
        if ($.Toybox has :Activity) {
            var activityInfo = $.Toybox.Activity.getActivityInfo();
            var rate = (activityInfo != null) ? activityInfo.currentHeartRate : null as Number?;
            var rateVal = (rate != null) ? rate as Number : -1;
            if (rateVal != _lastHrValue) {
                _lastHrValue = rateVal;
                _lastHrStr = FaceLogic.getHeartRateString(rateVal == -1 ? null : rateVal);
            }
        }
    }

    private function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        updateSystemStats();
        _hour = clockTime.hour as $.Toybox.Lang.Number;
        _min = clockTime.min as $.Toybox.Lang.Number;
    }

    public function updateSystemStats() as Void {
        var stats = $.Toybox.System.getSystemStats();
        _batteryLevel = stats.battery;
        _batteryRatio = _batteryLevel / FaceLogic.PERCENT_MAX;
        
        var intensity = (stats has :solarIntensity) ? stats.solarIntensity : 0;
        if (intensity == null) { intensity = 0; }
        var clampedIntensity = intensity > FaceLogic.PERCENT_MAX ? FaceLogic.PERCENT_MAX : intensity;
        _solarRatio = clampedIntensity / FaceLogic.PERCENT_MAX;

        var info = $.Toybox.ActivityMonitor.getInfo();
        _stepRatio = FaceLogic.getStepRatio(info.steps, info.stepGoal);
    }

    function onEnterSleep() as Void { _isLowPower = true; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { _isLowPower = false; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
}
