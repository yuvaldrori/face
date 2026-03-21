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
        var clockTime = System.getClockTime();
        var isFullUpdate = faceLogic.needsFullUpdate(_lastUpdateMinute, clockTime.min);
        _lastUpdateMinute = clockTime.min;

        // Heart Rate - Always update data every second
        var activityInfo = Activity.getActivityInfo();
        var rate = (activityInfo != null) ? activityInfo.currentHeartRate : null;
        if (_heartRateLabel != null) {
            _heartRateLabel.setText(faceLogic.getHeartRateString(rate));
        }

        if (isFullUpdate) {
            // Full data refresh: Only recalculate these strings once a minute
            var stats = System.getSystemStats();
            if (_batteryLabel != null) {
                _batteryLabel.setText(faceLogic.getBatteryString(stats.battery as Float, stats.batteryInDays as Float?));
            }

            if (_timeLabel != null) {
                _timeLabel.setText(faceLogic.getTimeString(clockTime.hour as Number, clockTime.min as Number));
            }

            var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            if (_dateLabel != null) {
                _dateLabel.setText(faceLogic.getDateString(info));
            }

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
                            conditionLabel.setText("Unknown");
                        }
                    }
                }
                if (_tempLabel != null) {
                    _tempLabel.setText(faceLogic.getTemperatureString(conditions.temperature as Number?));
                }
            }
        }

        // Always clear any clips and redraw the full screen to prevent black screen issues
        dc.clearClip();
        View.onUpdate(dc);
    }
}
