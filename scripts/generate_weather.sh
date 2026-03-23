#!/bin/bash

SDK_PATH=$1
DOC_FILE="$SDK_PATH/doc/Toybox/Weather.html"
XML_OUT="resources/strings/weather_gen.xml"
MC_OUT="source/weatherGenerated.mc"

if [ ! -f "$DOC_FILE" ]; then
    echo "Error: SDK documentation not found at $DOC_FILE"
    exit 1
fi

# Extract conditions from the SDK documentation HTML
CONDITIONS=$(grep -o "CONDITION_[A-Z_]*" "$DOC_FILE" | sort | uniq)

# Generate XML Resources
cat << EOM > "$XML_OUT"
<strings>
EOM

for c in $CONDITIONS; do
    # Simple capitalization: remove prefix, replace _ with space, lowercase, then capitalize words
    label=$(echo "$c" | sed 's/CONDITION_//' | tr '_' ' ' | tr '[:upper:]' '[:lower:]' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
    res_id="weather_gen_$(echo "$c" | tr '[:upper:]' '[:lower:]')"
    echo "    <string id=\"$res_id\">$label</string>" >> "$XML_OUT"
done

echo "</strings>" >> "$XML_OUT"

# Generate Monkey C Mapping
cat << EOM > "$MC_OUT"
import Toybox.Weather;
import Toybox.Lang;
import Toybox.WatchUi;

module WeatherGenerated {
    function getConditionString(condition as Integer) as String? {
        switch (condition) {
EOM

for c in $CONDITIONS; do
    res_id="weather_gen_$(echo "$c" | tr '[:upper:]' '[:lower:]')"
    echo "            case $.Toybox.Weather.$c:" >> "$MC_OUT"
    echo "                return $.Toybox.WatchUi.loadResource($.Rez.Strings.$res_id) as String;" >> "$MC_OUT"
done

cat << EOM >> "$MC_OUT"
            default:
                return null;
        }
    }

    function getAllConditions() as Array<Integer> {
        return [
EOM

for c in $CONDITIONS; do
    echo "            $.Toybox.Weather.$c," >> "$MC_OUT"
done

cat << EOM >> "$MC_OUT"
        ] as Array<Integer>;
    }
}
EOM

echo "Generated $XML_OUT and $MC_OUT"
