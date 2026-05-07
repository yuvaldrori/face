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
    public var _isSleepMode as $.Toybox.Lang.Boolean = false;
    
    public var _hour as $.Toybox.Lang.Number = 0;
    public var _min as $.Toybox.Lang.Number = 0;
    public var _lastFallbackMinute as $.Toybox.Lang.Number = -1;

    public var _lastTimeStr as $.Toybox.Lang.String = "";
    public var _timeWidths as $.Toybox.Lang.Array<$.Toybox.Lang.Number> = [] as $.Toybox.Lang.Array<$.Toybox.Lang.Number>;
    public var _timeTotalW as $.Toybox.Lang.Number = 0;

    // Data Controller
    private var _data as FaceComplications;

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
        _data = new FaceComplications();
    }

    //
    // Helper to safely set anti-aliasing if supported
    //
    private function setAntiAliasSafe(dc as $.Toybox.Graphics.Dc, enable as $.Toybox.Lang.Boolean) as Void {
        dc.setAntiAlias(enable);
    }

    //
    // Set up UI component dimensions and initial data
    //
    function onLayout(dc as $.Toybox.Graphics.Dc) as Void {
        _hugeFont = $.Toybox.Graphics.getVectorFont({
            :face => "RobotoCondensedBold",
            :size => $.LayoutGenerated.HUGE_FONT_SIZE
        });
        
        initializeStaticBuffer();
        var clockTime = $.Toybox.System.getClockTime();
        updateLongTermData(clockTime, dc);
    }

    //
    // Initialize the off-screen buffer for static elements
    //
    private function initializeStaticBuffer() as Void {
        if (_staticBuffer != null && _staticBuffer.get() != null) { return; }
        _staticBuffer = $.Toybox.Graphics.createBufferedBitmap({
            :width => $.LayoutGenerated.WIDTH,
            :height => $.LayoutGenerated.HEIGHT,
            :palette => FaceLogic.getRequiredPalette()
        });
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
            var inSleep = settings.doNotDisturb;
            if (inSleep != _isSleepMode) {
                _isSleepMode = inSleep;
            }

            updateLongTermData(clockTime, dc);
        }

        // Background redraw check
        if (isFullUpdate || _staticBuffer == null || _lastBufferMinute != clockTime.min || (_data.needsBackgroundRedraw && !_isSleepMode)) {
            updateStaticBuffer();
            _lastBufferMinute = clockTime.min;
            _data.needsBackgroundRedraw = false;
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
        FaceRenderer.drawRingArc(dc, $.LayoutGenerated.RING_SOLAR_R, _data.solarRatio, FaceLogic.COLOR_YELLOW, CX, CY);
        
        // 2. Steps Ring (Middle)
        FaceRenderer.drawRingArc(dc, $.LayoutGenerated.RING_STEPS_R, _data.stepRatio, FaceLogic.getStepColor(), CX, CY);
        
        // 3. Battery Ring (Inner)
        FaceRenderer.drawRingArc(dc, $.LayoutGenerated.RING_BATT_R, _data.batteryRatio, getBatteryColor(_data.batteryLevel), CX, CY);
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

        FaceRenderer.drawCachedTightText(dc, CX, Y_TIME, font, timeStr, _timeWidths, _timeTotalW, $.LayoutGenerated.TIME_TRACKING, $.DEBUG_ALIGNMENT, mainColor);
        
        if (!_isSleepMode) {
            FaceRenderer.drawHeartIcon(dc, COLOR_HEART);
            dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
            dc.drawText($.LayoutGenerated.HR_TEXT_X, Y_HR, FONT_SMALL, _data.hrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
        }

        setAntiAliasSafe(dc, false);
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
        var hrTextW = dc.getTextWidthInPixels(_data.hrStr, FONT_SMALL);
        var totalHrW = $.LayoutGenerated.HR_ICON_W + $.LayoutGenerated.HR_GAP + hrTextW;
        var hrStartX = CX - (totalHrW / 2);
        dc.drawRectangle(hrStartX, Y_HR, totalHrW, dc.getFontHeight(FONT_SMALL));
    }

    public function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        _hour = clockTime.hour as $.Toybox.Lang.Number;
        _min = clockTime.min as $.Toybox.Lang.Number;
        
        // Periodically refresh data from system as fallback (every 5 mins)
        if (_lastFallbackMinute == -1 || (_min % 5 == 0 && _lastFallbackMinute != _min)) {
            _lastFallbackMinute = _min;
            _data.updateSystemStatsFallback();
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
