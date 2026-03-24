import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.Activity;
import Toybox.Math;

class faceView extends $.Toybox.WatchUi.WatchFace {

    private var _lastUpdateMinute as $.Toybox.Lang.Number = -1;
    private var _hasAntiAlias as $.Toybox.Lang.Boolean = false;
    private var _solarIntensity as $.Toybox.Lang.Number = 0;
    private var _batteryLevel as $.Toybox.Lang.Float = 0.0;
    private var _isLowPower as $.Toybox.Lang.Boolean = true;
    
    // Value Tracking
    private var _lastHrValue as $.Toybox.Lang.Number = -1;
    private var _lastWeatherCondition as $.Toybox.Lang.Integer = -1;
    private var _lastTempValue as $.Toybox.Lang.Number? = null;
    private var _lastBattLevel as $.Toybox.Lang.Float = -1.0;
    private var _lastSolarValue as $.Toybox.Lang.Number = -1;

    // Cached Layout Values
    private var _condLine1 as $.Toybox.Lang.String = "";
    private var _condLine2 as $.Toybox.Lang.String = "";
    private var _isCondWrapped as $.Toybox.Lang.Boolean = false;

    // Dirty tracking strings
    private var _lastHrStr as $.Toybox.Lang.String = "--";
    private var _lastTimeStr as $.Toybox.Lang.String = "";
    private var _lastDateStr as $.Toybox.Lang.String = "";
    private var _lastCondStr as $.Toybox.Lang.String = "";
    private var _lastTempStr as $.Toybox.Lang.String = "";
    private var _unknownStr as $.Toybox.Lang.String = "";

    // Global Constants (Fenix 8 47mm 260x260)
    private const CX = $.LayoutGenerated.CX; 
    private const TOP_Y = $.LayoutGenerated.TOP_Y;
    private const ARC_RADIUS = $.LayoutGenerated.ARC_RADIUS;
    
    private const FONT_SMALL = $.Toybox.Graphics.FONT_SMALL;
    private const FONT_TIME = $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
    private const COLOR_MAIN = $.Toybox.Graphics.COLOR_WHITE;
    private const COLOR_BG = $.Toybox.Graphics.COLOR_BLACK;

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
        _hasAntiAlias = ($.Toybox.Graphics.Dc has :setAntiAlias);
        _unknownStr = $.Toybox.WatchUi.loadResource($.Rez.Strings.weather_gen_condition_unknown) as String;
    }

    function onLayout(dc as $.Toybox.Graphics.Dc) as Void {
        initializeStaticBuffer();
        _timeH = dc.getFontHeight(FONT_TIME);
        _dateH = dc.getFontHeight(FONT_SMALL);
        var clockTime = $.Toybox.System.getClockTime();
        updateLongTermData(clockTime, dc);
        updateHeartRate();
    }

    private function initializeStaticBuffer() as Void {
        if ($.Toybox.Graphics has :createBufferedBitmap) {
            // 4-bit palette (16 colors) for maximum efficiency on MIP
            _staticBuffer = $.Toybox.Graphics.createBufferedBitmap({
                :width => $.LayoutGenerated.WIDTH,
                :height => $.LayoutGenerated.HEIGHT,
                :palette => faceLogic.getRequiredPalette()
            });
        }
    }

    function onUpdate(dc as $.Toybox.Graphics.Dc) as Void {
        dc.clearClip();
        var clockTime = $.Toybox.System.getClockTime();
        var isFullUpdate = faceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);

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
            drawStaticBackground();
            _lastBufferMinute = clockTime.min;
        }

        // 3. Hardware-Accelerated Redraw
        if (_staticBuffer != null) {
            var buffer = _staticBuffer.get();
            if (buffer instanceof $.Toybox.Graphics.BufferedBitmap) {
                dc.drawBitmap(0, 0, buffer);
            } else {
                renderFullFallback(dc);
            }
        } else {
            renderFullFallback(dc);
        }

        // 4. Render Dynamic Text (High-Visibility Overlay)
        renderDynamicUI(dc);

        if ($.DEBUG_ALIGNMENT) { drawDebugOverlay(dc); }
    }

    private function drawStaticBackground() as Void {
        var bufferRef = _staticBuffer;
        if (bufferRef == null) { return; }
        var buffer = bufferRef.get();
        if (!(buffer instanceof $.Toybox.Graphics.BufferedBitmap)) { return; }

        var bDc = buffer.getDc();

        bDc.setColor(COLOR_BG, COLOR_BG);
        bDc.clear();

        // A. Static Arcs (Tracks)
        bDc.setPenWidth(ARC_PEN_WIDTH);
        bDc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, COLOR_BG);
        faceLogic.drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.BATT_TRACK_START, $.LayoutGenerated.BATT_TRACK_END);
        faceLogic.drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.SOLAR_TRACK_START, $.LayoutGenerated.SOLAR_TRACK_END);

        // B. Data Arcs (Fill - Static for this minute)
        bDc.setColor(faceLogic.getBatteryColor(_batteryLevel), COLOR_BG);
        var battFillAngle = (_batteryLevel / 100.0) * 90.0;
        if (battFillAngle > 0) {
            faceLogic.drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_CLOCKWISE, $.LayoutGenerated.BATT_START, ($.LayoutGenerated.BATT_START - battFillAngle).toNumber());
        }

        if (_solarIntensity > 0) {
            bDc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
            var clampedIntensity = _solarIntensity > 100 ? 100.0 : _solarIntensity;
            var solarFillAngle = (clampedIntensity / 100.0) * 90.0;
            faceLogic.drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.SOLAR_TRACK_START, ($.LayoutGenerated.SOLAR_TRACK_START + solarFillAngle).toNumber());
        }

        // C. Static Icons
        bDc.setPenWidth(1);
        var bx = $.LayoutGenerated.BX; var by = $.LayoutGenerated.BY;
        bDc.setColor($.Toybox.Graphics.COLOR_LT_GRAY, COLOR_BG);
        bDc.drawRectangle(bx - 4, by - 7, 8, 14);
        bDc.fillRectangle(bx - 2, by - 9, 4, 2); 
        bDc.setColor(faceLogic.getBatteryColor(_batteryLevel), COLOR_BG);
        var fillH = (12 * (_batteryLevel / 100.0)).toNumber();
        if (fillH > 0) { bDc.fillRectangle(bx - 3, by + 6 - fillH, 6, fillH); }

        var sx = $.LayoutGenerated.SX; var sy = $.LayoutGenerated.SY;
        bDc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
        bDc.fillCircle(sx, sy, 3);
        var rays = $.LayoutGenerated.SOLAR_RAYS;
        for (var i = 0; i < rays.size(); i++) {
            var r = rays[i];
            bDc.drawLine(sx + r[0], sy + r[1], sx + r[2], sy + r[3]);
        }
    }

    private function renderDynamicUI(dc as $.Toybox.Graphics.Dc) as Void {
        if (_hasAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);

        var yTimeUp = TOP_Y;

        dc.drawText(CX, yTimeUp, FONT_TIME,  _lastTimeStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CX, (yTimeUp + _timeH) - _dateH, FONT_SMALL, _lastDateStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);

        // HR Group (Static Alignment)
        drawHeartIcon(dc, $.LayoutGenerated.HR_X, Y_HR + 14, $.Toybox.Graphics.COLOR_RED);
        dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawText($.LayoutGenerated.HR_TEXT_X, Y_HR, FONT_SMALL, _lastHrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);

        // Weather Group (Semi-Static)
        if (_isCondWrapped) {
            dc.drawText(CX, Y_COND - 24, FONT_SMALL, _condLine1, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(CX, Y_COND, FONT_SMALL, _condLine2, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(CX, Y_COND, FONT_SMALL, _lastCondStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(CX, Y_TEMP, FONT_SMALL, _lastTempStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);

        if (_hasAntiAlias) { dc.setAntiAlias(false); }
    }

    private function renderFullFallback(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();
        renderArcsDirectly(dc);
        // Icons
        dc.setPenWidth(1);
        var bx = $.LayoutGenerated.BX; var by = $.LayoutGenerated.BY;
        dc.setColor($.Toybox.Graphics.COLOR_LT_GRAY, COLOR_BG);
        dc.drawRectangle(bx - 4, by - 7, 8, 14);
        dc.fillRectangle(bx - 2, by - 9, 4, 2); 
        dc.setColor(faceLogic.getBatteryColor(_batteryLevel), COLOR_BG);
        var fillH = (12 * (_batteryLevel / 100.0)).toNumber();
        if (fillH > 0) { dc.fillRectangle(bx - 3, by + 6 - fillH, 6, fillH); }

        var sx = $.LayoutGenerated.SX; var sy = $.LayoutGenerated.SY;
        dc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
        dc.fillCircle(sx, sy, 3);
        var rays = $.LayoutGenerated.SOLAR_RAYS;
        for (var i = 0; i < rays.size(); i++) {
            var r = rays[i];
            dc.drawLine(sx + r[0], sy + r[1], sx + r[2], sy + r[3]);
        }
    }

    private function renderArcsDirectly(dc as $.Toybox.Graphics.Dc) as Void {
        if (_hasAntiAlias) { dc.setAntiAlias(false); }
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();
        dc.setPenWidth(ARC_PEN_WIDTH);
        
        // Battery Arc
        dc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, COLOR_BG);
        faceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.BATT_TRACK_START, $.LayoutGenerated.BATT_TRACK_END);
        
        dc.setColor(faceLogic.getBatteryColor(_batteryLevel), COLOR_BG);
        var battFillAngle = (_batteryLevel / 100.0) * 90.0;
        if (battFillAngle > 0) {
            faceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_CLOCKWISE, $.LayoutGenerated.BATT_START, ($.LayoutGenerated.BATT_START - battFillAngle).toNumber());
        }

        // Solar Arc
        dc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, COLOR_BG);
        faceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.SOLAR_TRACK_START, $.LayoutGenerated.SOLAR_TRACK_END);
        
        if (_solarIntensity > 0) {
            dc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
            var clampedIntensity = _solarIntensity > 100 ? 100.0 : _solarIntensity;
            var solarFillAngle = (clampedIntensity / 100.0) * 90.0;
            faceLogic.drawSafeArc(dc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, $.LayoutGenerated.SOLAR_TRACK_START, ($.LayoutGenerated.SOLAR_TRACK_START + solarFillAngle).toNumber());
        }
    }

    private function drawDebugOverlay(dc as $.Toybox.Graphics.Dc) as Void {
        if (_hasAntiAlias) { dc.setAntiAlias(false); }
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
        var yTimeUp = TOP_Y; // Matches vertical padding in onUpdate
        
        // Clock & Date (Centered)
        dc.drawRectangle(CX - dc.getTextWidthInPixels(_lastTimeStr, FONT_TIME)/2, yTimeUp, dc.getTextWidthInPixels(_lastTimeStr, FONT_TIME), _timeH);
        dc.drawRectangle(CX - dc.getTextWidthInPixels(_lastDateStr, FONT_SMALL)/2, (yTimeUp + _timeH) - _dateH, dc.getTextWidthInPixels(_lastDateStr, FONT_SMALL), _dateH);

        // Heart Rate
        var hrTextW = dc.getTextWidthInPixels(_lastHrStr, FONT_SMALL);
        var totalHrW = 20 + 6 + hrTextW;
        var hrStartX = $.LayoutGenerated.HR_X - 10;
        dc.drawRectangle(hrStartX, Y_HR, totalHrW, 26);

        // Weather & Temp
        var condW = dc.getTextWidthInPixels(_lastCondStr, FONT_SMALL);
        if (_isCondWrapped) {
            var w1 = dc.getTextWidthInPixels(_condLine1, FONT_SMALL);
            var w2 = dc.getTextWidthInPixels(_condLine2, FONT_SMALL);
            dc.drawRectangle(CX - w1/2, Y_COND - 24, w1, 26);
            dc.drawRectangle(CX - w2/2, Y_COND, w2, 26);
        } else {
            dc.drawRectangle(CX - condW/2, Y_COND, condW, 26);
        }
        var tempW = dc.getTextWidthInPixels(_lastTempStr, FONT_SMALL);
        dc.drawRectangle(CX - tempW/2, Y_TEMP, tempW, 26);
        
        // Icon Guides
        dc.drawCircle($.LayoutGenerated.BX, $.LayoutGenerated.BY, 10); dc.drawCircle($.LayoutGenerated.SX, $.LayoutGenerated.SY, 10);
    }

    private function drawHeartIcon(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, color as Number) as Void {
        dc.setColor(color, COLOR_BG);
        dc.fillCircle(x - 5, y - 5, 5); dc.fillCircle(x + 5, y - 5, 5);
        var poly = $.LayoutGenerated.HEART_POLY;
        var points = [
            [x + poly[0][0], y + poly[0][1]],
            [x + poly[1][0], y + poly[1][1]],
            [x + poly[2][0], y + poly[2][1]]
        ] as Array<[Numeric, Numeric]>;
        dc.fillPolygon(points);
    }

    private function updateHeartRate() as Void {
        if ($.Toybox has :Activity) {
            var activityInfo = $.Toybox.Activity.getActivityInfo();
            var rate = (activityInfo != null) ? activityInfo.currentHeartRate : -1;
            if (rate != _lastHrValue) {
                _lastHrValue = (rate != null) ? rate as $.Toybox.Lang.Number : -1;
                _lastHrStr = faceLogic.getHeartRateString(rate == -1 ? null : rate);
            }
        }
    }

    private function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        var stats = $.Toybox.System.getSystemStats();
        _batteryLevel = stats.battery;
        if (_batteryLevel != _lastBattLevel) { _lastBattLevel = _batteryLevel; }
        if (stats has :solarIntensity) {
            var intensity = stats.solarIntensity;
            if (intensity != _lastSolarValue) {
                _lastSolarValue = (intensity != null) ? intensity as $.Toybox.Lang.Number : 0;
                _solarIntensity = _lastSolarValue;
            }
        }
        _lastTimeStr = faceLogic.getTimeString(clockTime.hour as $.Toybox.Lang.Number, clockTime.min as $.Toybox.Lang.Number);
        var info = $.Toybox.Time.Gregorian.info($.Toybox.Time.now(), $.Toybox.Time.FORMAT_SHORT);
        _lastDateStr = faceLogic.getDateString(info);
        if ($.Toybox has :Weather) {
            var conditions = $.Toybox.Weather.getCurrentConditions();
            if (conditions != null) { updateWeather(conditions, dc); }
        }
    }

    private function updateWeather(conditions as $.Toybox.Weather.CurrentConditions, dc as $.Toybox.Graphics.Dc) as Void {
        var condition = conditions.condition;
        if (condition != null && (condition != _lastWeatherCondition || _lastCondStr.equals(""))) {
            _lastWeatherCondition = condition;
            var str = WeatherGenerated.getConditionString(condition);
            _lastCondStr = (str == null) ? _unknownStr : str;
            var condWidth = dc.getTextWidthInPixels(_lastCondStr, FONT_SMALL);
            if (condWidth > MAX_TEXT_WIDTH) {
                var lines = faceLogic.splitString(_lastCondStr, dc, FONT_SMALL, MAX_TEXT_WIDTH);
                _condLine1 = lines[0]; _condLine2 = lines[1]; _isCondWrapped = true;
            } else { _isCondWrapped = false; }
        }
        var temp = conditions.temperature;
        if (temp != _lastTempValue || _lastTempStr.equals("")) {
            _lastTempValue = (temp != null) ? temp as $.Toybox.Lang.Number : null;
            _lastTempStr = faceLogic.getTemperatureString(temp as $.Toybox.Lang.Number?);
        }
    }

    function onEnterSleep() as Void { _isLowPower = true; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { _isLowPower = false; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
}
