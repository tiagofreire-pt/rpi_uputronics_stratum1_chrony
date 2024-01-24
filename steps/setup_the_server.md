# Setup the server

## Upgrade your system and install the required software


> sudo apt update && sudo apt upgrade -y
> 
> sudo apt install gpsd gpsd-tools gpsd-clients pps-tools chrony minicom gnuplot setserial i2c-tools python3-smbus -y


## Disable the serial TTY (linux console) on the UART interface
> sudo systemctl disable --now serial-getty@ttyAMA0.service
> 
> sudo systemctl disable --now hciuart


## Disable the kernel support for the serial TTY
> sudo nano /boot/cmdline.txt

Remove this ```console=serial0,115200``` and this (if applicable) ```kgdboc=ttyAMA0,115200``` sequence(s) only and save.


## Configure the Raspberry Pi

Add this to your `/boot/config.txt` file:

```
[pi5]
# To enable hardware serial UART interface over GPIO 14 and 15 (specific for 5B model)
dtparam=uart0_console=on

# Enable uart 0 on GPIOs 14-15. Pi 5 only.
dtoverlay=uart0-pi5

# Disables the undocumented RPi 5B RTC DA9091
dtparam=rtc=off

# Default presets of RPi 5B PWN fan control setpoints
dtparam=fan_temp0=50000
dtparam=fan_temp0_hyst=5000
dtparam=fan_temp0_speed=75

dtparam=fan_temp1=60000
dtparam=fan_temp1_hyst=5000
dtparam=fan_temp1_speed=125

dtparam=fan_temp2=67500
dtparam=fan_temp2_hyst=5000
dtparam=fan_temp2_speed=175

dtparam=fan_temp3=75000
dtparam=fan_temp3_hyst=5000
dtparam=fan_temp3_speed=250

[all]
# Uses the /dev/ttyAMA0 UART GNSS instead of Bluetooth
dtoverlay=miniuart-bt

# Disables Bluetooth for better accuracy and lower interferance - optional
dtoverlay=disable-bt

# Disables Wifi for better accuracy and lower interferance - optional
dtoverlay=disable-wifi

# For GPS Expansion Board from Uputronics
dtparam=i2c_arm=on
dtoverlay=i2c-rtc,rv3028,wakeup-source,backup-switchover-mode=3
dtoverlay=pps-gpio,gpiopin=18
init_uart_baud=115200

# Disables kernel power saving
nohz=off

# Force CPU high speed clock
force_turbo=1
```

## Remove the support to receive NTP servers through DHCP
> sudo rm /etc/dhcp/dhclient-exit-hooks.d/timesyncd
> 
> sudo nano /etc/dhcp/dhclient.conf

Remove the references for `dhcp6.sntp-servers` and `ntp-servers`

## Disable and stop systemd-timesyncd to eliminte conflicts with chrony later on
> sudo systemctl disable --now systemd-timesyncd

## Decrease the serial latency for improved accuracy and stability
> sudo nano /etc/udev/rules.d/gps.rules

Add the content:

```
KERNEL=="ttyAMA0", RUN+="/bin/setserial /dev/ttyAMA0 low_latency"
```

## Force the CPU governor from boot, being always `performance`, aiming better timekeeping resolution
> sudo sed -i `s/CPU_DEFAULT_GOVERNOR="\${CPU_DEFAULT_GOVERNOR:-ondemand}"/CPU_DEFAULT_GOVERNOR="\${CPU_DEFAULT_GOVERNOR:-performance}"/; s/CPU_ONDEMAND_UP_THRESHOLD="\${CPU_ONDEMAND_UP_THRESHOLD:-50}"/CPU_ONDEMAND_UP_THRESHOLD="\${CPU_ONDEMAND_UP_THRESHOLD:-10}"/; s/CPU_ONDEMAND_DOWN_SAMPLING_FACTOR="\${CPU_ONDEMAND_DOWN_SAMPLING_FACTOR:-50}"/CPU_ONDEMAND_DOWN_SAMPLING_FACTOR="\${CPU_ONDEMAND_DOWN_SAMPLING_FACTOR:-10}"/` /etc/init.d/raspi-config


## Disable the fake hardware clock, on Raspberry Pi OS
> sudo systemctl disable --now fake-hwclock
> sudo update-rc.d -f fake-hwclock remove
> sudo apt-get remove fake-hwclock -y
> sudo sed -i `/if \[ -e \/run\/systemd\/system \] ; then/,/\/sbin\/hwclock --rtc=$dev --hctosys/ s/^/#/` /lib/udev/hwclock-set
	

## Reboot to apply the system configurations
> sudo reboot

## For GPS Expansion Board from Uputronics
Confirm the i2c interfaces are working for the RTC (`52` or `UU` at the `0x52` address) and the GPS (`42` or `UU` at the `0x42` address) 
> sudo i2cdetect -y 1

The Output should be similar to:
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- 42 -- -- -- -- -- -- -- -- -- -- -- -- -- 
50: -- -- UU -- -- -- -- -- -- -- -- -- -- -- -- -- 
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
70: -- -- -- -- -- -- -- --                         
```
## Check the rv3028 RTC time
> sudo hwclock -r

If it does return the following error, instead of a date-time stamp:

```hwclock: ioctl(RTC_RD_TIME) to /dev/rtc0 to read the time failed: Invalid argument```

Execute the following command:
> sudo hwclock --systohc -D --noadjfile --utc && sudo hwclock -r

## Setup the GPSd daemon
> sudo nano /etc/default/gpsd

Replace all the content with:

```
START_DAEMON="true"
USBAUTO="false"
DEVICES="/dev/ttyAMA0 /dev/pps0″
GPSD_OPTIONS="--nowait --badtime --passive --speed 115200"
```

## Restart the GPSd service
> sudo systemctl restart gpsd


> [!NOTE]
> **For Uputronics GPS Extension Board:**
> Since V3.00 of the Ublox firmware the time pulse is not released until all time parameters are known including leap seconds. 
> There it could be up to 12.5 minutes before time pulse is available however positional lock is achieved from cold in the expected sub 30 seconds.


## Setup chrony as the service for the NTP server
> sudo nano /etc/chrony/chrony.conf 

Replace all the content with:

```
# Welcome to the chrony configuration file. See chrony.conf(5) for more
# information about usable directives.

# Include configuration files found in /etc/chrony/conf.d.
confdir /etc/chrony/conf.d

# ** CHANGE THIS ** -- DISABLE THIS FOR ISOLATED/AIRGAPED SYSTEMS
pool 0.pool.ntp.org iburst minpoll 5 maxpoll 5 polltarget 16 maxdelay 0.030 maxdelaydevratio 2 maxsources 6
pool 1.pool.ntp.org iburst minpoll 5 maxpoll 5 polltarget 16 maxdelay 0.030 maxdelaydevratio 2 maxsources 6

# ENABLE THIS FOR ISOLATED/AIRGAPED SYSTEMS
#cmdport 0

# Use NTP sources found in /etc/chrony/sources.d.
sourcedir /etc/chrony/sources.d

# This directive specify the location of the file containing ID/key pairs for
# NTP authentication.
keyfile /etc/chrony/chrony.keys

# This directive specify the file into which chronyd will store the rate
# information.
driftfile /var/lib/chrony/chrony.drift

# Save NTS keys and cookies.
ntsdumpdir /var/lib/chrony

# Set the NTS intermediate certificates
#ntsserverkey /etc/pki/tls/private/foo.example.net.key
#ntsservercert /etc/pki/tls/certs/foo.example.net.crt
#ntsratelimit interval 3 burst 1 leak 2


# Uncomment the following line to turn logging on.
#log tracking measurements statistics 
log rawmeasurements measurements statistics tracking refclocks tempcomp

# Log files location.
logdir /var/log/chrony

# The lock_all directive will lock chronyd into RAM so that it will
# never be paged out. This mode is only supported on Linux. This
# directive uses the Linux mlockall() system call to prevent chronyd
# from ever being swapped out. This should result in lower and more
# consistent latency.
lock_all

# Stop bad estimates upsetting machine clock.
maxupdateskew 100.0

# Use it as reference during chrony startup in case the clock needs a large adjustment.
# The 1 indicates that if the system’s error is found to be 1 second or less, a slew will be used to correct it; if the error is above 1 secods, a step will be used.
initstepslew 1 time.facebook.com time.google.com

# enables response rate limiting for NTP packets - reduce the response rate for IP addresses sending packets on average more than once per 2 seconds, or sending packets in bursts of more than 16 packets, by up to 75% (with default leak of 2).
ratelimit interval 1 burst 16 leak 2

# specifies the maximum amount of memory that chronyd is allowed to allocate for logging of client accesses and the state that chronyd as an NTP server needs to support the interleaved mode for its clients. 
# 1GB
clientloglimit 10000000

# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can’t be used along with the `rtcfile` directive.
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than
# one second, but only in the first three clock updates.
makestep 1 3

# Get TAI-UTC offset and leap seconds from the system tz database.
# This directive must be commented out when using time sources serving
# leap-smeared time.
leapsectz right/UTC

# Defining the networks allowed to access the service - DISABLE THIS FOR ISOLATED/AIRGAPED SYSTEMS
allow

# Expedited Forwarding DSCP directive traffic
dscp 48

# enables hardware timestamping for Rpi 5B
hwtimestamp *

# set larger delay to allow the NMEA source to overlap with
# the other sources and avoid the falseticker status
# https://chrony.tuxfamily.org/faq.html#using-pps-refclock
refclock SHM 0 poll 8 refid GPS precision 1e-1 offset 0.090 delay 0.2 noselect

# Choose the one with best long term results
refclock SHM 1 refid PPS precision 1e-7 prefer
refclock kPPS /dev/pps0 lock GPS maxlockage 2 poll 4 refid PPS precision 1e-7 prefer 

# Compares and saves the SoC temperature with the temperature correlation table bellow, every 30 seconds
#tempcomp /sys/class/thermal/thermal_zone0/temp 30 /etc/chrony/chrony.tempcomp
```

## Create a simple and innocuous temperature calibration file for chrony
> sudo nano /etc/chrony/chrony.tempcomp 

Add the content:

```
20000 0
21000 0
25000 0
30000 0
35000 0
40000 0
45000 0
50000 0
55000 0
60000 0
65000 0
```

## Restart the chrony service
> sudo systemctl restart chronyd.service


## Check the sources for correct operation
> watch chronyc sources -v

> [!IMPORTANT]
> Wait for 15 minutes, at least, allowing the system clock to converge into a proper offset range, around sub milisecond.
# Setup the server

## Upgrade your system and install the required software


> sudo apt update && sudo apt upgrade -y
> 
> sudo apt install gpsd gpsd-tools gpsd-clients pps-tools chrony minicom gnuplot setserial i2c-tools python3-smbus -y


## Disable the serial TTY (linux console) on the UART interface
> sudo systemctl disable --now serial-getty@ttyAMA0.service
> 
> sudo systemctl disable --now hciuart


## Disable the kernel support for the serial TTY
> sudo nano /boot/cmdline.txt

Remove this ```console=serial0,115200``` and this (if applicable) ```kgdboc=ttyAMA0,115200``` sequence(s) only and save.


## Configure the Raspberry Pi

Add this to your `/boot/config.txt` file:

```
[pi5]
# To enable hardware serial UART interface over GPIO 14 and 15 (specific for 5B model)
dtparam=uart0_console=on

# Enable uart 0 on GPIOs 14-15. Pi 5 only.
dtoverlay=uart0-pi5

# Disables the undocumented RPi 5B RTC DA9091
dtparam=rtc=off

# Default presets of RPi 5B PWN fan control setpoints
dtparam=fan_temp0=50000
dtparam=fan_temp0_hyst=5000
dtparam=fan_temp0_speed=75

dtparam=fan_temp1=60000
dtparam=fan_temp1_hyst=5000
dtparam=fan_temp1_speed=125

dtparam=fan_temp2=67500
dtparam=fan_temp2_hyst=5000
dtparam=fan_temp2_speed=175

dtparam=fan_temp3=75000
dtparam=fan_temp3_hyst=5000
dtparam=fan_temp3_speed=250

[all]
# Uses the /dev/ttyAMA0 UART GNSS instead of Bluetooth
dtoverlay=miniuart-bt

# Disables Bluetooth for better accuracy and lower interferance - optional
dtoverlay=disable-bt

# Disables Wifi for better accuracy and lower interferance - optional
dtoverlay=disable-wifi

# For GPS Expansion Board from Uputronics
dtparam=i2c_arm=on
dtoverlay=i2c-rtc,rv3028,wakeup-source,backup-switchover-mode=3
dtoverlay=pps-gpio,gpiopin=18
init_uart_baud=115200

# Disables kernel power saving
nohz=off

# Force CPU high speed clock
force_turbo=1
```

## Remove the support to receive NTP servers through DHCP
> sudo rm /etc/dhcp/dhclient-exit-hooks.d/timesyncd
> 
> sudo nano /etc/dhcp/dhclient.conf

Remove the references for `dhcp6.sntp-servers` and `ntp-servers`

## Disable and stop systemd-timesyncd to eliminte conflicts with chrony later on
> sudo systemctl disable --now systemd-timesyncd

## Decrease the serial latency for improved accuracy and stability
> sudo nano /etc/udev/rules.d/gps.rules

Add the content:

```
KERNEL=="ttyAMA0", RUN+="/bin/setserial /dev/ttyAMA0 low_latency"
```

## Force the CPU governor from boot, being always `performance`, aiming better timekeeping resolution
> sudo sed -i `s/CPU_DEFAULT_GOVERNOR="\${CPU_DEFAULT_GOVERNOR:-ondemand}"/CPU_DEFAULT_GOVERNOR="\${CPU_DEFAULT_GOVERNOR:-performance}"/; s/CPU_ONDEMAND_UP_THRESHOLD="\${CPU_ONDEMAND_UP_THRESHOLD:-50}"/CPU_ONDEMAND_UP_THRESHOLD="\${CPU_ONDEMAND_UP_THRESHOLD:-10}"/; s/CPU_ONDEMAND_DOWN_SAMPLING_FACTOR="\${CPU_ONDEMAND_DOWN_SAMPLING_FACTOR:-50}"/CPU_ONDEMAND_DOWN_SAMPLING_FACTOR="\${CPU_ONDEMAND_DOWN_SAMPLING_FACTOR:-10}"/` /etc/init.d/raspi-config


## Disable the fake hardware clock, on Raspberry Pi OS
> sudo systemctl disable --now fake-hwclock
> sudo update-rc.d -f fake-hwclock remove
> sudo apt-get remove fake-hwclock -y
> sudo sed -i `/if \[ -e \/run\/systemd\/system \] ; then/,/\/sbin\/hwclock --rtc=$dev --hctosys/ s/^/#/` /lib/udev/hwclock-set
	

## Reboot to apply the system configurations
> sudo reboot

## For GPS Expansion Board from Uputronics
Confirm the i2c interfaces are working for the RTC (`52` or `UU` at the `0x52` address) and the GPS (`42` or `UU` at the `0x42` address) 
> sudo i2cdetect -y 1

The Output should be similar to:
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- 42 -- -- -- -- -- -- -- -- -- -- -- -- -- 
50: -- -- UU -- -- -- -- -- -- -- -- -- -- -- -- -- 
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
70: -- -- -- -- -- -- -- --                         
```
## Check the rv3028 RTC time
> sudo hwclock -r

If it does return the following error, instead of a date-time stamp:

```hwclock: ioctl(RTC_RD_TIME) to /dev/rtc0 to read the time failed: Invalid argument```

Execute the following command:
> sudo hwclock --systohc -D --noadjfile --utc && sudo hwclock -r

## Setup the GPSd daemon
> sudo nano /etc/default/gpsd

Replace all the content with:

```
START_DAEMON="true"
USBAUTO="false"
DEVICES="/dev/ttyAMA0 /dev/pps0″
GPSD_OPTIONS="--nowait --badtime --passive --speed 115200"
```

## Restart the GPSd service
> sudo systemctl restart gpsd


> [!NOTE]
> **For Uputronics GPS Extension Board:**
> Since V3.00 of the Ublox firmware the time pulse is not released until all time parameters are known including leap seconds. 
> There it could be up to 12.5 minutes before time pulse is available however positional lock is achieved from cold in the expected sub 30 seconds.


## Setup chrony as the service for the NTP server
> sudo nano /etc/chrony/chrony.conf 

Replace all the content with:

```
# Welcome to the chrony configuration file. See chrony.conf(5) for more
# information about usable directives.

# Include configuration files found in /etc/chrony/conf.d.
confdir /etc/chrony/conf.d

# ** CHANGE THIS ** -- DISABLE THIS FOR ISOLATED/AIRGAPED SYSTEMS
pool 0.pool.ntp.org iburst minpoll 5 maxpoll 5 polltarget 16 maxdelay 0.030 maxdelaydevratio 2 maxsources 6
pool 1.pool.ntp.org iburst minpoll 5 maxpoll 5 polltarget 16 maxdelay 0.030 maxdelaydevratio 2 maxsources 6

# ENABLE THIS FOR ISOLATED/AIRGAPED SYSTEMS
#cmdport 0

# Use NTP sources found in /etc/chrony/sources.d.
sourcedir /etc/chrony/sources.d

# This directive specify the location of the file containing ID/key pairs for
# NTP authentication.
keyfile /etc/chrony/chrony.keys

# This directive specify the file into which chronyd will store the rate
# information.
driftfile /var/lib/chrony/chrony.drift

# Save NTS keys and cookies.
ntsdumpdir /var/lib/chrony

# Set the NTS intermediate certificates
#ntsserverkey /etc/pki/tls/private/foo.example.net.key
#ntsservercert /etc/pki/tls/certs/foo.example.net.crt
#ntsratelimit interval 3 burst 1 leak 2


# Uncomment the following line to turn logging on.
#log tracking measurements statistics 
log rawmeasurements measurements statistics tracking refclocks tempcomp

# Log files location.
logdir /var/log/chrony

# The lock_all directive will lock chronyd into RAM so that it will
# never be paged out. This mode is only supported on Linux. This
# directive uses the Linux mlockall() system call to prevent chronyd
# from ever being swapped out. This should result in lower and more
# consistent latency.
lock_all

# Stop bad estimates upsetting machine clock.
maxupdateskew 100.0

# Use it as reference during chrony startup in case the clock needs a large adjustment.
# The 1 indicates that if the system’s error is found to be 1 second or less, a slew will be used to correct it; if the error is above 1 secods, a step will be used.
initstepslew 1 time.facebook.com time.google.com

# enables response rate limiting for NTP packets - reduce the response rate for IP addresses sending packets on average more than once per 2 seconds, or sending packets in bursts of more than 16 packets, by up to 75% (with default leak of 2).
ratelimit interval 1 burst 16 leak 2

# specifies the maximum amount of memory that chronyd is allowed to allocate for logging of client accesses and the state that chronyd as an NTP server needs to support the interleaved mode for its clients. 
# 1GB
clientloglimit 10000000

# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can’t be used along with the `rtcfile` directive.
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than
# one second, but only in the first three clock updates.
makestep 1 3

# Get TAI-UTC offset and leap seconds from the system tz database.
# This directive must be commented out when using time sources serving
# leap-smeared time.
leapsectz right/UTC

# Defining the networks allowed to access the service - DISABLE THIS FOR ISOLATED/AIRGAPED SYSTEMS
allow

# Expedited Forwarding DSCP directive traffic
dscp 48

# enables hardware timestamping for Rpi 5B
hwtimestamp *

# set larger delay to allow the NMEA source to overlap with
# the other sources and avoid the falseticker status
# https://chrony.tuxfamily.org/faq.html#using-pps-refclock
refclock SHM 0 poll 8 refid GPS precision 1e-1 offset 0.090 delay 0.2 noselect

# Choose the one with best long term results
refclock SHM 1 refid PPS precision 1e-7 prefer
refclock kPPS /dev/pps0 lock GPS maxlockage 2 poll 4 refid PPS precision 1e-7 prefer 

# Compares and saves the SoC temperature with the temperature correlation table bellow, every 30 seconds
#tempcomp /sys/class/thermal/thermal_zone0/temp 30 /etc/chrony/chrony.tempcomp
```

## Create a simple and innocuous temperature calibration file for chrony
> sudo nano /etc/chrony/chrony.tempcomp 

Add the content:

```
20000 0
21000 0
25000 0
30000 0
35000 0
40000 0
45000 0
50000 0
55000 0
60000 0
65000 0
```

## Restart the chrony service
> sudo systemctl restart chronyd.service


## Check the sources for correct operation
> watch chronyc sources -v

> [!IMPORTANT]
> Wait for 15 minutes, at least, allowing the system clock to converge into a proper offset range, around sub milisecond.
