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
    
    // Background Buffer (Arcs only)
    private var _bgBuffer as $.Toybox.Graphics.BufferedBitmapReference? = null;
    
    // Value Tracking
    private var _lastHrValue as $.Toybox.Lang.Number = -1;
    private var _lastWeatherCondition as $.Toybox.Lang.Integer = -1;
    private var _lastTempValue as $.Toybox.Lang.Number? = null;
    private var _lastBattLevel as $.Toybox.Lang.Float = -1.0;
    private var _lastBattDays as $.Toybox.Lang.Float = -1.0;
    private var _lastSolarValue as $.Toybox.Lang.Number = -1;

    // Cached Layout Values
    private var _clockRightX as $.Toybox.Lang.Number = 130;
    private var _condLine1 as $.Toybox.Lang.String = "";
    private var _condLine2 as $.Toybox.Lang.String = "";
    private var _isCondWrapped as $.Toybox.Lang.Boolean = false;

    // Dirty tracking strings
    private var _lastHrStr as $.Toybox.Lang.String = "--";
    private var _lastBattDaysShortStr as $.Toybox.Lang.String = "";
    private var _lastTimeStr as $.Toybox.Lang.String = "";
    private var _lastDateStr as $.Toybox.Lang.String = "";
    private var _lastCondStr as $.Toybox.Lang.String = "";
    private var _lastTempStr as $.Toybox.Lang.String = "";

    // Global Constants (Fenix 8 47mm 260x260)
    private const CX = $.LayoutGenerated.CX; 
    private const TOP_Y = $.LayoutGenerated.TOP_Y;
    private const OUTER_X_LEFT = $.LayoutGenerated.OUTER_X_LEFT;
    private const ARC_RADIUS = $.LayoutGenerated.ARC_RADIUS;
    private const BATT_END_DEG = $.LayoutGenerated.BATT_END_ANGLE;

    private const FONT_SMALL = $.Toybox.Graphics.FONT_SMALL;
    private const FONT_TINY = $.Toybox.Graphics.FONT_XTINY; 
    private const FONT_TIME = $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
    private const COLOR_MAIN = $.Toybox.Graphics.COLOR_WHITE;
    private const COLOR_BG = $.Toybox.Graphics.COLOR_BLACK;

    private const Y_HR = 12;    
    private const Y_COND = 203; 
    private const Y_TEMP = 229; 

    // Geometric Constants
    private const ARC_PEN_WIDTH = 6;
    private const BATT_START = 225; 
    private const MAX_TEXT_WIDTH = 180;

    function initialize() {
        WatchFace.initialize();
        _hasAntiAlias = ($.Toybox.Graphics.Dc has :setAntiAlias);
    }

    function onLayout(dc as $.Toybox.Graphics.Dc) as Void {
        var palette = [
            Graphics.COLOR_BLACK, Graphics.COLOR_WHITE, 
            Graphics.COLOR_DK_GRAY, Graphics.COLOR_LT_GRAY, 
            Graphics.COLOR_YELLOW, Graphics.COLOR_RED, Graphics.COLOR_GREEN
        ];
        
        if ($.Toybox.Graphics has :createBufferedBitmap) {
            _bgBuffer = $.Toybox.Graphics.createBufferedBitmap({ :width => 260, :height => 260, :palette => palette });
        }
        
        var clockTime = $.Toybox.System.getClockTime();
        updateLongTermData(clockTime, dc);
        updateHeartRate();
    }

    function onUpdate(dc as $.Toybox.Graphics.Dc) as Void {
        var clockTime = $.Toybox.System.getClockTime();
        var isFullUpdate = faceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);
        
        if (!_isLowPower) { updateHeartRate(); }
        if (isFullUpdate) {
            _lastUpdateMinute = clockTime.min;
            updateLongTermData(clockTime, dc);
        }

        // 1. Buffer Management (Redraw Arcs if data changed or buffer purged)
        if (isFullUpdate || _bgBuffer == null) {
            drawBackgroundToBuffer();
        }

        // 2. Render Background Arcs
        var bufferRef = _bgBuffer;
        if (bufferRef != null) {
            var buffer = bufferRef.get();
            if (buffer instanceof $.Toybox.Graphics.BufferedBitmap) {
                dc.drawBitmap(0, 0, buffer);
            }
        } else {
            dc.setColor(COLOR_BG, COLOR_BG);
            dc.clear();
        }
        
        // 3. Render All Text directly to Screen DC (For Anti-Aliasing and Hardware Stability)
        if (_hasAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
        
        // Battery Label
        var fontHeightTiny = dc.getFontHeight(FONT_TINY);
        dc.drawText(OUTER_X_LEFT, TOP_Y + (fontHeightTiny / 2), FONT_TINY, _lastBattDaysShortStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT | $.Toybox.Graphics.TEXT_JUSTIFY_VCENTER);

        // Heart Rate Row
        var hrTextWidth = dc.getTextWidthInPixels(_lastHrStr, FONT_SMALL);
        var hrStartX = CX - ((20 + 8 + hrTextWidth) / 2);
        drawHeartIcon(dc, hrStartX + 10, Y_HR + 14, $.Toybox.Graphics.COLOR_RED);
        dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawText(hrStartX + 28, Y_HR, FONT_SMALL, _lastHrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);

        // Clock Core
        var timeH = dc.getFontHeight(FONT_TIME);
        var dateH = dc.getFontHeight(FONT_SMALL);
        var yTimeUp = TOP_Y + (fontHeightTiny / 2);
        dc.drawText(CX, yTimeUp, FONT_TIME,  _lastTimeStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_clockRightX, yTimeUp + timeH - dateH, FONT_SMALL, _lastDateStr, $.Toybox.Graphics.TEXT_JUSTIFY_RIGHT);

        // Weather Group
        if (_isCondWrapped) {
            dc.drawText(CX, Y_COND - 24, FONT_SMALL, _condLine1, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(CX, Y_COND, FONT_SMALL, _condLine2, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(CX, Y_COND, FONT_SMALL, _lastCondStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(CX, Y_TEMP, FONT_SMALL, _lastTempStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);

        if ($.DEBUG_ALIGNMENT) { drawDebugOverlay(dc); }
    }

    private function drawBackgroundToBuffer() as Void {
        var bufferRef = _bgBuffer;
        if (bufferRef == null) { return; }
        var buffer = bufferRef.get();
        if (!(buffer instanceof $.Toybox.Graphics.BufferedBitmap)) { return; }
        
        var bDc = buffer.getDc();
        bDc.setColor(COLOR_BG, COLOR_BG);
        bDc.fillRectangle(0, 0, 260, 260); 
        
        bDc.setPenWidth(ARC_PEN_WIDTH);
        
        // 1. Battery Arc (Left)
        bDc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, COLOR_BG);
        drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_CLOCKWISE, BATT_START, BATT_END_DEG);
        
        bDc.setColor(faceLogic.getBatteryColor(_batteryLevel), COLOR_BG);
        var battTotalAngle = BATT_START - BATT_END_DEG;
        var battFillAngle = (_batteryLevel / 100.0) * battTotalAngle;
        if (battFillAngle > 0) {
            drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_CLOCKWISE, BATT_START, (BATT_START - battFillAngle).toNumber());
        }

        // 2. Solar Arc (Right) - Using YELLOW for high MIP visibility
        bDc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, COLOR_BG);
        drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, 315, 405); 
        
        if (_solarIntensity > 0) {
            bDc.setColor($.Toybox.Graphics.COLOR_YELLOW, COLOR_BG);
            var clampedIntensity = _solarIntensity > 100 ? 100.0 : _solarIntensity;
            var solarFillAngle = (clampedIntensity / 100.0) * 90.0;
            drawSafeArc(bDc, CX, CX, ARC_RADIUS, Graphics.ARC_COUNTER_CLOCKWISE, 315, (315 + solarFillAngle).toNumber());
        }
    }

    private function drawSafeArc(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, radius as Number, direction as $.Toybox.Graphics.ArcDirection, start as Number, end as Number) as Void {
        var diff = (end - start).abs();
        if (diff <= 45) {
            dc.drawArc(x, y, radius, direction, start, end);
        } else {
            var segments = (diff / 45.0).toNumber() + 1;
            var step = (end - start).toFloat() / segments.toFloat();
            var current = start.toFloat();
            for (var i = 0; i < segments; i++) {
                var next = current + step;
                dc.drawArc(x, y, radius, direction, current.toNumber(), next.toNumber());
                current = next;
            }
        }
    }

    private function drawDebugOverlay(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setPenWidth(1);
        dc.setColor($.Toybox.Graphics.COLOR_BLUE, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawLine(CX, 0, CX, 260); // V-Center
        
        var deltaY = ARC_RADIUS * 0.7071; // 45 degrees
        var topY = CX - deltaY;
        dc.setColor($.Toybox.Graphics.COLOR_YELLOW, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, topY, 260, topY); // Horizontal arc limit
        
        dc.setColor($.Toybox.Graphics.COLOR_PINK, $.Toybox.Graphics.COLOR_TRANSPARENT);
        
        // 1. HR Bounding Box
        var hrTextWidth = dc.getTextWidthInPixels(_lastHrStr, FONT_SMALL);
        var hrTotalWidth = 20 + 8 + hrTextWidth;
        dc.drawRectangle(CX - (hrTotalWidth / 2), Y_HR, hrTotalWidth, 26);

        // 2. Battery Days Box
        dc.drawRectangle(OUTER_X_LEFT, TOP_Y, dc.getTextWidthInPixels(_lastBattDaysShortStr, FONT_TINY), dc.getFontHeight(FONT_TINY));

        // 3. Clock & Date Boxes
        var timeW = dc.getTextWidthInPixels(_lastTimeStr, FONT_TIME);
        var timeH = dc.getFontHeight(FONT_TIME);
        var yTimeUp = topY + (dc.getFontHeight(FONT_TINY) / 2);
        dc.drawRectangle(CX - timeW/2, yTimeUp, timeW, timeH);
        
        var dateW = dc.getTextWidthInPixels(_lastDateStr, FONT_SMALL);
        dc.drawRectangle(_clockRightX - dateW, yTimeUp + timeH - dc.getFontHeight(FONT_SMALL), dateW, dc.getFontHeight(FONT_SMALL));

        // 4. Weather Box
        if (_isCondWrapped) {
            var w1 = dc.getTextWidthInPixels(_condLine1, FONT_SMALL);
            var w2 = dc.getTextWidthInPixels(_condLine2, FONT_SMALL);
            dc.drawRectangle(CX - w1/2, Y_COND - 24, w1, 26);
            dc.drawRectangle(CX - w2/2, Y_COND, w2, 26);
        } else {
            var condW = dc.getTextWidthInPixels(_lastCondStr, FONT_SMALL);
            dc.drawRectangle(CX - condW/2, Y_COND, condW, 26);
        }

        // 5. Temp Box
        var tempW = dc.getTextWidthInPixels(_lastTempStr, FONT_SMALL);
        dc.drawRectangle(CX - tempW/2, Y_TEMP, tempW, 26);
    }

    private function drawHeartIcon(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, color as Number) as Void {
        dc.setColor(color, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 5, y - 5, 5); dc.fillCircle(x + 5, y - 5, 5);
        dc.fillPolygon([[x - 10, y - 2], [x + 10, y - 2], [x, y + 10]]);
    }

    private function updateHeartRate() as Void {
        if ($.Toybox has :Activity) {
            var activityInfo = $.Toybox.Activity.getActivityInfo();
            var rate = (activityInfo != null) ? activityInfo.currentHeartRate : null;
            if (rate != _lastHrValue || _lastHrStr.equals("--")) {
                _lastHrValue = (rate != null) ? rate as $.Toybox.Lang.Number : -1;
                _lastHrStr = faceLogic.getHeartRateString(rate);
            }
        }
    }

    private function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        var stats = $.Toybox.System.getSystemStats();
        _batteryLevel = stats.battery;
        var curBattDays = (stats has :batteryInDays) ? stats.batteryInDays : null;
        if (_batteryLevel != _lastBattLevel || curBattDays != _lastBattDays || _lastBattDaysShortStr.equals("")) {
            _lastBattLevel = _batteryLevel;
            _lastBattDays = (curBattDays != null) ? curBattDays as $.Toybox.Lang.Float : -1.0;
            _lastBattDaysShortStr = faceLogic.getBatteryDaysShortString(curBattDays as $.Toybox.Lang.Float?);
        }
        if (stats has :solarIntensity) {
            var intensity = stats.solarIntensity;
            if (intensity != _lastSolarValue) {
                _lastSolarValue = (intensity != null) ? intensity as $.Toybox.Lang.Number : 0;
                _solarIntensity = _lastSolarValue;
            }
        }
        _lastTimeStr = faceLogic.getTimeString(clockTime.hour as $.Toybox.Lang.Number, clockTime.min as $.Toybox.Lang.Number);
        _clockRightX = CX + (dc.getTextWidthInPixels(_lastTimeStr, FONT_TIME) / 2);
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
            _lastCondStr = (str == null) ? $.Toybox.WatchUi.loadResource($.Rez.Strings.weather_gen_condition_unknown) as String : str;
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

    function onEnterSleep() as Void { _isLowPower = true; $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { _isLowPower = false; $.Toybox.WatchUi.requestUpdate(); }
}
