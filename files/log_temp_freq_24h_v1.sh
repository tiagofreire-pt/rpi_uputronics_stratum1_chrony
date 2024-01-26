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
	frequency_raw=$(chronyc tracking | awk '/Frequency/ {print $3, $4, $5}')

	# Extract numeric value and determine sign based on "slow" or "fast" suffix
	frequency=$(awk -v fr="$frequency_raw" 'BEGIN {
		if (fr != "ppm") {
			value = fr + 0;  # Convert to numeric, handling cases like "slow" or "fast"
			if (value != 0) {
				if (index(fr, "slow") > 0) {
					value *= -1;
				}
				printf "%.3f", value;
			} else {
				print "Error: Unable to extract numeric frequency value from '" fr "'"
				exit 1
			}
		} else {
			print "Error: Unexpected frequency value: '" fr "'"
			exit 1
		}
	}')

	# Check for errors in frequency extraction
	if [ $? -ne 0 ]; then
		echo "Error: Unable to extract numeric frequency value from '$frequency_raw'"
		exit 1
	fi

	# Add debugging output
	echo "Frequency: $frequency"

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
gnuplot <<-EOF
    set terminal png
    set output "$PLOT_FILE"
    set title "Frequency and Temperature over 24 Hours"
    set xlabel "Time (HH:MM:SS)"
    set ylabel "Frequency and Temperature"
    plot "$DATA_FILE" using 1:2 with lines title "Frequency", "$DATA_FILE" using 1:3 with lines title "Temperature"
EOF

# Display the plot file
xdg-open "$PLOT_FILE" >/dev/null 2>&1 &

# Clean up the data file
rm "$DATA_FILE"
