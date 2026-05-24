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
    public var stepRatio as Float = 0.0;
    public var hrValue as Number = -1;
    public var hrStr as String = FaceLogic.STR_DASHES;
    public var tempStr as String = FaceLogic.STR_TEMP_DASHES;

    // Internal tracking for buffer refresh
    public var needsBackgroundRedraw as Boolean = false;

    // Complication IDs
    public var _idSteps as Complications.Id? = null;
    public var _idBattery as Complications.Id? = null;
    public var _idHR as Complications.Id? = null;
    public var _idWeatherTemp as Complications.Id? = null;

    function initialize() {
        Complications.registerComplicationChangeCallback(self.method(:onComplicationChanged));
        
        _idSteps = new Complications.Id(Complications.COMPLICATION_TYPE_STEPS);
        _idBattery = new Complications.Id(Complications.COMPLICATION_TYPE_BATTERY);
        _idHR = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);
        _idWeatherTemp = new Complications.Id(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);

        var ids = [_idSteps, _idBattery, _idHR, _idWeatherTemp];
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
        var settings = $.Toybox.System.getDeviceSettings();
        if (settings.doNotDisturb) { return; }

        var complication = Complications.getComplication(id) as $.Toybox.Complications.Complication?;
        if (complication == null) { return; }
        var val = complication.value;
        if (val == null) { return; }

        updateComplicationValue(id, val);
        $.Toybox.WatchUi.requestUpdate();
    }

    //
    // Internal helper to update internal state from complication values
    //
    private function updateComplicationValue(id as Complications.Id, val as $.Toybox.Lang.Object) as Void {
        if (id.equals(_idSteps)) {
            var info = $.Toybox.ActivityMonitor.getInfo();
            var goal = (info != null) ? info.stepGoal : null;
            stepRatio = $.FaceLogic.getStepRatio(val as $.Toybox.Lang.Numeric, goal);
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
        } else if (id.equals(_idWeatherTemp)) {
            tempStr = $.FaceLogic.getTempString(val as $.Toybox.Lang.Numeric);
        }
    }

    //
    // Force immediate data sync from all complications when waking up
    //
    public function refreshFromComplications() as Void {
        var ids = [_idSteps, _idBattery, _idHR, _idWeatherTemp];
        for (var i = 0; i < ids.size(); i++) {
            var id = ids[i];
            if (id != null) {
                var complication = Complications.getComplication(id) as $.Toybox.Complications.Complication?;
                if (complication != null && complication.value != null) {
                    updateComplicationValue(id, complication.value as $.Toybox.Lang.Object);
                }
            }
        }
    }


}
