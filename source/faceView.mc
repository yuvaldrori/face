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
import Toybox.Weather;
import Toybox.Activity;

class FaceView extends $.Toybox.WatchUi.WatchFace {

    // Lifecycle and state tracking
    private var _lastUpdateMinute as $.Toybox.Lang.Number = -1;
    private var _hasAntiAlias as $.Toybox.Lang.Boolean = false;
    private var _solarIntensity as $.Toybox.Lang.Number = 0;
    private var _batteryLevel as $.Toybox.Lang.Float = 0.0;
    private var _isLowPower as $.Toybox.Lang.Boolean = true;
    
    // Value tracking for dirty-rect and change detection
    private var _lastHrValue as $.Toybox.Lang.Number = -1;
    private var _lastWeatherCondition as $.Toybox.Lang.Integer = -1;
    private var _lastTempValue as $.Toybox.Lang.Number? = null;
    private var _lastBattLevel as $.Toybox.Lang.Float = -1.0;
    private var _lastSolarValue as $.Toybox.Lang.Number = -1;

    // Cached Layout and String Values
    private var _condLine1 as $.Toybox.Lang.String = "";
    private var _condLine2 as $.Toybox.Lang.String = "";
    private var _isCondWrapped as $.Toybox.Lang.Boolean = false;

    private var _lastHrStr as $.Toybox.Lang.String = FaceLogic.STR_DASHES;
    private var _lastTimeStr as $.Toybox.Lang.String = "";
    private var _lastDateStr as $.Toybox.Lang.String = "";
    private var _lastCondStr as $.Toybox.Lang.String = "";
    private var _lastTempStr as $.Toybox.Lang.String = "";
    private var _unknownStr as $.Toybox.Lang.String = FaceLogic.STR_EMPTY;

    // Layout Constants (Optimized for 260x260 MIP)
    private const CX = $.LayoutGenerated.CX; 
    private const TOP_Y = $.LayoutGenerated.TOP_Y;
    private const ARC_RADIUS = $.LayoutGenerated.ARC_RADIUS;
    
    private const FONT_SMALL = $.Toybox.Graphics.FONT_SMALL;
    private const FONT_TIME = $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
    private const COLOR_MAIN = $.Toybox.Graphics.COLOR_WHITE;
    private const COLOR_BG = $.Toybox.Graphics.COLOR_BLACK;
    private const COLOR_HEART = $.Toybox.Graphics.COLOR_RED;
    private const COLOR_GLYPH = $.Toybox.Graphics.COLOR_LT_GRAY;

    private const Y_HR = $.LayoutGenerated.Y_HR;
    
    private const Y_COND = $.LayoutGenerated.Y_COND; 
    private const Y_TEMP = $.LayoutGenerated.Y_TEMP; 

    private const ARC_PEN_WIDTH = $.LayoutGenerated.ARC_PEN_WIDTH;
    private const MAX_TEXT_WIDTH = $.LayoutGenerated.MAX_TEXT_WIDTH;

    // Static Background Buffer (Track arcs, icons, and labels)
    private var _staticBuffer as $.Toybox.Graphics.BufferedBitmapReference? = null;
    private var _lastBufferMinute as $.Toybox.Lang.Number = -1;
    private var _timeH as $.Toybox.Lang.Number = 0;
    private var _dateH as $.Toybox.Lang.Number = 0;

    function initialize() {
        WatchFace.initialize();
        _hasAntiAlias = ($.Toybox.Graphics has :setAntiAlias);
        _unknownStr = $.Toybox.WatchUi.loadResource($.Rez.Strings.weather_gen_condition_unknown) as String;
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
        _timeH = dc.getFontHeight(FONT_TIME);
        _dateH = dc.getFontHeight(FONT_SMALL);
        
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
            // 4-bit palette (16 colors) for maximum efficiency on MIP
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
        dc.clearClip();
        var clockTime = $.Toybox.System.getClockTime();
        var isFullUpdate = FaceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);

        // 1. Data Refresh (Smart Polling)
        if (!_isLowPower) { 
            updateHeartRate(); 
        }

        if (isFullUpdate) {
            _lastUpdateMinute = clockTime.min;
            updateLongTermData(clockTime, dc);
            if (_isLowPower) { updateHeartRate(); } // Only poll once per minute in sleep
        }

        // 2. Buffer Management (Redraw static elements if minute changed or buffer purged)
        if (isFullUpdate || _staticBuffer == null || _lastBufferMinute != clockTime.min) {
            updateStaticBuffer();
            _lastBufferMinute = clockTime.min;
        }

        // 3. Hardware-Accelerated Redraw (Blit buffer to screen)
        var bufferRef = _staticBuffer;
        var buffer = (bufferRef != null) ? bufferRef.get() : null;
        if (buffer instanceof $.Toybox.Graphics.BufferedBitmap) {
            dc.drawBitmap(0, 0, buffer);
        } else {
            renderStatic(dc);
        }

        // 4. Render Dynamic Text (High-Visibility Overlay)
        renderDynamicUI(dc);

        if ($.DEBUG_ALIGNMENT) { drawDebugOverlay(dc); }
    }

    //
    // Render persistent UI elements into the background buffer
    //
    private function updateStaticBuffer() as Void {
        var bufferRef = _staticBuffer;
        if (bufferRef == null) { return; }
        var buffer = bufferRef.get();
        if (!(buffer instanceof $.Toybox.Graphics.BufferedBitmap)) { return; }

        renderStatic(buffer.getDc());
    }

    //
    // Shared logic for all static elements (Arcs, Icons, Labels)
    //
    private function renderStatic(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();
        renderAllArcs(dc);
        drawStaticIcons(dc);
    }

    //
    // Shared logic for arc tracks and data fills
    //
    private function renderAllArcs(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, false);
        dc.setPenWidth(ARC_PEN_WIDTH);

        // 1. Static Tracks
        dc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, COLOR_BG);
        FaceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.BATT_TRACK_START, $.LayoutGenerated.BATT_TRACK_END);
        FaceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.SOLAR_TRACK_START, $.LayoutGenerated.SOLAR_TRACK_END);

        // 2. Data Fills
        dc.setColor(FaceLogic.getBatteryColor(_batteryLevel), COLOR_BG);
        var battFillAngle = (_batteryLevel / FaceLogic.PERCENT_MAX) * $.LayoutGenerated.DATA_ARC_SPAN;
        if (battFillAngle > 0) {
            FaceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_CLOCKWISE, $.LayoutGenerated.BATT_START, ($.LayoutGenerated.BATT_START - battFillAngle).toNumber());
        }

        if (_solarIntensity > 0) {
            dc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
            var clampedIntensity = _solarIntensity > FaceLogic.PERCENT_MAX ? FaceLogic.PERCENT_MAX : _solarIntensity;
            var solarFillAngle = (clampedIntensity / FaceLogic.PERCENT_MAX) * $.LayoutGenerated.DATA_ARC_SPAN;
            FaceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.SOLAR_TRACK_START, ($.LayoutGenerated.SOLAR_TRACK_START + solarFillAngle).toNumber());
        }
    }

    //
    // Draw shared glyphs (Battery and Solar)
    //
    private function drawStaticIcons(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setPenWidth(1);
        dc.setColor(COLOR_GLYPH, COLOR_BG);
        dc.drawRectangle($.LayoutGenerated.BATT_RECT_X, $.LayoutGenerated.BATT_RECT_Y, $.LayoutGenerated.BATT_W, $.LayoutGenerated.BATT_H);
        dc.fillRectangle($.LayoutGenerated.BATT_TIP_RECT_X, $.LayoutGenerated.BATT_TIP_RECT_Y, $.LayoutGenerated.BATT_TIP_W, $.LayoutGenerated.BATT_TIP_H); 
        
        dc.setColor(FaceLogic.getBatteryColor(_batteryLevel), COLOR_BG);
        var fillH = ($.LayoutGenerated.BATT_FILL_MAX_H * (_batteryLevel / FaceLogic.PERCENT_MAX)).toNumber();
        if (fillH > 0) { 
            dc.fillRectangle($.LayoutGenerated.BATT_FILL_X, $.LayoutGenerated.BATT_FILL_Y_BASE - fillH, $.LayoutGenerated.BATT_FILL_W, fillH); 
        }

        var sx = $.LayoutGenerated.SX; var sy = $.LayoutGenerated.SY;
        dc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
        dc.fillCircle(sx, sy, $.LayoutGenerated.SUN_R);
        var rays = $.LayoutGenerated.SOLAR_RAYS;
        for (var i = 0; i < rays.size(); i++) {
            var r = rays[i];
            dc.drawLine(sx + r[0], sy + r[1], sx + r[2], sy + r[3]);
        }
    }

    //
    // Render real-time text (Clock, HR, Weather) directly to the screen
    //
    private function renderDynamicUI(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, true);
        dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);

        dc.drawText(CX, TOP_Y, FONT_TIME,  _lastTimeStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CX, $.LayoutGenerated.DATE_Y, FONT_SMALL, _lastDateStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);

        // HR Group (Static Alignment)
        drawHeartIcon(dc, COLOR_HEART);
        dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawText($.LayoutGenerated.HR_TEXT_X, Y_HR, FONT_SMALL, _lastHrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);

        // Weather Group (Semi-Static)
        if (_isCondWrapped) {
            dc.drawText(CX, Y_COND - $.LayoutGenerated.COND_WRAP_V_OFFSET, FONT_SMALL, _condLine1, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(CX, Y_COND, FONT_SMALL, _condLine2, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(CX, Y_COND, FONT_SMALL, _lastCondStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(CX, Y_TEMP, FONT_SMALL, _lastTempStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);

        setAntiAliasSafe(dc, false);
    }

    //
    // Debug helper to verify geometric alignment
    //
    private function drawDebugOverlay(dc as $.Toybox.Graphics.Dc) as Void {
        setAntiAliasSafe(dc, false);
        dc.setPenWidth(2);
        
        // 1. Full Alignment Grid
        dc.setColor($.Toybox.Graphics.COLOR_WHITE, COLOR_BG);
        dc.drawCircle(CX, CX, $.LayoutGenerated.SCREEN_RADIUS); // Screen Edge

        dc.setColor($.Toybox.Graphics.COLOR_RED, COLOR_BG);
        dc.drawLine(CX, 0, CX, $.LayoutGenerated.HEIGHT); dc.drawLine(0, CX, $.LayoutGenerated.WIDTH, CX); // Crosshair
        
        dc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
        dc.drawLine(0, TOP_Y, $.LayoutGenerated.WIDTH, TOP_Y); // Arc Limit
        
        dc.setColor($.Toybox.Graphics.COLOR_GREEN, COLOR_BG);
        
        // 2. Data Bounding Boxes
        dc.drawRectangle(CX - dc.getTextWidthInPixels(_lastTimeStr, FONT_TIME)/2, TOP_Y, dc.getTextWidthInPixels(_lastTimeStr, FONT_TIME), _timeH);
        dc.drawRectangle(CX - dc.getTextWidthInPixels(_lastDateStr, FONT_SMALL)/2, $.LayoutGenerated.DATE_Y, dc.getTextWidthInPixels(_lastDateStr, FONT_SMALL), _dateH);

        // Heart Rate
        var hrTextW = dc.getTextWidthInPixels(_lastHrStr, FONT_SMALL);
        var iconW = $.LayoutGenerated.HR_ICON_W;
        var gap = $.LayoutGenerated.HR_GAP;
        var totalHrW = iconW + gap + hrTextW;
        var hrStartX = $.LayoutGenerated.HR_X - (iconW / 2);
        dc.drawRectangle(hrStartX, Y_HR, totalHrW, _dateH);

        var condW = dc.getTextWidthInPixels(_lastCondStr, FONT_SMALL);
        if (_isCondWrapped) {
            var w1 = dc.getTextWidthInPixels(_condLine1, FONT_SMALL);
            var w2 = dc.getTextWidthInPixels(_condLine2, FONT_SMALL);
            dc.drawRectangle(CX - w1/2, Y_COND - $.LayoutGenerated.COND_WRAP_V_OFFSET, w1, _dateH);
            dc.drawRectangle(CX - w2/2, Y_COND, w2, _dateH);
        } else {
            dc.drawRectangle(CX - condW/2, Y_COND, condW, _dateH);
        }
        var tempW = dc.getTextWidthInPixels(_lastTempStr, FONT_SMALL);
        dc.drawRectangle(CX - tempW/2, Y_TEMP, tempW, _dateH);
        
        var gr = $.LayoutGenerated.DEBUG_GUIDE_R;
        dc.drawCircle($.LayoutGenerated.BX, $.LayoutGenerated.BY, gr); dc.drawCircle($.LayoutGenerated.SX, $.LayoutGenerated.SY, gr);
    }

    //
    // Draw a vector-based heart icon
    //
    private function drawHeartIcon(dc as $.Toybox.Graphics.Dc, color as Number) as Void {
        dc.setColor(color, COLOR_BG);
        var r = $.LayoutGenerated.HEART_LOBE_R;
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_L_X, $.LayoutGenerated.HEART_LOBE_Y, r); 
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_R_X, $.LayoutGenerated.HEART_LOBE_Y, r);
        dc.fillPolygon($.LayoutGenerated.HEART_POLY);
    }

    //
    // Fetch and update the heart rate sensor data
    //
    private function updateHeartRate() as Void {
        if ($.Toybox has :Activity) {
            var activityInfo = $.Toybox.Activity.getActivityInfo();
            var rate = (activityInfo != null) ? activityInfo.currentHeartRate : -1;
            if (rate != _lastHrValue) {
                _lastHrValue = (rate != null) ? rate as $.Toybox.Lang.Number : -1;
                _lastHrStr = FaceLogic.getHeartRateString(rate == -1 ? null : rate);
            }
        }
    }

    //
    // Update system stats, clock, and solar data
    //
    private function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        var stats = $.Toybox.System.getSystemStats();
        _batteryLevel = stats.battery;
        if (_batteryLevel != _lastBattLevel) { _lastBattLevel = _batteryLevel; }
        
        var intensity = (stats has :solarIntensity) ? stats.solarIntensity : 0;
        if (intensity == null) { intensity = 0; }
        if (intensity != _lastSolarValue) {
            _lastSolarValue = intensity;
            _solarIntensity = intensity;
        }
        _lastTimeStr = FaceLogic.getTimeString(clockTime.hour as $.Toybox.Lang.Number, clockTime.min as $.Toybox.Lang.Number);
        var info = $.Toybox.Time.Gregorian.info($.Toybox.Time.now(), $.Toybox.Time.FORMAT_SHORT);
        _lastDateStr = FaceLogic.getDateString(info);
        if ($.Toybox has :Weather) {
            updateWeather($.Toybox.Weather.getCurrentConditions(), dc);
        }
    }

    //
    // Fetch and format weather condition and temperature data
    //
    private function updateWeather(conditions as $.Toybox.Weather.CurrentConditions?, dc as $.Toybox.Graphics.Dc) as Void {
        var condition = (conditions != null) ? conditions.condition : null;
        if (condition != _lastWeatherCondition || _lastCondStr.equals("")) {
            _lastWeatherCondition = (condition != null) ? condition : -1;
            var str = (condition != null) ? WeatherGenerated.getConditionString(condition) : null;
            _lastCondStr = (str == null) ? _unknownStr : str;
            var condWidth = dc.getTextWidthInPixels(_lastCondStr, FONT_SMALL);
            if (condWidth > MAX_TEXT_WIDTH) {
                var lines = FaceLogic.splitString(_lastCondStr, dc, FONT_SMALL, MAX_TEXT_WIDTH);
                _condLine1 = lines[0]; _condLine2 = lines[1]; _isCondWrapped = true;
            } else { _isCondWrapped = false; }
        }
        var temp = (conditions != null) ? conditions.temperature : null;
        if (temp != _lastTempValue || _lastTempStr.equals("")) {
            _lastTempValue = (temp != null) ? temp as $.Toybox.Lang.Number : null;
            _lastTempStr = FaceLogic.getTemperatureString(_lastTempValue);
        }
    }

    function onEnterSleep() as Void { _isLowPower = true; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { _isLowPower = false; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
}
