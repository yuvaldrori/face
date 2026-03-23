import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.Activity;

class faceView extends $.Toybox.WatchUi.WatchFace {
    private var _lastUpdateMinute as $.Toybox.Lang.Number = -1;
    private var _hasAntiAlias as $.Toybox.Lang.Boolean = false;
    private var _solarIntensity as $.Toybox.Lang.Number = 0;
    private var _batteryLevel as $.Toybox.Lang.Float = 0.0;
    
    // Buffers & References
    private var _bgBuffer as $.Toybox.Graphics.BufferedBitmapReference? = null;
    private var _hrBuffer as $.Toybox.Graphics.BufferedBitmapReference? = null;
    private var _partialUpdatesAllowed as $.Toybox.Lang.Boolean = true;
    
    // Value Tracking
    private var _lastHrValue as $.Toybox.Lang.Number = -1;
    private var _lastWeatherCondition as $.Toybox.Lang.Integer = -1;
    private var _lastTempValue as $.Toybox.Lang.Number? = null;
    private var _lastBattLevel as $.Toybox.Lang.Float = -1.0;
    private var _lastBattDays as $.Toybox.Lang.Float = -1.0;

    // Cached Layout Values
    private var _hrBufferX as $.Toybox.Lang.Number = 80; 
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

    // Global Constants from Generated Layout
    private const CX = $.LayoutGenerated.CX; 
    private const TOP_Y = $.LayoutGenerated.TOP_Y;
    private const OUTER_X_LEFT = $.LayoutGenerated.OUTER_X_LEFT;
    private const ARC_RADIUS = $.LayoutGenerated.ARC_RADIUS;

    private const FONT_SMALL = $.Toybox.Graphics.FONT_SMALL;
    private const FONT_TINY = $.Toybox.Graphics.FONT_XTINY; 
    private const FONT_TIME = $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
    private const COLOR_MAIN = $.Toybox.Graphics.COLOR_WHITE;
    private const COLOR_BG = $.Toybox.Graphics.COLOR_BLACK;

    // Vertical Positions
    private const Y_HR = 12;    
    private const Y_COND = 203; 
    private const Y_TEMP = 229; 

    // Geometric Constants
    private const ARC_PEN_WIDTH = 6;
    private const BATT_START = 225; 
    private const BATT_END = 145;   
    private const BATT_TOTAL_ANGLE = 80.0; 
    private const SOLAR_START = 315; 
    private const SOLAR_END = 45;    
    private const MAX_TEXT_WIDTH = 180;

    function initialize() {
        WatchFace.initialize();
        _hasAntiAlias = ($.Toybox.Graphics.Dc has :setAntiAlias);
    }

    function onLayout(dc as $.Toybox.Graphics.Dc) as Void {
        if ($.Toybox.Graphics has :createBufferedBitmap) {
            _bgBuffer = $.Toybox.Graphics.createBufferedBitmap({ :width => 260, :height => 260 });
            _hrBuffer = $.Toybox.Graphics.createBufferedBitmap({ :width => 100, :height => 32 });
        }
    }

    function onUpdate(dc as $.Toybox.Graphics.Dc) as Void {
        if (_hasAntiAlias) { dc.setAntiAlias(true); }

        var clockTime = $.Toybox.System.getClockTime();
        var isFullUpdate = faceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);
        
        updateHeartRate(dc); 
        if (isFullUpdate) {
            _lastUpdateMinute = clockTime.min;
            updateLongTermData(clockTime, dc);
        }

        if (isFullUpdate || _bgBuffer == null) {
            drawBackgroundToBuffer();
        }

        var bufferRef = _bgBuffer;
        if (bufferRef != null) {
            var buffer = bufferRef.get();
            if (buffer instanceof $.Toybox.Graphics.BufferedBitmap) { dc.drawBitmap(0, 0, buffer); }
        } else {
            dc.setColor(COLOR_BG, COLOR_BG);
            dc.clear();
        }
        
        var hrRef = _hrBuffer;
        if (hrRef != null) {
            var hr = hrRef.get();
            if (hr instanceof $.Toybox.Graphics.BufferedBitmap) { dc.drawBitmap(_hrBufferX, Y_HR, hr); }
        }

        if ($.DEBUG_ALIGNMENT) { drawDebugOverlay(dc); }
    }

    private function drawBackgroundToBuffer() as Void {
        var bufferRef = _bgBuffer;
        if (bufferRef == null) { return; }
        var buffer = bufferRef.get();
        if (!(buffer instanceof $.Toybox.Graphics.BufferedBitmap)) { return; }
        
        var bDc = buffer.getDc();
        if (_hasAntiAlias) { bDc.setAntiAlias(true); }
        bDc.setColor(COLOR_BG, COLOR_BG);
        bDc.clear();
        
        // 1. Arcs
        bDc.setPenWidth(ARC_PEN_WIDTH);
        bDc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, $.Toybox.Graphics.COLOR_TRANSPARENT);
        bDc.drawArc(CX, CX, ARC_RADIUS, $.Toybox.Graphics.ARC_CLOCKWISE, BATT_START, BATT_END);
        bDc.setColor(faceLogic.getBatteryColor(_lastBattLevel), $.Toybox.Graphics.COLOR_TRANSPARENT);
        bDc.drawArc(CX, CX, ARC_RADIUS, $.Toybox.Graphics.ARC_CLOCKWISE, BATT_START, BATT_START - ((_batteryLevel / 100.0) * BATT_TOTAL_ANGLE));

        bDc.setColor($.Toybox.Graphics.COLOR_DK_GRAY, $.Toybox.Graphics.COLOR_TRANSPARENT);
        bDc.drawArc(CX, CX, ARC_RADIUS, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, SOLAR_START, SOLAR_END);
        if (_solarIntensity > 0) {
            bDc.setColor($.Toybox.Graphics.COLOR_ORANGE, $.Toybox.Graphics.COLOR_TRANSPARENT);
            bDc.drawArc(CX, CX, ARC_RADIUS, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, SOLAR_START, SOLAR_START + ((_solarIntensity / 100.0) * 90.0));
        }

        // 2. Battery Label
        var fontHeightTiny = bDc.getFontHeight(FONT_TINY);
        bDc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
        bDc.drawText(OUTER_X_LEFT, TOP_Y + (fontHeightTiny / 2), FONT_TINY, _lastBattDaysShortStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT | $.Toybox.Graphics.TEXT_JUSTIFY_VCENTER);

        // 3. Clock & Date
        var dateH = bDc.getFontHeight(FONT_SMALL);
        var yTimeUp = TOP_Y + (fontHeightTiny / 2);
        var clockBottom = yTimeUp + bDc.getFontHeight(FONT_TIME);
        
        bDc.drawText(_clockRightX, clockBottom - dateH, FONT_SMALL, _lastDateStr, $.Toybox.Graphics.TEXT_JUSTIFY_RIGHT);
        bDc.drawText(CX, yTimeUp, FONT_TIME,  _lastTimeStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        
        // 4. Weather
        if (_isCondWrapped) {
            bDc.drawText(CX, Y_COND - 24, FONT_SMALL, _condLine1, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
            bDc.drawText(CX, Y_COND, FONT_SMALL, _condLine2, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            bDc.drawText(CX, Y_COND, FONT_SMALL, _lastCondStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
        }
        bDc.drawText(CX, Y_TEMP, FONT_SMALL, _lastTempStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onPartialUpdate(dc as $.Toybox.Graphics.Dc) as Void {
        if (!_partialUpdatesAllowed) { return; }
        updateHeartRate(dc);
        dc.setClip(_hrBufferX, Y_HR, 100, 32);
        var bgRef = _bgBuffer;
        if (bgRef != null) {
            var bg = bgRef.get();
            if (bg instanceof $.Toybox.Graphics.BufferedBitmap) { dc.drawBitmap(0, 0, bg); }
        }
        var hrRef = _hrBuffer;
        if (hrRef != null) {
            var hr = hrRef.get();
            if (hr instanceof $.Toybox.Graphics.BufferedBitmap) { dc.drawBitmap(_hrBufferX, Y_HR, hr); }
        }
    }

    private function renderHrToBuffer(dc as $.Toybox.Graphics.Dc) as Void {
        var hrRef = _hrBuffer;
        if (hrRef == null) { return; }
        var hrBuf = hrRef.get();
        if (!(hrBuf instanceof $.Toybox.Graphics.BufferedBitmap)) { return; }
        var hDc = hrBuf.getDc();
        hDc.setColor(COLOR_BG, COLOR_BG);
        hDc.clear();
        var hrTextWidth = hDc.getTextWidthInPixels(_lastHrStr, FONT_SMALL);
        var hrTotalWidth = 20 + 8 + hrTextWidth;
        var startX = (100 - hrTotalWidth) / 2;
        drawHeartIcon(hDc, startX + 10, 14, $.Toybox.Graphics.COLOR_RED);
        hDc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
        hDc.drawText(startX + 28, 0, FONT_SMALL, _lastHrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
        _hrBufferX = CX - 50; 
    }

    function onPowerBudgetExceeded(powerInfo as $.Toybox.WatchUi.WatchFacePowerInfo) as Void {
        _partialUpdatesAllowed = false;
    }

    private function drawDebugOverlay(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setPenWidth(1);
        dc.setColor($.Toybox.Graphics.COLOR_BLUE, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawLine(CX, 0, CX, 260);
        dc.setColor($.Toybox.Graphics.COLOR_YELLOW, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, TOP_Y, 260, TOP_Y);
    }

    private function drawHeartIcon(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, color as Number) as Void {
        dc.setColor(color, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 5, y - 5, 5); dc.fillCircle(x + 5, y - 5, 5);
        dc.fillPolygon([[x - 10, y - 2], [x + 10, y - 2], [x, y + 10]]);
    }

    private function updateHeartRate(dc as $.Toybox.Graphics.Dc) as Void {
        if ($.Toybox has :Activity) {
            var activityInfo = $.Toybox.Activity.getActivityInfo();
            var rate = (activityInfo != null) ? activityInfo.currentHeartRate : null;
            if (rate != _lastHrValue) {
                _lastHrValue = (rate != null) ? rate as $.Toybox.Lang.Number : -1;
                _lastHrStr = faceLogic.getHeartRateString(rate);
                renderHrToBuffer(dc);
            }
        }
    }

    private function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        var stats = $.Toybox.System.getSystemStats();
        _batteryLevel = stats.battery;
        var curBattDays = (stats has :batteryInDays) ? stats.batteryInDays : null;
        if (_batteryLevel != _lastBattLevel || curBattDays != _lastBattDays) {
            _lastBattLevel = _batteryLevel;
            _lastBattDays = (curBattDays != null) ? curBattDays as $.Toybox.Lang.Float : -1.0;
            _lastBattDaysShortStr = faceLogic.getBatteryDaysShortString(curBattDays as $.Toybox.Lang.Float?);
        }
        if (stats has :solarIntensity) {
            _solarIntensity = (stats.solarIntensity != null) ? stats.solarIntensity as $.Toybox.Lang.Number : 0;
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
        if (condition != null && condition != _lastWeatherCondition) {
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
        if (temp != _lastTempValue) {
            _lastTempValue = (temp != null) ? temp as $.Toybox.Lang.Number : null;
            _lastTempStr = faceLogic.getTemperatureString(temp as $.Toybox.Lang.Number?);
        }
    }

    function onEnterSleep() as Void { $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { $.Toybox.WatchUi.requestUpdate(); }
}
