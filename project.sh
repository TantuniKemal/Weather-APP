#!/bin/bash
data_file="/home/erkan/data.txt"
dataC_file="/home/erkan/dataC.txt"
dataF_file="/home/erkan/dataF.txt"
cold_file="/home/erkan/cold.txt"
snow_file="/home/erkan/snow.txt"
rain_file="/home/erkan/rain.txt"
lucia_file="/home/erkan/lucia.txt"
API_KEY="6a0d890c75dce638fe4ac030f893c3ce"
BASE_URL="http://api.openweathermap.org/data/2.5/forecast"

convertCelsius_to_Fahrenheit() {
    input_file=$1
    output_file=$2
    # again reset last dataF file
    >"$output_file"
    while IFS=$',' read -r date temp info icon; do
        #update file with temp conver Fahreneit
        fahrenheit=$(echo "scale=2; ($temp * 9/5) + 32" | bc)
        echo -e "$date,$fahrenheit,$info,$icon" >>"$output_file"
    done <"$input_file"
}
get_weather_data() {
    city="$1"
    country="$2"
    # api will work using input city and country
    response=$(curl -s "${BASE_URL}?q=${city},${country}&appid=${API_KEY}&units=metric")
    # if not find return error
    if [[ -z "$response" ]]; then
        echo "API not give response"
        error_message=$(echo "$response" | jq -r '.message')
        yad --title="ERROR" \
            --text="$error_message" \
            --center \
            --width=400 \
            --height=150 \
            --button="Exit:0"
        return 1
    else
        # reset data_file
        >"$data_file"
        while IFS= read -r forecast; do
            date=$(echo "$forecast" | jq -r '.dt_txt')
            temp=$(echo "$forecast" | jq -r '.main.temp')
            forecast_desc=$(echo "$forecast" | jq -r '.weather[0].description')
            # split and find in JSON data format for date temp forecast
            dates+=("$date")
            temps+=("$temp")
            forecasts+=("$forecast_desc")
        done < <(echo "$response" | jq -c '.list[]')
    fi
    #print each data arrays and create data_file
    for i in "${!dates[@]}"; do
        echo -e "${dates[i]}\t${temps[i]}\t${forecasts[i]}" >>"$data_file"
    done
}
get_form_entry() {
    form_entry=$(yad --form \
        --title="Weather Application" \
        --text="\nWeather App\n" \
        --field="City" \
        --field="Country" \
        --width=600 \
        --height=250 \
        --image="/home/erkan/newicon/main.png" \
        --button="Exit:1" \
        --button="Show:0")
}
lucia() {
    response_file="$1"
    while true; do
        response=$(yad --form --title="Lucia" \
            --text="What can I help with?" \
            --button="➔" \
            --field="Message Lucia" --width=400)
        # take question or input and find with main letter
        if echo "$response" | grep -iqE "wear|take"; then
            # update image and suggest
            image="/home/erkan/luciaicon/coat.jpg"
            suggest=$(head -n 6 "$response_file")
        elif echo "$response" | grep -iqE "movie|book|outside"; then
            image="/home/erkan/luciaicon/ok.png"
            suggest=$(sed -n '7,12p' "$response_file")
        elif echo "$response" | grep -iq "activity"; then
            image="/home/erkan/luciaicon/idea.png"
            suggest=$(sed -n '13,19p' "$response_file")
        else
            image="/home/erkan/luciaicon/goodbye.png"
            suggest=$(tail -n 3 "$response_file")
        fi
        yad --title="Lucia" \
            --text="$suggest" \
            --image="$image" \
            --button="Exit:1" \
            --button="Ask again:0"
        if [[ "$?" -eq 1 ]]; then
            exit 0
        fi
        # last output clikc button 1 exit
    done
}
get_app() {
    # ask user Celcius or Fahreneit
    selected_unit=$(yad --title="Temperature Preference" \
        --text="Select Unit" \
        --list \
        --radiolist \
        --column="Select" \
        --column="UNIT" \
        TRUE "Celcius" \
        FALSE "Fahrenheit" \
        --width=300 --height=200)
    >"$dataC_file"
    # set up 4th icon column and reach last data folder
    awk -F'\t' 'BEGIN {OFS=","} {print $1, $2, $3}' "$data_file" | while IFS=$',' read -r date temp status; do

        if echo "$status" | grep -iq "cloud"; then
            icon="☁️"
        elif echo "$status" | grep -iq "rain"; then
            icon="☔"
        elif echo "$status" | grep -iq "snow"; then
            icon="❄️"
        else
            icon="☀️"
        fi

        echo -e "$date,$temp,$status,$icon" >>"$dataC_file"
    done
    # if fahreneit choosen
    >"$lucia_file"
    if [[ "$selected_unit" == *"Fahrenheit"* ]]; then
        convertCelsius_to_Fahrenheit "$dataC_file" "$dataF_file"
        head -n 1 "$dataF_file" | while IFS=$',' read -r date temp status icon; do

            if echo -e "$status" | grep -iq "cloud"; then
                image="/home/erkan/newicon/cloud.png"
            elif echo -e "$status" | grep -iq "rain"; then
                image="/home/erkan/newicon/rain.png"
            elif echo -e "$status" | grep -iq "snow"; then
                image="/home/erkan/newicon/snow.png"
            else
                image="/home/erkan/newicon/sun.png"
            fi
            echo "$status" >>"$lucia_file"
            yad --text="City:$city\n\nCountry:$country\n\nDate: $date\n\nTemperature: $temp °F\n\nForecast: $status" \
                --title="Weather Information" \
                --image="$image" \
                --width=400 \
                --height=300 \
                --button="Ask Lucia:0" \
                --button="Exit:2" \
                --button="See more:1"
        done
        ans="$?"
        if [[ "$ans" -eq 1 ]]; then
            yad_list=$(awk -F',' 'BEGIN {OFS=","} {print $1, $2, $3, $4}' "$dataF_file" | while IFS=',' read -r date temp status icon; do
                status=$(echo "$status" | sed 's/ /_/g')
                echo "'$date' '$temp' '$status' '$icon'"
            done)
            # show 5 days data with per 3 hours intervals
            yad --list \
                --title="Weather Information" \
                --column="Date" --column="Time" --column="Temperature (°F)" --column="Forecast" --column="Icon" \
                $yad_list \
                --width=600 --height=400 --button="OK:0" --button="Cancel:1"
        elif [[ "$ans" -eq 0 ]]; then
            if cat "$lucia_file" | grep -iqE "cloud|sky"; then
                lucia "$cold_file"
            elif cat "$lucia_file" | grep -iqE "snow"; then
                lucia "$snow_file"
            else
                lucia "$rain_file"
            fi
        else
            exit 0
        fi
    else
        head -n 1 "$dataC_file" | while IFS=$',' read -r date temp status icon; do

            if echo -e "$status" | grep -iq "cloud"; then
                image="/home/erkan/newicon/cloud.png"
            elif echo -e "$status" | grep -iq "rain"; then
                image="/home/erkan/newicon/rain.png"
            elif echo -e "$status" | grep -iq "snow"; then
                image="/home/erkan/newicon/snow.png"
            else
                image="/home/erkan/newicon/sun.png"
            fi
            echo "$status" >>"$lucia_file"
            yad --text="City:$city\n\nCountry:$country\n\nDate: $date\n\nTemperature: $temp °C\n\nForecast: $status" \
                --title="Weather Information" \
                --image="$image" \
                --width=400 \
                --height=300 \
                --button="Ask Lucia:0" \
                --button="Exit:2" \
                --button="See more:1"
        done
        ans="$?"
        if [[ "$ans" -eq 1 ]]; then
            yad_list=$(awk -F',' 'BEGIN {OFS=","} {print $1, $2, $3, $4}' "$dataC_file" | while IFS=',' read -r date temp status icon; do
                status=$(echo "$status" | sed 's/ /_/g')
                echo "'$date' '$temp' '$status' '$icon'"
            done)
            # show 5 days data with per 3 hours intervals
            yad --list \
                --title="Weather Information" \
                --column="Date" --column="Time" --column="Temperature (°C)" --column="Forecast" --column="Icon" \
                $yad_list \
                --width=600 --height=400 --button="OK:0" --button="Cancel:1"
        elif [[ "$ans" -eq 0 ]]; then
            if cat "$lucia_file" | grep -iqE "cloud|sky"; then
                lucia "$cold_file"
            elif cat "$lucia_file" | grep -iqE "snow"; then
                lucia "$snow_file"
            else
                lucia "$rain_file"
            fi
        else
            exit 0
        fi
    fi

}
get_form_entry
# split, take citu and country
city=$(echo "$form_entry" | awk -F'|' '{print $1}')
country=$(echo "$form_entry" | awk -F'|' '{print $2}')
# if user do not enter any input
check=0
while [[ $check -ne 1 ]]; do
    if [[ -z "$city" || -z "$country" ]]; then
        yad --title="ERROR" \
            --text="Please enter city and country!" \
            --center \
            --image=dialog-warning \
            --width=300 \
            --height=150 \
            --button="Back:0"
        get_form_entry
        city=$(echo "$form_entry" | awk -F'|' '{print $1}')
        country=$(echo "$form_entry" | awk -F'|' '{print $2}')
    else
        # if user enter city and country loop finish
        check=1
    fi
done

get_weather_data "$city" "$country"
get_app
