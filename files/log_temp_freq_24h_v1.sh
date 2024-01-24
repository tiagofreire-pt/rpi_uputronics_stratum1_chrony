#!/bin/bash

# Define the file paths for storing data
DATA_FILE="/tmp/plot_data.txt"
PLOT_FILE="/tmp/plot.png"

# Create a header for the data file with semicolon separator
echo "Time;Frequency;Temperature" > "$DATA_FILE"

# Calculate the number of iterations for 24 hours with measurements every 20 seconds
iterations=$((24 * 60 * 60 / 20))
counter=0

# Run the loop for the specified iterations
while [ "$counter" -lt "$iterations" ]; do
    # Get the current time
    current_time=$(date +"%T")

    # Get the frequency using chronyc tracking
    frequency=$(chronyc tracking | awk '/Frequency/ {print $3}')

    # Get the temperature and format to three decimal places in Celsius
    temperature=$(awk '{printf "%.3f", $1 / 1000}' /sys/class/thermal/thermal_zone0/temp)

    # Append data to the data file with semicolon separator
    echo "$current_time;$frequency;$temperature" >> "$DATA_FILE"

    # Increment counter
    counter=$((counter + 1))

    # Wait for 20 seconds before the next measurement
    sleep 20
done

# Use gnuplot to create the plot
gnuplot -persist <<-EOF
    set terminal png
    set output "$PLOT_FILE"
    set title "Frequency and Temperature over 24 Hours"
    set xlabel "Time (HH:MM:SS)"
    set ylabel "Frequency and Temperature"
    plot "$DATA_FILE" using 1:2 with lines title "Frequency", "$DATA_FILE" using 1:3 with lines title "Temperature"
EOF

# Clean up the data file
rm "$DATA_FILE"

# Display the plot file
xdg-open "$PLOT_FILE"
