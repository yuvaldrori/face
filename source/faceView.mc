//
// FaceView.mc
// Specialized Watch Face View for Fenix 8 Solar 47mm (MIP)
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
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
    public var _hour as $.Toybox.Lang.Number = 0;
    public var _min as $.Toybox.Lang.Number = 0;
    public var _lastFallbackMinute as $.Toybox.Lang.Number = -1;

    public var _lastTimeStr as $.Toybox.Lang.String = "";
    public var _timeWidths as $.Toybox.Lang.Array<$.Toybox.Lang.Number> = [] as $.Toybox.Lang.Array<$.Toybox.Lang.Number>;
    public var _timeTotalW as $.Toybox.Lang.Number = 0;

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
                    if ($.Toybox.System has :println) {
                        $.Toybox.System.println("Complication sub failed: " + ids[i] + " (" + e.getErrorMessage() + ")");
                    }
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
                var needsBackgroundRedraw = false;
                if (id.equals(_complicationSolar)) {
                    var floatVal = (val as Numeric).toFloat();
                    var clampedIntensity = floatVal > FaceLogic.PERCENT_MAX ? FaceLogic.PERCENT_MAX : floatVal;
                    _solarRatio = clampedIntensity / FaceLogic.PERCENT_MAX;
                    needsBackgroundRedraw = true;
                } else if (id.equals(_complicationSteps)) {
                    var info = $.Toybox.ActivityMonitor.getInfo();
                    if (info != null) {
                        _stepRatio = FaceLogic.getStepRatio(val as Numeric, info.stepGoal);
                    } else {
                        _stepRatio = 0.0;
                    }
                    needsBackgroundRedraw = true;
                } else if (id.equals(_complicationBattery)) {
                    _batteryLevel = (val as Numeric).toFloat();
                    _batteryRatio = _batteryLevel / FaceLogic.PERCENT_MAX;
                    needsBackgroundRedraw = true;
                } else if (id.equals(_complicationHR)) {
                    var hr = (val as Number);
                    if (hr != _lastHrValue) {
                        _lastHrValue = hr;
                        _lastHrStr = FaceLogic.getHeartRateString(hr == -1 ? null : hr);
                    }
                }
                
                if (needsBackgroundRedraw && !_isSleepMode) {
                    _lastBufferMinute = -1; // Force static buffer update on next onUpdate
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
        
        var clockTime = $.Toybox.System.getClockTime();
        var isFullUpdate = FaceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);

        if (isFullUpdate) {
            _lastUpdateMinute = clockTime.min;
            
            // Check DND status once a minute (or when settings change)
            var settings = $.Toybox.System.getDeviceSettings();
            var inSleep = (settings has :doNotDisturb && settings.doNotDisturb);
            if (inSleep != _isSleepMode) {
                _isSleepMode = inSleep;
            }

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
        drawRingArc(dc, $.LayoutGenerated.RING_SOLAR_R, _solarRatio, FaceLogic.COLOR_YELLOW);
        
        // 2. Steps Ring (Middle)
        drawRingArc(dc, $.LayoutGenerated.RING_STEPS_R, _stepRatio, FaceLogic.getStepColor());
        
        // 3. Battery Ring (Inner)
        drawRingArc(dc, $.LayoutGenerated.RING_BATT_R, _batteryRatio, getBatteryColor(_batteryLevel));
    }

    private function drawRingArc(dc as $.Toybox.Graphics.Dc, radius as Number, ratio as Float, color as ColorValue) as Void {
        if (ratio <= 0) { return; }
        dc.setColor(color, COLOR_BG);
        var endAngle = 90 + (360 * ratio);
        dc.drawArc(CX, CY, radius, Graphics.ARC_COUNTER_CLOCKWISE, 90, endAngle.toNumber());
    }

    public function renderDynamicUI(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, true);
        
        var mainColor = _isSleepMode ? FaceLogic.COLOR_DK_GRAY : COLOR_MAIN;
        dc.setColor(mainColor, $.Toybox.Graphics.COLOR_TRANSPARENT);

        // Huge Scalable Time (Tight Tracking)
        var font = _hugeFont != null ? _hugeFont : $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
        var timeStr = Lang.format("$1$$2$", [_hour.format("%02d"), _min.format("%02d")]);
        
        if (!timeStr.equals(_lastTimeStr)) {
            _lastTimeStr = timeStr;
            var chars = timeStr.toCharArray();
            _timeWidths = new [chars.size()] as Array<Number>;
            _timeTotalW = 0;
            for (var i = 0; i < chars.size(); i++) {
                _timeWidths[i] = dc.getTextWidthInPixels(chars[i].toString(), font) as Number;
                _timeTotalW += _timeWidths[i];
                if (i < chars.size() - 1) { _timeTotalW += $.LayoutGenerated.TIME_TRACKING; }
            }
        }

        drawCachedTightText(dc, CX, Y_TIME, font, timeStr, _timeWidths, _timeTotalW, $.LayoutGenerated.TIME_TRACKING, $.DEBUG_ALIGNMENT);
        
        if (!_isSleepMode) {
            drawHeartIcon(dc, COLOR_HEART);
            dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
            dc.drawText($.LayoutGenerated.HR_TEXT_X, Y_HR, FONT_SMALL, _lastHrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
        }

        setAntiAliasSafe(dc, false);
    }

    //
    // Render text with custom character tracking using cached dimensions
    //
    private function drawCachedTightText(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, font as Object, text as String, widths as Array<Number>, totalW as Number, tracking as Number, debug as Boolean) as Void {
        var chars = text.toCharArray();
        var curX = (x - (totalW / 2)) as Number;
        var fontH = dc.getFontHeight(font as $.Toybox.Graphics.FontDefinition) as Number;

        for (var i = 0; i < chars.size(); i++) {
            var s = chars[i].toString();
            if (debug) {
                dc.setColor(FaceLogic.COLOR_GREEN, COLOR_BG);
                dc.drawRectangle(curX, y, widths[i] as Number, fontH);
                dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(curX, y, font as $.Toybox.Graphics.FontDefinition, s, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
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
        dc.drawCircle(CX, CY, $.LayoutGenerated.SCREEN_R);

        // 2. Ring Guides (Centers)
        dc.setColor(FaceLogic.COLOR_DK_GRAY, COLOR_BG);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_SOLAR_R);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_STEPS_R);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_BATT_R);

        // 3. Data Boundaries (Green)
        dc.setColor(FaceLogic.COLOR_GREEN, COLOR_BG);
        
        // HR Group
        var hrTextW = dc.getTextWidthInPixels(_lastHrStr, FONT_SMALL);
        var totalHrW = $.LayoutGenerated.HR_ICON_W + $.LayoutGenerated.HR_GAP + hrTextW;
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

    public function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        _hour = clockTime.hour as $.Toybox.Lang.Number;
        _min = clockTime.min as $.Toybox.Lang.Number;
        
        // Periodically refresh data from system as fallback (every 5 mins)
        if (_lastFallbackMinute == -1 || (_min % 5 == 0 && _lastFallbackMinute != _min)) {
            _lastFallbackMinute = _min;
            updateSystemStatsFallback();
        }
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
        if (info != null) {
            _stepRatio = FaceLogic.getStepRatio(info.steps, info.stepGoal);
        } else {
            _stepRatio = 0.0;
        }
    }

    function onEnterSleep() as Void { _isSleepMode = true; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { 
        _isSleepMode = false; 
        _lastUpdateMinute = -1; 
        _lastBufferMinute = -1; // Force background redraw when waking up
        $.Toybox.WatchUi.requestUpdate(); 
    }
}
