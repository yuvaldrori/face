//
// faceDelegate.mc
// Input delegate for handling touch complications on Fenix 8
//

import Toybox.WatchUi;
import Toybox.Complications;
import Toybox.Graphics;

class FaceDelegate extends $.Toybox.WatchUi.WatchFaceDelegate {

    private var _view as FaceView;

    function initialize(view as FaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //
    // Handle tap events to launch complication widgets
    //
    function onPress(evt as $.Toybox.WatchUi.ClickEvent) as $.Toybox.Lang.Boolean {
        var coords = evt.getCoordinates();
        var x = coords[0];
        var y = coords[1];
        
        var data = _view._data;
        var cx = $.LayoutGenerated.CX;

        // 1. Heart Rate Area Check
        var hrY = $.LayoutGenerated.Y_HR;
        var hrH = $.LayoutGenerated.TOUCH_HR_H;
        var hrW = $.LayoutGenerated.TOUCH_HR_W;
        if (y >= hrY && y <= (hrY + hrH) && x >= (cx - hrW/2) && x <= (cx + hrW/2)) {
            var id = data._idHR;
            if (id != null) {
                Complications.exitTo(id as Complications.Id);
                return true;
            }
        }

        // 2. Temperature Area Check
        var tempY = $.LayoutGenerated.Y_WEATHER;
        var tempH = $.LayoutGenerated.TOUCH_TEMP_H;
        var tempW = $.LayoutGenerated.TOUCH_TEMP_W;
        if (y >= tempY && y <= (tempY + tempH) && x >= (cx - tempW/2) && x <= (cx + tempW/2)) {
            var id = data._idWeatherTemp;
            if (id != null) {
                Complications.exitTo(id as Complications.Id);
                return true;
            }
        }

        return false;
    }
}
