#!/bin/bash

BT_MAC="XX:XX:XX:XX:XX:XX"
PHONE_IP="XXX.XXX.XXX.XXX"

# bluetooth device id
# tested with Pluggable BT4 USB adapater with BCM20702 chipset.
BLUETOOTH_DEVICE="hci0"

# Mosquitto info
MOSQUITTO_SERVER='localhost'
MOSQUITTO_TOPIC='presence'

# how long to wait between polling
SLEEP="10s"

# verbose output - shows status of each health check
DEBUG="false"

#overload echo to add timestamps for logging
echo_bin=`which echo`
function echo() {
    $echo_bin `date` $*
}

# Check for mosquitto pub tool
which mosquitto_pub > /dev/null 2>&1
if [ "$?" != "0" ]; then
	# no mosquitto_pub found
	echo "No mosquitto_pub found. Exiting."
	exit 1
fi
which l2ping > /dev/null 2>&1
if [ "$?" != "0" ]; then
	# no l2ping found
	echo "No l2ping found. Exiting."
	exit 1
fi

hciconfig $BLUETOOTH_DEVICE > /dev/null 2>&1
if [ "$?" != "0" ]; then
	echo "No BT device found. Exiting"
	exit 1
fi


# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
	echo "Received ctrl-c. Exiting..."
	exit 0
}

function check_wifi() {
	ping -c2 $PHONE_IP > /dev/null 2>&1
	if [ "$?" != "0" ]; then
		# phone not present
		status='absent'
	else
		status='present'
	fi

	if [ "$DEBUG" == "true" ]; then
		echo "wifi status; $status"
	fi
}

function check_bluetooth() {
	sudo l2ping -t 2 -i $BLUETOOTH_DEVICE -c1 $BT_MAC > /dev/null 2>&1
	if [ "$?" == "0" ]; then
		if [ "$status" == "absent" ]; then
			# if the status is absent, then chage it. Otherwise we don't care.
			status="present"
		fi
	fi

	if [ "$DEBUG" = "true" ]; then
		echo "bt status: $status"
	fi
}
	
echo "debug is $DEBUG"

function main() {
	# assume present when script starts so lights won't get turned on if they were already turned off.
	last_status="present"
	status=""

	while true; do

		check_wifi
		if [ "$status" == "absent" ]; then
			check_bluetooth
		fi

		if [ "$status" != "$last_status" ]; then
			echo "status changed from $last_status to $status"
			# save for later
			last_status=$status

			# update the status
			mosquitto_pub -t $MOSQUITTO_TOPIC -h $MOSQUITTO_SERVER -m "$status"


		fi


		# wait
		sleep $SLEEP
	done
}