#!/bin/bash

. .phone

# bluetooth device id
# tested with Pluggable BT4 USB adapater with BCM20702 chipset.
readonly BLUETOOTH_DEVICE="hci0"

# Mosquitto info
readonly MOSQUITTO_SERVER='localhost'
readonly MOSQUITTO_TOPIC='presence'

# how long to wait between polling
readonly SLEEP="5s"

# verbose output - shows status of each health check
readonly DEBUG="false"

#overload echo to add timestamps for logging
readonly ECHO_BIN=`which echo`
function echo() {
    $ECHO_BIN `date` $*
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
	
function main() {
	echo "debug is $DEBUG"
	# assume present when script starts so lights won't get turned on if they were already turned off.
	last_status="present"
	status=""

	absent_counter=0
	absent_send=2

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
			if [[ "$status" == "present" ]]; then
				mosquitto_pub -t $MOSQUITTO_TOPIC -h $MOSQUITTO_SERVER -m "$status"
			fi
		else 
			if [[ "$status" == "absent" ]]; then
				if [[ "$absent_counter" < "$absent_send" ]]; then
					absent_counter = $($absent_counter + 1)
				else
					echo "Sending absent"
					mosquitto_pub -t $MOSQUITTO_TOPIC -h $MOSQUITTO_SERVER -m "$status"
				fi

			fi
		fi


		# wait
		sleep $SLEEP
	done
}

main

