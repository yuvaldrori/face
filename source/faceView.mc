import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.SensorHistory;

class faceView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Get and show the current heart rate
        var view = View.findDrawableById("HeartLabel") as Text;
        var sensorIter = Toybox.SensorHistory.getHeartRateHistory({:period => 1});
        var rateString = "<3 --";
        if (sensorIter != null) {
            var rate = sensorIter.next().data;
            if (rate != null) {
                rateString = Lang.format("<3 $1$", [rate]);
            }
        }
        view.setText(rateString);

        // Get and show the current battery level
        view = View.findDrawableById("BatteryLabel") as Text;
        var stats = System.getSystemStats();
        var indicator = "[||||}";
        if (stats.battery <= 25) {
            indicator = "[|   }";
        } else if (stats.battery <= 50) {
            indicator = "[||  }";
        } else if (stats.battery <= 75) {
            indicator = "[||| }";
        } else if (stats.battery <= 100) {
            indicator = "[||||}";
        }
        var days = Lang.format("$1$ $2$ days", [indicator, stats.batteryInDays.format("%d")]);
        view.setText(days);

        // Get and show the current time
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%02d")]);
        view = View.findDrawableById("TimeLabel") as Text;
        view.setText(timeString);

        // Get and show the current date
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        view = View.findDrawableById("DateLabel") as Text;
        var date = Lang.format("$1$ $2$ $3$ $4$", [info.day_of_week, info.month, info.day, info.year]);
        view.setText(date);

        // Get and show the current weather
        var weatherConditions = {
            Weather.CONDITION_CLEAR => "Clear",
            Weather.CONDITION_PARTLY_CLOUDY => "Partly cloudy",
            Weather.CONDITION_MOSTLY_CLOUDY => "Mostly cloudy",
            Weather.CONDITION_RAIN => "Rain",
            Weather.CONDITION_SNOW => "Snow",
            Weather.CONDITION_WINDY => "Windy",
            Weather.CONDITION_THUNDERSTORMS => "Thunderstorms",
            Weather.CONDITION_WINTRY_MIX=> "Wintry mix",
            Weather.CONDITION_FOG => "Fog",
            Weather.CONDITION_HAZY => "Hazy",
            Weather.CONDITION_HAIL => "Hail",
            Weather.CONDITION_SCATTERED_SHOWERS => "Scattered showers",
            Weather.CONDITION_SCATTERED_THUNDERSTORMS => "Scattered thunderstorms",
            Weather.CONDITION_UNKNOWN_PRECIPITATION => "Unknown precipitation",
            Weather.CONDITION_LIGHT_RAIN => "Light rain",
            Weather.CONDITION_HEAVY_RAIN => "Heavy rain",
            Weather.CONDITION_LIGHT_SNOW => "Light snow",
            Weather.CONDITION_HEAVY_SNOW => "Heavy snow",
            Weather.CONDITION_LIGHT_RAIN_SNOW => "Light rain snow",
            Weather.CONDITION_HEAVY_RAIN_SNOW => "Heavy rain snow",
            Weather.CONDITION_CLOUDY => "Cloudy",
            Weather.CONDITION_RAIN_SNOW => "Rain snow",
            Weather.CONDITION_PARTLY_CLEAR => "Partly clear",
            Weather.CONDITION_MOSTLY_CLEAR => "Mostly clear",
            Weather.CONDITION_LIGHT_SHOWERS => "Light showers",
            Weather.CONDITION_SHOWERS => "Showers",
            Weather.CONDITION_HEAVY_SHOWERS => "Heavy showers",
            Weather.CONDITION_CHANCE_OF_SHOWERS => "Chance of showers",
            Weather.CONDITION_CHANCE_OF_THUNDERSTORMS => "Chance of thunderstorms",
            Weather.CONDITION_MIST => "Mist",
            Weather.CONDITION_DUST => "Dust",
            Weather.CONDITION_DRIZZLE => "Drizzle",
            Weather.CONDITION_TORNADO => "Tornado",
            Weather.CONDITION_SMOKE => "Smoke",
            Weather.CONDITION_ICE => "Ice",
            Weather.CONDITION_SAND => "Sand",
            Weather.CONDITION_SQUALL => "Squall",
            Weather.CONDITION_SANDSTORM => "Sandstorm",
            Weather.CONDITION_VOLCANIC_ASH => "Volcanic ash",
            Weather.CONDITION_HAZE => "Haze",
            Weather.CONDITION_FAIR => "Fair",
            Weather.CONDITION_HURRICANE => "Hurricane",
            Weather.CONDITION_TROPICAL_STORM => "Tropical storm",
            Weather.CONDITION_CHANCE_OF_SNOW => "Chance of snow",
            Weather.CONDITION_CHANCE_OF_RAIN_SNOW => "Chance of rain snow",
            Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN => "Cloudy chance of rain",
            Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW => "Cloudy chance of snow",
            Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW => "Cloudy chance of rain snow",
            Weather.CONDITION_FLURRIES => "Flurries",
            Weather.CONDITION_FREEZING_RAIN => "Freezing rain",
            Weather.CONDITION_SLEET => "Sleet",
            Weather.CONDITION_ICE_SNOW => "Ice snow",
            Weather.CONDITION_THIN_CLOUDS => "Thin clouds",
            Weather.CONDITION_UNKNOWN => "Unknown"
        };

        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            view = View.findDrawableById("ConditionLabel") as Text;
            var condition = weatherConditions[conditions.condition];
            view.setText(condition);
            view = View.findDrawableById("TempLabel") as Text;
            var temparature = Lang.format("$1$°", [conditions.temperature.format("%02d")]);
            view.setText(temparature);
        }

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }

}
