#!/bin/bash

SDK_PATH=$1
DOC_FILE="$SDK_PATH/doc/Toybox/Weather.html"
XML_OUT="resources/strings/weather_gen.xml"
MC_OUT="source/weatherGenerated.mc"

if [ ! -f "$DOC_FILE" ]; then
    echo "Error: SDK documentation not found at $DOC_FILE"
    exit 1
fi

# Extract conditions
CONDITIONS=$(grep -oP "CONDITION_[A-Z0-9_]+" "$DOC_FILE" | sort -u)

# Generate XML
echo '<strings>' > "$XML_OUT"
for c in $CONDITIONS; do
    # Convert CONDITION_PARTLY_CLOUDY to "Partly cloudy"
    label=$(echo "$c" | sed 's/CONDITION_//' | tr '_' ' ' | tr '[:upper:]' '[:lower:]')
    label="$(tr '[:lower:]' '[:upper:]' <<< ${label:0:1})${label:1}"
    
    # Create valid resource ID (lowercase with underscores)
    res_id="weather_gen_$(echo "$c" | tr '[:upper:]' '[:lower:]')"
    
    echo "    <string id=\"$res_id\">$label</string>" >> "$XML_OUT"
done
echo '</strings>' >> "$XML_OUT"

# Generate Monkey C Mapping
cat << EOM > "$MC_OUT"
import Toybox.Weather;
import Toybox.Lang;

module WeatherGenerated {
    function getMap() as Dictionary<Integer, ResourceId> {
        return {
EOM

for c in $CONDITIONS; do
    res_id="weather_gen_$(echo "$c" | tr '[:upper:]' '[:lower:]')"
    echo "            Weather.$c => Rez.Strings.$res_id," >> "$MC_OUT"
done

cat << EOM >> "$MC_OUT"
        } as Dictionary<Integer, ResourceId>;
    }
}
EOM

echo "Generated $XML_OUT and $MC_OUT"
