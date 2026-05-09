//
// FaceComplications.mc
// Encapsulates Toybox Complications management and data state
//

import Toybox.Complications;
import Toybox.Lang;
import Toybox.ActivityMonitor;
import Toybox.WatchUi;

class FaceComplications {
    
    // Data State
    public var batteryLevel as Float = 0.0;
    public var batteryRatio as Float = 0.0;
    public var solarRatio as Float = 0.0;
    public var stepRatio as Float = 0.0;
    public var hrValue as Number = -1;
    public var hrStr as String = FaceLogic.STR_DASHES;

    // Internal tracking for buffer refresh
    public var needsBackgroundRedraw as Boolean = false;

    // Complication IDs
    public var _idSolar as Complications.Id? = null;
    public var _idSteps as Complications.Id? = null;
    public var _idBattery as Complications.Id? = null;
    public var _idHR as Complications.Id? = null;

    function initialize() {
        Complications.registerComplicationChangeCallback(self.method(:onComplicationChanged));
        
        _idSolar = new Complications.Id(Complications.COMPLICATION_TYPE_SOLAR_INPUT);
        _idSteps = new Complications.Id(Complications.COMPLICATION_TYPE_STEPS);
        _idBattery = new Complications.Id(Complications.COMPLICATION_TYPE_BATTERY);
        _idHR = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);

        var ids = [_idSolar, _idSteps, _idBattery, _idHR];
        for (var i = 0; i < ids.size(); i++) {
            try {
                Complications.subscribeToUpdates(ids[i]);
            } catch (e) {
                if ($.Toybox.System has :println) {
                    var msg = e.getErrorMessage();
                    if (msg != null && msg.find("Permission") != null) {
                        $.Toybox.System.println("Permission Denied: Complication " + ids[i]);
                    } else {
                        $.Toybox.System.println("Subscription Failed: " + ids[i] + " (" + (msg != null ? msg : "Unknown Error") + ")");
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
        var val = complication.value;
        if (val == null) { return; }

        if (id.equals(_idSolar)) {
            solarRatio = $.FaceLogic.getSolarRatio(val as $.Toybox.Lang.Numeric);
            needsBackgroundRedraw = true;
        } else if (id.equals(_idSteps)) {
            var info = $.Toybox.ActivityMonitor.getInfo();
            if (info != null) {
                stepRatio = $.FaceLogic.getStepRatio(val as $.Toybox.Lang.Numeric, info.stepGoal);
            } else {
                stepRatio = 0.0;
            }
            needsBackgroundRedraw = true;
        } else if (id.equals(_idBattery)) {
            batteryLevel = (val as $.Toybox.Lang.Numeric).toFloat();
            batteryRatio = batteryLevel / $.FaceLogic.PERCENT_MAX;
            needsBackgroundRedraw = true;
        } else if (id.equals(_idHR)) {
            var hr = (val as $.Toybox.Lang.Number);
            if (hr != hrValue) {
                hrValue = hr;
                hrStr = $.FaceLogic.getHeartRateString(hr == -1 ? null : hr);
            }
        }
        
        $.Toybox.WatchUi.requestUpdate();
    }

    //
    // Periodically refresh data from system as fallback (every 5 mins)
    //
    public function updateSystemStatsFallback() as Void {
        var stats = $.Toybox.System.getSystemStats();
        batteryLevel = stats.battery;
        batteryRatio = batteryLevel / $.FaceLogic.PERCENT_MAX;
        
        solarRatio = $.FaceLogic.getSolarRatio(stats.solarIntensity);

        var info = $.Toybox.ActivityMonitor.getInfo();
        if (info != null) {
            stepRatio = $.FaceLogic.getStepRatio(info.steps, info.stepGoal);
        } else {
            stepRatio = 0.0;
        }
    }
}
