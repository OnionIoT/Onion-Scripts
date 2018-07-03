#!/bin/sh

## Onion script for various funcitonality

. /usr/share/libubox/jshn.sh


### global variables
# options
bVerbose=0
bJson=0
bTest=0
bBase64=0
bError=0

#commands
bCmd=0
scriptCommand=""
scriptOption0=""
scriptOption1=""

#############################
##### Print Usage ###########
usage () {
	_Print "Functionality:"
	_Print "	Configure Onion products"
	_Print ""

	_Print "General Usage:"
	_Print "	onion [OPTIONS] <COMMAND> <PARAMETER>"
	_Print ""

	_Print "Configure Ethernet Settings:"
	_Print "	onion [OPTIONS] ethernet client"
	_Print "		Set Ethernet port to be a client on the network"
	_Print ""
	_Print "	onion [OPTIONS] ethernet host"
	_Print "		Set Ethernet port to be the network host"
	_Print ""

	_Print "Configure MJPG Streamer Settings:"
	_Print "	onion [OPTIONS] mjpg-streamer setup"
	_Print "		Configure mjpg-streamer with acceptable default options"
	_Print ""
	_Print "	onion [OPTIONS] mjpg-streamer <SETTING> <VALUE"
	_Print "		Change a specific mjpg-streamer setting"
	_Print "		Supported options:"
	_Print "			resolution <WIDTHxHEIGHT>"
	_Print "			fps <number>"
	_Print ""

	_Print ""
	_Print "Command Line Options:"
	_Print "  -v      Increase output verbosity"
	_Print "  -j      Set all output to JSON"
	#_Print "  -ap     Set any commands above to refer to an AP network"
	#_Print "  -b64    Input arguments are base64 encoded"
	_Print ""
}


#############################
##### General Functions #####
# initialize the json
_Init () {
	if [ $bJson == 1 ]; then
		# json setup
		json_init
	fi
}

# prints a message, taking json output into account
#	$1	- the message to print
#	$2	- the json index string
_Print () {
	if [ $bJson == 0 ]; then
		echo "$1"
	else
		json_add_string "$2" "$1"
	fi
}

# set an error flag
_SetError () {
	bError=1
}

# close and print the json
_Close () {
	if [ $bJson == 1 ]; then
		# print the error status
		local output=$((!$bError))
		json_add_boolean "success" $output

		# print the json
		json_dump
	fi
}

# decode a base64 encoded string
#	$1	- base64 encoded string
#	returns decoded string
_base64Decode () {
	local string="$1"
	string=$(echo "$string" | base64 -d)
	echo "$string"
}

########################################
###     Ethernet Functions
########################################
# set network and dhcp config to act as ethernet hsot
# $1 - bTest - whether this is to be used in testing
setEthernetHost () {
	local bTestConfig=$1
	# change the network config
	if [ $bTestConfig -ne 0 ]; then
		uci -q batch <<-EOF > /dev/null
			set network.lan=interface
			set network.lan.ifname='eth0'
			set network.lan.force_link='1'
			set network.lan.macaddr='40:a3:6b:c0:27:84'
			set network.lan.type='bridge'
			set network.lan.proto='static'
			set network.lan.ipaddr='192.168.100.1'
			set network.lan.netmask='255.255.255.0'
			set network.lan.ip6assign='60'
			commit network
			set dhcp.lan=dhcp
			set dhcp.lan.interface='lan'
			set dhcp.lan.start='100'
			set dhcp.lan.limit='150'
			set dhcp.lan.leasetime='12h'
			set dhcp.lan.dhcpv6='server'
			set dhcp.lan.ra='server'
			commit dhcp
EOF
	fi
	# remove any existing wan network that uses the eth0 interface
	local bExists=$(uci -q get network.wan)
	if [ "$bExists" != "" ]; then
		uci delete network.wan
		uci commit network
	fi


	# restart the network
	/etc/init.d/network restart
}

setEthernetClient() {
	# change the network config
	uci -q batch <<-EOF > /dev/null
		set network.wan=interface
		set network.wan.ifname='eth0'
		set network.wan.proto='dhcp'
		commit network
EOF

	# remove any existing lan network that uses the eth0 interface
	local bExists=$(uci -q get network.lan)
	if [ "$bExists" != "" ]; then
		uci delete network.lan
		uci commit network
	fi

	# remove any lan network DHCP
	local bExists=$(uci -q get dhcp.lan)
	if [ "$bExists" != "" ]; then
		uci delete dhcp.lan
		uci commit dhcp
	fi


	# restart the network
	/etc/init.d/network restart
}

########################################
###     MJPG Streamer Functions
########################################
# set mjpg-streamer default settings
setMjpgStreamerDefault () {
	# change the config
	local fps=$(uci -q get mjpg-streamer.core.fps)
	if [ "$fps" == "5" ]; then
		uci set mjpg-streamer.core.fps='15'
	fi

	uci -q batch <<-EOF > /dev/null
		delete mjpg-streamer.core.username
		delete mjpg-streamer.core.password
		set mjpg-streamer.core.enabled='1'
		commit mjpg-streamer
EOF

	# restart the service
	/etc/init.d/mjpg-streamer restart
}

# set a specified option for mjpg-streamer
#	$1	- the option
#	$2 	- the option value
setMjpgStreamerOption () {
	# change the config
	uci set mjpg-streamer.core.$1="$2"
	uci commit mjpg-streamer

	# restart the service
	/etc/init.d/mjpg-streamer restart
}



########################################
###     Parse Arguments
########################################


# parse arguments
while [ "$1" != "" ]
do
	case "$1" in
		# options
		-v|--v|-verbose|verbose)
			bVerbose=1
			shift
		;;
		-j|--j|-json|--json|json)
			bJson=1
			shift
		;;
		-t|--t|-test|--test|test|-testing|--testing|testing)
			bTest=1
			shift
		;;
		-ap|--ap|accesspoint|-accesspoint|--accesspoint)
			bApNetwork=1
			shift
		;;
		-b64|--b64|-base64|--base64|base64)
			bBase64=1
			shift
		;;
		# commands
		ethernet)
			bCmd=1
			scriptCommand="ethernet"
			shift
			scriptOption0="$1"
			shift
		;;
		mjpg-streamer)
			bCmd=1
			scriptCommand="mjpg-streamer"
			shift
			scriptOption0="$1"
			shift
			scriptOption1="$1"
			shift
		;;
		*)
			echo "ERROR: Invalid Argument: $1"
			usage
			exit
		;;
	esac
done



########################################
########################################
###     Main Program
########################################

## json init
_Init


## commands
if [ $bCmd == 1 ]; then
	# ethernet commands
	if [ "$scriptCommand" == "ethernet" ]; then
		if [ "$scriptOption0" == "host" ]; then
			setEthernetHost $bTest
		elif [ "$scriptOption0" == "client" ]; then
			setEthernetClient
		fi
	elif [ "$scriptCommand" == "mjpg-streamer" ]; then
		if [ "$scriptOption0" == "setup" ]; then
			setMjpgStreamerDefault
		elif 	[ "$scriptOption0" == "resolution" ] ||
					[ "$scriptOption0" == "fps" ];
		then
			setMjpgStreamerOption "$scriptOption0" "$scriptOption1"
		fi
	fi

else
	usage
fi



## json finish
_Close
