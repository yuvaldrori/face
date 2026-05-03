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
import Toybox.Complications;

class FaceView extends $.Toybox.WatchUi.WatchFace {

    // Lifecycle and state tracking
    private var _lastUpdateMinute as $.Toybox.Lang.Number = -1;
    private var _hasAntiAlias as $.Toybox.Lang.Boolean = false;
    private var _batteryLevel as $.Toybox.Lang.Float = 0.0;
    private var _batteryRatio as $.Toybox.Lang.Float = 0.0;
    private var _solarRatio as $.Toybox.Lang.Float = 0.0;
    private var _stepRatio as $.Toybox.Lang.Float = 0.0;
    public var _isSleepMode as $.Toybox.Lang.Boolean = false;
    
    private var _lastHrValue as $.Toybox.Lang.Number = -1;
    private var _lastHrStr as $.Toybox.Lang.String = FaceLogic.STR_DASHES;
    private var _hour as $.Toybox.Lang.Number = 0;
    private var _min as $.Toybox.Lang.Number = 0;

    // Complication IDs
    private var _complicationSolar as Complications.Id? = null;
    private var _complicationSteps as Complications.Id? = null;
    private var _complicationBattery as Complications.Id? = null;
    private var _complicationHR as Complications.Id? = null;

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
    
    // Static Background Buffer (Track arcs)
    private var _staticBuffer as $.Toybox.Graphics.BufferedBitmapReference? = null;
    private var _lastBufferMinute as $.Toybox.Lang.Number = -1;
    private var _hugeFont as $.Toybox.Graphics.VectorFont? = null;

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
        if ($.Toybox.Graphics has :getVectorFont) {
            _hugeFont = $.Toybox.Graphics.getVectorFont({
                :face => "RobotoCondensedBold",
                :size => $.LayoutGenerated.HUGE_FONT_SIZE
            });
        }
        
        initializeComplications();
        initializeStaticBuffer();
        var clockTime = $.Toybox.System.getClockTime();
        updateLongTermData(clockTime, dc);
    }

    //
    // Initialize Complications subscriptions
    //
    private function initializeComplications() as Void {
        if (Toybox has :Complications) {
            Complications.registerComplicationChangeCallback(self.method(:onComplicationChanged));
            
            _complicationSolar = new Complications.Id(Complications.COMPLICATION_TYPE_SOLAR_INPUT);
            _complicationSteps = new Complications.Id(Complications.COMPLICATION_TYPE_STEPS);
            _complicationBattery = new Complications.Id(Complications.COMPLICATION_TYPE_BATTERY);
            _complicationHR = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);

            var ids = [_complicationSolar, _complicationSteps, _complicationBattery, _complicationHR];
            for (var i = 0; i < ids.size(); i++) {
                try {
                    Complications.subscribeToUpdates(ids[i]);
                } catch (e) {
                    // Handle unsupported complication types
                }
            }
        }
    }

    //
    // Handle Complication Data Updates
    //
    function onComplicationChanged(id as Complications.Id) as Void {
        var complication = Complications.getComplication(id);
        if (complication != null) {
            var val = complication.value;
            if (val != null) {
                if (id.equals(_complicationSolar)) {
                    var floatVal = (val instanceof Float) ? val as Float : (val as Number).toFloat();
                    var clampedIntensity = floatVal > FaceLogic.PERCENT_MAX ? FaceLogic.PERCENT_MAX : floatVal;
                    _solarRatio = clampedIntensity / FaceLogic.PERCENT_MAX;
                } else if (id.equals(_complicationSteps)) {
                    var info = $.Toybox.ActivityMonitor.getInfo();
                    _stepRatio = FaceLogic.getStepRatio((val as Number), info.stepGoal);
                } else if (id.equals(_complicationBattery)) {
                    var floatVal = (val instanceof Float) ? val as Float : (val as Number).toFloat();
                    _batteryLevel = floatVal;
                    _batteryRatio = _batteryLevel / FaceLogic.PERCENT_MAX;
                } else if (id.equals(_complicationHR)) {
                    var hr = (val as Number);
                    if (hr != _lastHrValue) {
                        _lastHrValue = hr;
                        _lastHrStr = FaceLogic.getHeartRateString(hr == -1 ? null : hr);
                    }
                }
                
                $.Toybox.WatchUi.requestUpdate();
            }
        }
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

        if (isFullUpdate) {
            _lastUpdateMinute = clockTime.min;
            updateLongTermData(clockTime, dc);
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
        return (level <= FaceLogic.BATT_THRESHOLD_LOW) ? COLOR_HEART : FaceLogic.COLOR_GREEN;
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
        if (_solarRatio > 0) {
            dc.setColor(FaceLogic.COLOR_YELLOW, COLOR_BG);
            FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_SOLAR_R, Graphics.ARC_COUNTER_CLOCKWISE, 90, (90 + (360 * _solarRatio)).toNumber());
        }

        // 2. Steps Ring (Middle)
        if (_stepRatio > 0) {
            dc.setColor(0x00FFFF, COLOR_BG); // Cyan for Steps
            FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_STEPS_R, Graphics.ARC_COUNTER_CLOCKWISE, 90, (90 + (360 * _stepRatio)).toNumber());
        }

        // 3. Battery Ring (Inner)
        if (_batteryRatio > 0) {
            dc.setColor(getBatteryColor(_batteryLevel), COLOR_BG);
            FaceLogic.drawSafeArc(dc, CX, CY, $.LayoutGenerated.RING_BATT_R, Graphics.ARC_COUNTER_CLOCKWISE, 90, (90 + (360 * _batteryRatio)).toNumber());
        }
    }

    public function renderDynamicUI(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, true);
        
        var mainColor = _isSleepMode ? FaceLogic.COLOR_DK_GRAY : COLOR_MAIN;
        dc.setColor(mainColor, $.Toybox.Graphics.COLOR_TRANSPARENT);

        // Huge Scalable Time (Tight Tracking)
        var font = _hugeFont != null ? _hugeFont : $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
        var timeStr = Lang.format("$1$$2$", [_hour.format("%02d"), _min.format("%02d")]);
        drawTightText(dc, CX, Y_TIME, font, timeStr, -14, $.DEBUG_ALIGNMENT);
        
        if (!_isSleepMode) {
            drawHeartIcon(dc, COLOR_HEART);
            dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
            dc.drawText($.LayoutGenerated.HR_TEXT_X, Y_HR, FONT_SMALL, _lastHrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
        }

        setAntiAliasSafe(dc, false);
    }

    //
    // Render text with custom character tracking (spacing)
    //
    private function drawTightText(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, font as Object, text as String, tracking as Number, debug as Boolean) as Void {
        var chars = text.toCharArray();
        var totalW = 0;
        var widths = new [chars.size()] as Array<Number>;
        var vFont = font as Graphics.VectorFont;
        
        for (var i = 0; i < chars.size(); i++) {
            var s = chars[i].toString();
            widths[i] = dc.getTextWidthInPixels(s, vFont) as Number;
            totalW += widths[i];
            if (i < chars.size() - 1) { totalW += tracking; }
        }
        
        var curX = (x - (totalW / 2)) as Number;
        var fontH = dc.getFontHeight(vFont) as Number;

        for (var i = 0; i < chars.size(); i++) {
            var s = chars[i].toString();
            if (debug) {
                dc.setColor(FaceLogic.COLOR_GREEN, COLOR_BG);
                dc.drawRectangle(curX, y, widths[i] as Number, fontH);
                dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(curX, y, vFont, s, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
            curX += widths[i] + tracking;
        }
    }

    private function drawDebugOverlay(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, false);
        dc.setPenWidth($.LayoutGenerated.PEN_WIDTH_DEBUG);
        
        // 1. Grid & Screen Edge
        dc.setColor(FaceLogic.COLOR_RED, COLOR_BG);
        dc.drawLine(CX, 0, CX, $.LayoutGenerated.HEIGHT); 
        dc.drawLine(0, CY, $.LayoutGenerated.WIDTH, CY);
        dc.drawCircle(CX, CY, ($.LayoutGenerated.WIDTH / 2) - 1);

        // 2. Ring Guides (Centers)
        dc.setColor(FaceLogic.COLOR_DK_GRAY, COLOR_BG);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_SOLAR_R);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_STEPS_R);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_BATT_R);

        // 3. Data Boundaries (Green)
        dc.setColor(FaceLogic.COLOR_GREEN, COLOR_BG);
        
        // HR Group
        var hrTextW = dc.getTextWidthInPixels(_lastHrStr, FONT_SMALL);
        var totalHrW = 24 + 8 + hrTextW;
        var hrStartX = CX - (totalHrW / 2);
        dc.drawRectangle(hrStartX, Y_HR, totalHrW, dc.getFontHeight(FONT_SMALL));
    }

    private function drawHeartIcon(dc as $.Toybox.Graphics.Dc, color as Number) as Void {
        dc.setColor(color, COLOR_BG);
        var r = $.LayoutGenerated.HEART_LOBE_R;
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_L_X, $.LayoutGenerated.HEART_LOBE_Y, r); 
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_R_X, $.LayoutGenerated.HEART_LOBE_Y, r);
        
        var pts = $.LayoutGenerated.HEART_POLY;
        dc.fillPolygon([[pts[0][0], pts[0][1]], [pts[1][0], pts[1][1]], [pts[2][0], pts[2][1]]]);
    }

    private function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        _hour = clockTime.hour as $.Toybox.Lang.Number;
        _min = clockTime.min as $.Toybox.Lang.Number;
        
        // Initial data fetch if complications haven't fired yet
        if (_batteryRatio == 0.0) { updateSystemStatsFallback(); }
    }

    public function updateSystemStatsFallback() as Void {
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

    function onEnterSleep() as Void { _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
}
