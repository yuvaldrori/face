import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.Activity;

class faceView extends WatchUi.WatchFace {
    private var _heartRateLabel as WatchUi.Text?;
    private var _batteryLabel as WatchUi.Text?;
    private var _timeLabel as WatchUi.Text?;
    private var _dateLabel as WatchUi.Text?;
    private var _conditionLabel as WatchUi.Text?;
    private var _tempLabel as WatchUi.Text?;

    private var _weatherConditionsMap as Dictionary<Integer, ResourceId>?;

    function initialize() {
        WatchFace.initialize();
        // Uses the automatically generated mapping from WeatherGenerated.mc
        _weatherConditionsMap = WeatherGenerated.getMap();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
        _heartRateLabel = View.findDrawableById("HeartLabel") as WatchUi.Text;
        _batteryLabel = View.findDrawableById("BatteryLabel") as WatchUi.Text;
        _timeLabel = View.findDrawableById("TimeLabel") as WatchUi.Text;
        _dateLabel = View.findDrawableById("DateLabel") as WatchUi.Text;
        _conditionLabel = View.findDrawableById("ConditionLabel") as WatchUi.Text;
        _tempLabel = View.findDrawableById("TempLabel") as WatchUi.Text;
    }

    function onUpdate(dc as Dc) as Void {
        // Heart Rate
        var activityInfo = Activity.getActivityInfo();
        var rate = (activityInfo != null) ? activityInfo.currentHeartRate : null;
        if (_heartRateLabel != null) {
            _heartRateLabel.setText(faceLogic.getHeartRateString(rate));
        }

        // Battery
        var stats = System.getSystemStats();
        if (_batteryLabel != null) {
            _batteryLabel.setText(faceLogic.getBatteryString(stats.battery as Float, stats.batteryInDays as Float?));
        }

        // Time
        var clockTime = System.getClockTime();
        if (_timeLabel != null) {
            _timeLabel.setText(faceLogic.getTimeString(clockTime.hour as Number, clockTime.min as Number));
        }

        // Date
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        if (_dateLabel != null) {
            _dateLabel.setText(faceLogic.getDateString(info));
        }

        // Weather
        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            var condition = conditions.condition;
            if (condition != null) {
                var map = _weatherConditionsMap;
                var resId = (map != null && map.hasKey(condition)) ? map[condition] : null;
                var conditionLabel = _conditionLabel;
                if (conditionLabel != null) {
                    if (resId != null) {
                        conditionLabel.setText(WatchUi.loadResource(resId) as String);
                    } else {
                        // Fallback to a generic string if condition not found
                        conditionLabel.setText("Unknown");
                    }
                }
            }
            if (_tempLabel != null) {
                _tempLabel.setText(faceLogic.getTemperatureString(conditions.temperature as Number?));
            }
        }

        View.onUpdate(dc);
    }
}
