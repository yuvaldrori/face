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
    private var _lastUpdateMinute as Number = -1;
    private var _lastWeatherCondition as Integer = -1;
    private var _isLowPower as Boolean = true;
    private var _unknownLabel as String = "";

    function initialize() {
        WatchFace.initialize();
        _weatherConditionsMap = WeatherGenerated.getMap();
        _unknownLabel = WatchUi.loadResource(Rez.Strings.weather_gen_condition_unknown) as String;
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
        var clockTime = System.getClockTime();
        var isFullUpdate = faceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);
        
        // HEART RATE: Every Second (if not in low power)
        if (!_isLowPower) {
            updateHeartRate();
        }

        // FULL DATA: Every Minute
        if (isFullUpdate) {
            _lastUpdateMinute = clockTime.min;
            updateLongTermData(clockTime);
        }

        // Always redraw full screen for Fenix 8
        dc.clearClip();
        View.onUpdate(dc);
    }

    private function updateHeartRate() as Void {
        var label = _heartRateLabel;
        if (label != null) {
            var activityInfo = Activity.getActivityInfo();
            var rate = (activityInfo != null) ? activityInfo.currentHeartRate : null;
            label.setText(faceLogic.getHeartRateString(rate));
        }
    }

    private function updateLongTermData(clockTime as System.ClockTime) as Void {
        var stats = System.getSystemStats();
        if (_batteryLabel != null) {
            _batteryLabel.setText(faceLogic.getBatteryString(stats.battery as Float, stats.batteryInDays as Float?));
        }

        if (_timeLabel != null) {
            _timeLabel.setText(faceLogic.getTimeString(clockTime.hour as Number, clockTime.min as Number));
        }

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (_dateLabel != null) {
            _dateLabel.setText(faceLogic.getDateString(info));
        }

        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            updateWeather(conditions);
        }
    }

    private function updateWeather(conditions as Weather.CurrentConditions) as Void {
        var condition = conditions.condition;
        if (condition != null && _conditionLabel != null) {
            if (condition != _lastWeatherCondition) {
                _lastWeatherCondition = condition;
                var map = _weatherConditionsMap;
                var resId = (map != null && map.hasKey(condition)) ? map[condition] : null;
                if (resId != null) {
                    _conditionLabel.setText(WatchUi.loadResource(resId) as String);
                } else {
                    _conditionLabel.setText(_unknownLabel);
                }
            }
        }
        if (_tempLabel != null) {
            _tempLabel.setText(faceLogic.getTemperatureString(conditions.temperature as Number?));
        }
    }

    function onEnterSleep() as Void {
        _isLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isLowPower = false;
        WatchUi.requestUpdate();
    }
}
