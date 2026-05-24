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

    public var _lastTimeStr as $.Toybox.Lang.String = "";
    public var _timeWidths as $.Toybox.Lang.Array<$.Toybox.Lang.Number> = [] as $.Toybox.Lang.Array<$.Toybox.Lang.Number>;
    public var _timeCharStrings as $.Toybox.Lang.Array<$.Toybox.Lang.String> = [] as $.Toybox.Lang.Array<$.Toybox.Lang.String>;
    public var _timeTotalW as $.Toybox.Lang.Number = 0;

    // Data Controller
    public var _data as FaceComplications;

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
    public var _staticBuffer as $.Toybox.Graphics.BufferedBitmapReference? = null;
    private var _lastBufferMinute as $.Toybox.Lang.Number = -1;
    private var _hugeFont as $.Toybox.Graphics.VectorFont? = null;
    private var _hugeFontHeight as $.Toybox.Lang.Number = 0;

    function initialize() {
        WatchFace.initialize();
        _data = new FaceComplications();
    }

    //
    // Set up UI component dimensions and initial data
    //
    function onLayout(dc as $.Toybox.Graphics.Dc) as Void {
        _hugeFont = $.Toybox.Graphics.getVectorFont({
            :face => "RobotoCondensedBold",
            :size => $.LayoutGenerated.HUGE_FONT_SIZE
        });
        
        var font = _hugeFont != null ? _hugeFont : $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
        _hugeFontHeight = dc.getFontHeight(font);
        
        initializeStaticBuffer();
        var clockTime = $.Toybox.System.getClockTime();
        updateLongTermData(clockTime, dc);
    }

    //
    // Initialize the off-screen buffer for static elements
    //
    public function initializeStaticBuffer() as Void {
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
        if (_staticBuffer == null || _staticBuffer.get() == null) {
            initializeStaticBuffer();
        }
        dc.setAntiAlias(false);
        dc.clearClip();
        
        var clockTime = $.Toybox.System.getClockTime();
        var isFullUpdate = $.FaceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);

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
        return (level <= $.FaceLogic.BATT_THRESHOLD_LOW) ? COLOR_HEART : $.FaceLogic.COLOR_GREEN;
    }

    private function updateStaticBuffer() as Void {
        var bufferRef = _staticBuffer;
        if (bufferRef == null) { return; }
        var buffer = bufferRef.get();
        if (!(buffer instanceof $.Toybox.Graphics.BufferedBitmap)) { return; }
        renderStatic(buffer.getDc());
    }

    public function renderStatic(dc as $.Toybox.Graphics.Dc) as Void {
        // Use fillRectangle for a more robust clear on MIP drivers
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.fillRectangle(0, 0, $.LayoutGenerated.WIDTH, $.LayoutGenerated.HEIGHT);
        
        if (!_isSleepMode) {
            renderAllRings(dc);
            $.FaceRenderer.drawHeartIcon(dc, COLOR_HEART);
        }
    }

    private function renderAllRings(dc as $.Toybox.Graphics.Dc) as Void {
        // Apply horizontal clip to straighten the top edges of the rings
        dc.setClip(0, $.LayoutGenerated.RING_CLIP_Y, $.LayoutGenerated.WIDTH, $.LayoutGenerated.HEIGHT - $.LayoutGenerated.RING_CLIP_Y);
        
        // 1. Battery Ring (Outer)
        $.FaceRenderer.drawRingArc(dc, $.LayoutGenerated.RING_BATT_R, _data.batteryRatio, getBatteryColor(_data.batteryLevel), CX, CY, RING_WIDTH);
        
        // 2. Steps Ring (Inner)
        $.FaceRenderer.drawRingArc(dc, $.LayoutGenerated.RING_STEPS_R, _data.stepRatio, $.FaceLogic.getStepColor(), CX, CY, RING_WIDTH);
        
        dc.clearClip();
    }

    private function updateTimeMetrics(dc as $.Toybox.Graphics.Dc, timeStr as $.Toybox.Lang.String, font as $.Toybox.Graphics.FontDefinition or $.Toybox.Graphics.VectorFont) as Void {
        _lastTimeStr = timeStr;
        var chars = timeStr.toCharArray();
        var size = chars.size();
        _timeWidths = new [size] as $.Toybox.Lang.Array<$.Toybox.Lang.Number>;
        _timeCharStrings = new [size] as $.Toybox.Lang.Array<$.Toybox.Lang.String>;
        _timeTotalW = 0;
        for (var i = 0; i < size; i++) {
            var charStr = chars[i].toString();
            _timeCharStrings[i] = charStr;
            _timeWidths[i] = dc.getTextWidthInPixels(charStr, font) as $.Toybox.Lang.Number;
            _timeTotalW += _timeWidths[i];
            if (i < size - 1) { _timeTotalW += $.LayoutGenerated.TIME_TRACKING; }
        }
    }

    public function renderDynamicUI(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setAntiAlias(true);

        var mainColor = _isSleepMode ? $.FaceLogic.COLOR_DK_GRAY : COLOR_MAIN;
        var font = _hugeFont != null ? _hugeFont : $.Toybox.Graphics.FONT_NUMBER_THAI_HOT;
        var timeStr = $.FaceLogic.getTimeString(_hour, _min);
        
        // Ensure metrics are up to date if time changed
        if (!timeStr.equals(_lastTimeStr)) {
            updateTimeMetrics(dc, timeStr, font);
        }

        $.FaceRenderer.drawCachedTightText(dc, CX, Y_TIME, font, _timeCharStrings, _timeWidths, _timeTotalW, $.LayoutGenerated.TIME_TRACKING, $.DEBUG_ALIGNMENT, mainColor, _hugeFontHeight);

        if (_isSleepMode) { 
            dc.setAntiAlias(false);
            return; 
        }

        dc.setColor(COLOR_MAIN, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawText($.LayoutGenerated.HR_TEXT_X, Y_HR, FONT_SMALL, _data.hrStr, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
        
        // Temperature Centered
        dc.setColor(mainColor, $.Toybox.Graphics.COLOR_TRANSPARENT);
        dc.drawText($.LayoutGenerated.CX, $.LayoutGenerated.Y_WEATHER, FONT_SMALL, _data.tempStr, $.Toybox.Graphics.TEXT_JUSTIFY_CENTER);

        dc.setAntiAlias(false);
    }

    private function drawDebugOverlay(dc as $.Toybox.Graphics.Dc) as Void {
        dc.setAntiAlias(false);
        dc.setPenWidth($.LayoutGenerated.PEN_WIDTH_DEBUG);
        
        // 1. Grid & Screen Edge
        dc.setColor($.FaceLogic.COLOR_RED, COLOR_BG);
        dc.drawLine(CX, 0, CX, $.LayoutGenerated.HEIGHT); 
        dc.drawLine(0, CY, $.LayoutGenerated.WIDTH, CY);
        dc.drawCircle(CX, CY, $.LayoutGenerated.SCREEN_R);

        // 2. Ring Guides (Centers)
        dc.setColor($.FaceLogic.COLOR_DK_GRAY, COLOR_BG);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_BATT_R);
        dc.drawCircle(CX, CY, $.LayoutGenerated.RING_STEPS_R);

        // 3. Data Boundaries (Green)
        dc.setColor($.FaceLogic.COLOR_GREEN, COLOR_BG);
        
        // HR Group
        var hrTextW = dc.getTextWidthInPixels(_data.hrStr, FONT_SMALL);
        var hrLeft = $.LayoutGenerated.HEART_LOBE_L_X - $.LayoutGenerated.HEART_LOBE_R;
        var hrWidth = ($.LayoutGenerated.HR_TEXT_X + hrTextW) - hrLeft;
        dc.drawRectangle(hrLeft, Y_HR, hrWidth, dc.getFontHeight(FONT_SMALL));

        // Temperature Group
        var tempTextW = dc.getTextWidthInPixels(_data.tempStr, FONT_SMALL);
        var tempStartX = CX - (tempTextW / 2);
        dc.drawRectangle(tempStartX, $.LayoutGenerated.Y_WEATHER, tempTextW, dc.getFontHeight(FONT_SMALL));

        // 4. Touch Targets (Cyan/Blue)
        dc.setColor($.FaceLogic.COLOR_CYAN, COLOR_BG);
        
        // HR Touch Target
        var hrTouchW = $.LayoutGenerated.TOUCH_HR_W;
        var hrTouchH = $.LayoutGenerated.TOUCH_HR_H;
        dc.drawRectangle(CX - hrTouchW/2, Y_HR, hrTouchW, hrTouchH);

        // Temp Touch Target
        var tempTouchW = $.LayoutGenerated.TOUCH_TEMP_W;
        var tempTouchH = $.LayoutGenerated.TOUCH_TEMP_H;
        dc.drawRectangle(CX - tempTouchW/2, $.LayoutGenerated.Y_WEATHER, tempTouchW, tempTouchH);
    }

    public function updateLongTermData(clockTime as $.Toybox.System.ClockTime, dc as $.Toybox.Graphics.Dc) as Void {
        _hour = clockTime.hour as $.Toybox.Lang.Number;
        _min = clockTime.min as $.Toybox.Lang.Number;
    }

    function onEnterSleep() as Void { _isSleepMode = true; _lastUpdateMinute = -1; $.Toybox.WatchUi.requestUpdate(); }
    function onExitSleep() as Void { 
        _isSleepMode = false; 
        _lastUpdateMinute = -1; 
        _lastBufferMinute = -1; // Force background redraw when waking up
        _data.refreshFromComplications(); // Query latest values immediately on wake
        $.Toybox.WatchUi.requestUpdate(); 
    }
}
