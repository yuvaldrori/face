import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FaceApp extends $.Toybox.Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as $.Toybox.Lang.Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as $.Toybox.Lang.Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [$.Toybox.WatchUi.Views] or [$.Toybox.WatchUi.Views, $.Toybox.WatchUi.InputDelegates] {
        return [ new FaceView() ];
    }

}

function getApp() as FaceApp {
    return $.Toybox.Application.getApp() as FaceApp;
}
