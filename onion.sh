#!/bin/sh

## Onion script for various funcitonality

# . /usr/share/libubox/jshn.sh


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
scriptOption2=""

#############################
##### Print Usage ###########
ethernetUsage () {
	_Print "Configure Ethernet Settings:"
	_Print "	onion [OPTIONS] ethernet client"
	_Print "		Set Ethernet port to be a client on the network"
	_Print ""
	_Print "	onion [OPTIONS] ethernet host"
	_Print "		Set Ethernet port to be the network host"
	_Print ""
}

mjpgStreamerUsage () {
	_Print "Configure MJPG Streamer Settings:"
	_Print "	onion [OPTIONS] mjpg-streamer setup"
	_Print "		Configure mjpg-streamer with acceptable default options"
	_Print ""
	_Print "	onion [OPTIONS] mjpg-streamer <SETTING> <VALUE>"
	_Print "		Change a specific mjpg-streamer setting"
	_Print "		Supported options:"
	_Print "			resolution <WIDTHxHEIGHT>"
	_Print "			fps <number>"
	_Print ""
}

timeUsage () {
	_Print "Configure Device Time:"
	_Print "	onion [OPTIONS] time list"
	_Print "		List all available timezones and associated timezone string"
	_Print ""
	_Print "	onion [OPTIONS] time set <TIMEZONE> <TIMEZONE STRING>"
	_Print "		Change the system timezone"
	_Print ""
	_Print "	onion [OPTIONS] time sync"
	_Print "		Update system time from the internet"
	_Print ""
}

pwmUsage () {
	_Print "Configure PWM Channel:"
	_Print "	onion [OPTIONS] pwm <CHANNEL> <DUTY CYCLE> <FREQUENCY>"
	_Print "		Set PWM Channel to PWM signal with specified duty cycle and frequency"
	_Print "			CHANNEL     - can be 0 (GPIO18) or 1 (GPIO19)"
	_Print "			DUTY CYCLE  - percentage, expressed 0 - 100"
	_Print "			FREQUENCY   - signal frequency, expressed in Hz"
	_Print ""
	_Print "	onion [OPTIONS] pwm <CHANNEL> disable"
	_Print "		Disable the specified PWM Channel"
	_Print ""
}

osUsage () {
	_Print "Configure OnionOS:"
	_Print "	onion [OPTIONS] os version"
	_Print "		Display Omega and OnionOS version information"
	_Print ""
	_Print "	onion [OPTIONS] os update"
	_Print "		Update OnionOS to the latest available version"
	_Print ""
}

usage () {
	_Print "Functionality:"
	_Print "	Configure Onion products"
	_Print ""

	_Print "General Usage:"
	_Print "	onion [OPTIONS] <COMMAND> <PARAMETER>"
	_Print ""

	ethernetUsage

	mjpgStreamerUsage

	timeUsage

	pwmUsage

	osUsage

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
###     Timezone Functions
########################################
# output the list of available timezones
listTimezones () {
	_Print "Location	TZ string"
	_Print "Africa/Abidjan	GMT0"
	_Print "Africa/Accra	GMT0"
	_Print "Africa/Addis Ababa	EAT-3"
	_Print "Africa/Algiers	CET-1"
	_Print "Africa/Asmara	EAT-3"
	_Print "Africa/Bamako	GMT0"
	_Print "Africa/Bangui	WAT-1"
	_Print "Africa/Banjul	GMT0"
	_Print "Africa/Bissau	GMT0"
	_Print "Africa/Blantyre	CAT-2"
	_Print "Africa/Brazzaville	WAT-1"
	_Print "Africa/Bujumbura	CAT-2"
	_Print "Africa/Casablanca	WET0"
	_Print "Africa/Ceuta	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Africa/Conakry	GMT0"
	_Print "Africa/Dakar	GMT0"
	_Print "Africa/Dar es Salaam	EAT-3"
	_Print "Africa/Djibouti	EAT-3"
	_Print "Africa/Douala	WAT-1"
	_Print "Africa/El Aaiun	WET0"
	_Print "Africa/Freetown	GMT0"
	_Print "Africa/Gaborone	CAT-2"
	_Print "Africa/Harare	CAT-2"
	_Print "Africa/Johannesburg	SAST-2"
	_Print "Africa/Kampala	EAT-3"
	_Print "Africa/Khartoum	EAT-3"
	_Print "Africa/Kigali	CAT-2"
	_Print "Africa/Kinshasa	WAT-1"
	_Print "Africa/Lagos	WAT-1"
	_Print "Africa/Libreville	WAT-1"
	_Print "Africa/Lome	GMT0"
	_Print "Africa/Luanda	WAT-1"
	_Print "Africa/Lubumbashi	CAT-2"
	_Print "Africa/Lusaka	CAT-2"
	_Print "Africa/Malabo	WAT-1"
	_Print "Africa/Maputo	CAT-2"
	_Print "Africa/Maseru	SAST-2"
	_Print "Africa/Mbabane	SAST-2"
	_Print "Africa/Mogadishu	EAT-3"
	_Print "Africa/Monrovia	GMT0"
	_Print "Africa/Nairobi	EAT-3"
	_Print "Africa/Ndjamena	WAT-1"
	_Print "Africa/Niamey	WAT-1"
	_Print "Africa/Nouakchott	GMT0"
	_Print "Africa/Ouagadougou	GMT0"
	_Print "Africa/Porto-Novo	WAT-1"
	_Print "Africa/Sao Tome	GMT0"
	_Print "Africa/Tripoli	EET-2"
	_Print "Africa/Tunis	CET-1"
	_Print "Africa/Windhoek	WAT-1WAST,M9.1.0,M4.1.0"
	_Print "America/Adak	HAST10HADT,M3.2.0,M11.1.0"
	_Print "America/Anchorage	AKST9AKDT,M3.2.0,M11.1.0"
	_Print "America/Anguilla	AST4"
	_Print "America/Antigua	AST4"
	_Print "America/Araguaina	BRT3"
	_Print "America/Argentina/Buenos Aires	ART3"
	_Print "America/Argentina/Catamarca	ART3"
	_Print "America/Argentina/Cordoba	ART3"
	_Print "America/Argentina/Jujuy	ART3"
	_Print "America/Argentina/La Rioja	ART3"
	_Print "America/Argentina/Mendoza	ART3"
	_Print "America/Argentina/Rio Gallegos	ART3"
	_Print "America/Argentina/Salta	ART3"
	_Print "America/Argentina/San Juan	ART3"
	_Print "America/Argentina/Tucuman	ART3"
	_Print "America/Argentina/Ushuaia	ART3"
	_Print "America/Aruba	AST4"
	_Print "America/Asuncion	PYT4PYST,M10.1.0/0,M4.2.0/0"
	_Print "America/Atikokan	EST5"
	_Print "America/Bahia	BRT3"
	_Print "America/Barbados	AST4"
	_Print "America/Belem	BRT3"
	_Print "America/Belize	CST6"
	_Print "America/Blanc-Sablon	AST4"
	_Print "America/Boa Vista	AMT4"
	_Print "America/Bogota	COT5"
	_Print "America/Boise	MST7MDT,M3.2.0,M11.1.0"
	_Print "America/Cambridge Bay	MST7MDT,M3.2.0,M11.1.0"
	_Print "America/Campo Grande	AMT4AMST,M10.3.0/0,M2.3.0/0"
	_Print "America/Cancun	CST6CDT,M4.1.0,M10.5.0"
	_Print "America/Caracas	VET4:30"
	_Print "America/Cayenne	GFT3"
	_Print "America/Cayman	EST5"
	_Print "America/Chicago	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Chihuahua	MST7MDT,M4.1.0,M10.5.0"
	_Print "America/Costa Rica	CST6"
	_Print "America/Cuiaba	AMT4AMST,M10.3.0/0,M2.3.0/0"
	_Print "America/Curacao	AST4"
	_Print "America/Danmarkshavn	GMT0"
	_Print "America/Dawson	PST8PDT,M3.2.0,M11.1.0"
	_Print "America/Dawson Creek	MST7"
	_Print "America/Denver	MST7MDT,M3.2.0,M11.1.0"
	_Print "America/Detroit	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Dominica	AST4"
	_Print "America/Edmonton	MST7MDT,M3.2.0,M11.1.0"
	_Print "America/Eirunepe	AMT4"
	_Print "America/El Salvador	CST6"
	_Print "America/Fortaleza	BRT3"
	_Print "America/Glace Bay	AST4ADT,M3.2.0,M11.1.0"
	_Print "America/Goose Bay	AST4ADT,M3.2.0/0:01,M11.1.0/0:01"
	_Print "America/Grand Turk	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Grenada	AST4"
	_Print "America/Guadeloupe	AST4"
	_Print "America/Guatemala	CST6"
	_Print "America/Guayaquil	ECT5"
	_Print "America/Guyana	GYT4"
	_Print "America/Halifax	AST4ADT,M3.2.0,M11.1.0"
	_Print "America/Havana	CST5CDT,M3.2.0/0,M10.5.0/1"
	_Print "America/Hermosillo	MST7"
	_Print "America/Indiana/Indianapolis	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Indiana/Knox	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Indiana/Marengo	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Indiana/Petersburg	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Indiana/Tell City	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Indiana/Vevay	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Indiana/Vincennes	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Indiana/Winamac	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Inuvik	MST7MDT,M3.2.0,M11.1.0"
	_Print "America/Iqaluit	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Jamaica	EST5"
	_Print "America/Juneau	AKST9AKDT,M3.2.0,M11.1.0"
	_Print "America/Kentucky/Louisville	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Kentucky/Monticello	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/La Paz	BOT4"
	_Print "America/Lima	PET5"
	_Print "America/Los Angeles	PST8PDT,M3.2.0,M11.1.0"
	_Print "America/Maceio	BRT3"
	_Print "America/Managua	CST6"
	_Print "America/Manaus	AMT4"
	_Print "America/Marigot	AST4"
	_Print "America/Martinique	AST4"
	_Print "America/Matamoros	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Mazatlan	MST7MDT,M4.1.0,M10.5.0"
	_Print "America/Menominee	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Merida	CST6CDT,M4.1.0,M10.5.0"
	_Print "America/Mexico City	CST6CDT,M4.1.0,M10.5.0"
	_Print "America/Miquelon	PMST3PMDT,M3.2.0,M11.1.0"
	_Print "America/Moncton	AST4ADT,M3.2.0,M11.1.0"
	_Print "America/Monterrey	CST6CDT,M4.1.0,M10.5.0"
	_Print "America/Montevideo	UYT3UYST,M10.1.0,M3.2.0"
	_Print "America/Montreal	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Montserrat	AST4"
	_Print "America/Nassau	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/New York	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Nipigon	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Nome	AKST9AKDT,M3.2.0,M11.1.0"
	_Print "America/Noronha	FNT2"
	_Print "America/North Dakota/Center	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/North Dakota/New Salem	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Ojinaga	MST7MDT,M3.2.0,M11.1.0"
	_Print "America/Panama	EST5"
	_Print "America/Pangnirtung	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Paramaribo	SRT3"
	_Print "America/Phoenix	MST7"
	_Print "America/Port of Spain	AST4"
	_Print "America/Port-au-Prince	EST5"
	_Print "America/Porto Velho	AMT4"
	_Print "America/Puerto Rico	AST4"
	_Print "America/Rainy River	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Rankin Inlet	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Recife	BRT3"
	_Print "America/Regina	CST6"
	_Print "America/Rio Branco	AMT4"
	_Print "America/Santa Isabel	PST8PDT,M4.1.0,M10.5.0"
	_Print "America/Santarem	BRT3"
	_Print "America/Santo Domingo	AST4"
	_Print "America/Sao Paulo	BRT3BRST,M10.3.0/0,M2.3.0/0"
	_Print "America/Scoresbysund	EGT1EGST,M3.5.0/0,M10.5.0/1"
	_Print "America/Shiprock	MST7MDT,M3.2.0,M11.1.0"
	_Print "America/St Barthelemy	AST4"
	_Print "America/St Johns	NST3:30NDT,M3.2.0/0:01,M11.1.0/0:01"
	_Print "America/St Kitts	AST4"
	_Print "America/St Lucia	AST4"
	_Print "America/St Thomas	AST4"
	_Print "America/St Vincent	AST4"
	_Print "America/Swift Current	CST6"
	_Print "America/Tegucigalpa	CST6"
	_Print "America/Thule	AST4ADT,M3.2.0,M11.1.0"
	_Print "America/Thunder Bay	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Tijuana	PST8PDT,M3.2.0,M11.1.0"
	_Print "America/Toronto	EST5EDT,M3.2.0,M11.1.0"
	_Print "America/Tortola	AST4"
	_Print "America/Vancouver	PST8PDT,M3.2.0,M11.1.0"
	_Print "America/Whitehorse	PST8PDT,M3.2.0,M11.1.0"
	_Print "America/Winnipeg	CST6CDT,M3.2.0,M11.1.0"
	_Print "America/Yakutat	AKST9AKDT,M3.2.0,M11.1.0"
	_Print "America/Yellowknife	MST7MDT,M3.2.0,M11.1.0"
	_Print "Antarctica/Casey	WST-8"
	_Print "Antarctica/Davis	DAVT-7"
	_Print "Antarctica/DumontDUrville	DDUT-10"
	_Print "Antarctica/Macquarie	MIST-11"
	_Print "Antarctica/Mawson	MAWT-5"
	_Print "Antarctica/McMurdo	NZST-12NZDT,M9.5.0,M4.1.0/3"
	_Print "Antarctica/Rothera	ROTT3"
	_Print "Antarctica/South Pole	NZST-12NZDT,M9.5.0,M4.1.0/3"
	_Print "Antarctica/Syowa	SYOT-3"
	_Print "Antarctica/Vostok	VOST-6"
	_Print "Arctic/Longyearbyen	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Asia/Aden	AST-3"
	_Print "Asia/Almaty	ALMT-6"
	_Print "Asia/Anadyr	ANAT-11ANAST,M3.5.0,M10.5.0/3"
	_Print "Asia/Aqtau	AQTT-5"
	_Print "Asia/Aqtobe	AQTT-5"
	_Print "Asia/Ashgabat	TMT-5"
	_Print "Asia/Baghdad	AST-3"
	_Print "Asia/Bahrain	AST-3"
	_Print "Asia/Baku	AZT-4AZST,M3.5.0/4,M10.5.0/5"
	_Print "Asia/Bangkok	ICT-7"
	_Print "Asia/Beirut	EET-2EEST,M3.5.0/0,M10.5.0/0"
	_Print "Asia/Bishkek	KGT-6"
	_Print "Asia/Brunei	BNT-8"
	_Print "Asia/Choibalsan	CHOT-8"
	_Print "Asia/Chongqing	CST-8"
	_Print "Asia/Colombo	IST-5:30"
	_Print "Asia/Damascus	EET-2EEST,M4.1.5/0,M10.5.5/0"
	_Print "Asia/Dhaka	BDT-6"
	_Print "Asia/Dili	TLT-9"
	_Print "Asia/Dubai	GST-4"
	_Print "Asia/Dushanbe	TJT-5"
	_Print "Asia/Gaza	EET-2EEST,M3.5.6/0:01,M9.1.5"
	_Print "Asia/Harbin	CST-8"
	_Print "Asia/Ho Chi Minh	ICT-7"
	_Print "Asia/Hong Kong	HKT-8"
	_Print "Asia/Hovd	HOVT-7"
	_Print "Asia/Irkutsk	IRKT-8IRKST,M3.5.0,M10.5.0/3"
	_Print "Asia/Jakarta	WIT-7"
	_Print "Asia/Jayapura	EIT-9"
	_Print "Asia/Kabul	AFT-4:30"
	_Print "Asia/Kamchatka	PETT-11PETST,M3.5.0,M10.5.0/3"
	_Print "Asia/Karachi	PKT-5"
	_Print "Asia/Kashgar	CST-8"
	_Print "Asia/Kathmandu	NPT-5:45"
	_Print "Asia/Kolkata	IST-5:30"
	_Print "Asia/Krasnoyarsk	KRAT-7KRAST,M3.5.0,M10.5.0/3"
	_Print "Asia/Kuala Lumpur	MYT-8"
	_Print "Asia/Kuching	MYT-8"
	_Print "Asia/Kuwait	AST-3"
	_Print "Asia/Macau	CST-8"
	_Print "Asia/Magadan	MAGT-11MAGST,M3.5.0,M10.5.0/3"
	_Print "Asia/Makassar	CIT-8"
	_Print "Asia/Manila	PHT-8"
	_Print "Asia/Muscat	GST-4"
	_Print "Asia/Nicosia	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Asia/Novokuznetsk	NOVT-6NOVST,M3.5.0,M10.5.0/3"
	_Print "Asia/Novosibirsk	NOVT-6NOVST,M3.5.0,M10.5.0/3"
	_Print "Asia/Omsk	OMST-7"
	_Print "Asia/Oral	ORAT-5"
	_Print "Asia/Phnom Penh	ICT-7"
	_Print "Asia/Pontianak	WIT-7"
	_Print "Asia/Pyongyang	KST-9"
	_Print "Asia/Qatar	AST-3"
	_Print "Asia/Qyzylorda	QYZT-6"
	_Print "Asia/Rangoon	MMT-6:30"
	_Print "Asia/Riyadh	AST-3"
	_Print "Asia/Sakhalin	SAKT-10SAKST,M3.5.0,M10.5.0/3"
	_Print "Asia/Samarkand	UZT-5"
	_Print "Asia/Seoul	KST-9"
	_Print "Asia/Shanghai	CST-8"
	_Print "Asia/Singapore	SGT-8"
	_Print "Asia/Taipei	CST-8"
	_Print "Asia/Tashkent	UZT-5"
	_Print "Asia/Tbilisi	GET-4"
	_Print "Asia/Tehran	IRST-3:30IRDT,80/0,264/0"
	_Print "Asia/Thimphu	BTT-6"
	_Print "Asia/Tokyo	JST-9"
	_Print "Asia/Ulaanbaatar	ULAT-8"
	_Print "Asia/Urumqi	CST-8"
	_Print "Asia/Vientiane	ICT-7"
	_Print "Asia/Vladivostok	VLAT-10VLAST,M3.5.0,M10.5.0/3"
	_Print "Asia/Yakutsk	YAKT-9YAKST,M3.5.0,M10.5.0/3"
	_Print "Asia/Yekaterinburg	YEKT-5YEKST,M3.5.0,M10.5.0/3"
	_Print "Asia/Yerevan	AMT-4AMST,M3.5.0,M10.5.0/3"
	_Print "Atlantic/Azores	AZOT1AZOST,M3.5.0/0,M10.5.0/1"
	_Print "Atlantic/Bermuda	AST4ADT,M3.2.0,M11.1.0"
	_Print "Atlantic/Canary	WET0WEST,M3.5.0/1,M10.5.0"
	_Print "Atlantic/Cape Verde	CVT1"
	_Print "Atlantic/Faroe	WET0WEST,M3.5.0/1,M10.5.0"
	_Print "Atlantic/Madeira	WET0WEST,M3.5.0/1,M10.5.0"
	_Print "Atlantic/Reykjavik	GMT0"
	_Print "Atlantic/South Georgia	GST2"
	_Print "Atlantic/St Helena	GMT0"
	_Print "Atlantic/Stanley	FKT4FKST,M9.1.0,M4.3.0"
	_Print "Australia/Adelaide	CST-9:30CST,M10.1.0,M4.1.0/3"
	_Print "Australia/Brisbane	EST-10"
	_Print "Australia/Broken Hill	CST-9:30CST,M10.1.0,M4.1.0/3"
	_Print "Australia/Currie	EST-10EST,M10.1.0,M4.1.0/3"
	_Print "Australia/Darwin	CST-9:30"
	_Print "Australia/Eucla	CWST-8:45"
	_Print "Australia/Hobart	EST-10EST,M10.1.0,M4.1.0/3"
	_Print "Australia/Lindeman	EST-10"
	_Print "Australia/Lord Howe	LHST-10:30LHST-11,M10.1.0,M4.1.0"
	_Print "Australia/Melbourne	EST-10EST,M10.1.0,M4.1.0/3"
	_Print "Australia/Perth	WST-8"
	_Print "Australia/Sydney	EST-10EST,M10.1.0,M4.1.0/3"
	_Print "Europe/Amsterdam	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Andorra	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Athens	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Belgrade	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Berlin	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Bratislava	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Brussels	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Bucharest	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Budapest	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Chisinau	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Copenhagen	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Dublin	GMT0IST,M3.5.0/1,M10.5.0"
	_Print "Europe/Gibraltar	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Guernsey	GMT0BST,M3.5.0/1,M10.5.0"
	_Print "Europe/Helsinki	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Isle of Man	GMT0BST,M3.5.0/1,M10.5.0"
	_Print "Europe/Istanbul	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Jersey	GMT0BST,M3.5.0/1,M10.5.0"
	_Print "Europe/Kaliningrad	EET-2EEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Kiev	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Lisbon	WET0WEST,M3.5.0/1,M10.5.0"
	_Print "Europe/Ljubljana	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/London	GMT0BST,M3.5.0/1,M10.5.0"
	_Print "Europe/Luxembourg	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Madrid	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Malta	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Mariehamn	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Minsk	EET-2EEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Monaco	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Moscow	MSK-3"
	_Print "Europe/Oslo	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Paris	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Podgorica	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Prague	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Riga	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Rome	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Samara	SAMT-3SAMST,M3.5.0,M10.5.0/3"
	_Print "Europe/San Marino	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Sarajevo	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Simferopol	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Skopje	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Sofia	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Stockholm	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Tallinn	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Tirane	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Uzhgorod	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Vaduz	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Vatican	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Vienna	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Vilnius	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Volgograd	VOLT-3VOLST,M3.5.0,M10.5.0/3"
	_Print "Europe/Warsaw	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Zagreb	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Europe/Zaporozhye	EET-2EEST,M3.5.0/3,M10.5.0/4"
	_Print "Europe/Zurich	CET-1CEST,M3.5.0,M10.5.0/3"
	_Print "Indian/Antananarivo	EAT-3"
	_Print "Indian/Chagos	IOT-6"
	_Print "Indian/Christmas	CXT-7"
	_Print "Indian/Cocos	CCT-6:30"
	_Print "Indian/Comoro	EAT-3"
	_Print "Indian/Kerguelen	TFT-5"
	_Print "Indian/Mahe	SCT-4"
	_Print "Indian/Maldives	MVT-5"
	_Print "Indian/Mauritius	MUT-4"
	_Print "Indian/Mayotte	EAT-3"
	_Print "Indian/Reunion	RET-4"
	_Print "Pacific/Apia	WST11"
	_Print "Pacific/Auckland	NZST-12NZDT,M9.5.0,M4.1.0/3"
	_Print "Pacific/Chatham	CHAST-12:45CHADT,M9.5.0/2:45,M4.1.0/3:45"
	_Print "Pacific/Efate	VUT-11"
	_Print "Pacific/Enderbury	PHOT-13"
	_Print "Pacific/Fakaofo	TKT10"
	_Print "Pacific/Fiji	FJT-12"
	_Print "Pacific/Funafuti	TVT-12"
	_Print "Pacific/Galapagos	GALT6"
	_Print "Pacific/Gambier	GAMT9"
	_Print "Pacific/Guadalcanal	SBT-11"
	_Print "Pacific/Guam	ChST-10"
	_Print "Pacific/Honolulu	HST10"
	_Print "Pacific/Johnston	HST10"
	_Print "Pacific/Kiritimati	LINT-14"
	_Print "Pacific/Kosrae	KOST-11"
	_Print "Pacific/Kwajalein	MHT-12"
	_Print "Pacific/Majuro	MHT-12"
	_Print "Pacific/Marquesas	MART9:30"
	_Print "Pacific/Midway	SST11"
	_Print "Pacific/Nauru	NRT-12"
	_Print "Pacific/Niue	NUT11"
	_Print "Pacific/Norfolk	NFT-11:30"
	_Print "Pacific/Noumea	NCT-11"
	_Print "Pacific/Pago Pago	SST11"
	_Print "Pacific/Palau	PWT-9"
	_Print "Pacific/Pitcairn	PST8"
	_Print "Pacific/Ponape	PONT-11"
	_Print "Pacific/Port Moresby	PGT-10"
	_Print "Pacific/Rarotonga	CKT10"
	_Print "Pacific/Saipan	ChST-10"
	_Print "Pacific/Tahiti	TAHT10"
	_Print "Pacific/Tarawa	GILT-12"
	_Print "Pacific/Tongatapu	TOT-13"
	_Print "Pacific/Truk	TRUT-10"
	_Print "Pacific/Wake	WAKT-12"
	_Print "Pacific/Wallis	WFT-12"
}

# set system timezone
#	$1 	- the timezone name
#	$2	- the timezone string
setTimezone () {
	local timezone="$1"
	local tz="$2"

	uci set system.@system[0].timezone="$tz"
	uci set system.@system[0].zonename="$timezone"
	uci commit system

	echo "$tz" > /etc/TZ
	echo "$tz" > /tmp/TZ
}

# sync time with online NTP servers
syncTime () {
	/etc/init.d/sysntpd restart
}

########################################
###     PWM Functions
########################################
# check if pwm module is installed
isPwmAvailable () {
	if [ -d "/sys/class/pwm/pwmchip0" ]; then
		echo "1"
	else
		echo "0"
	fi
}

# check if channel is valid
# $1 - channel
isPwmChannelValid () {
	case "$1" in
		0|1|2|3)
			echo "1"
		;;
		*)
			echo "0"
		;;
	esac
}

# set a PWM channel to a duty cycle and frequency
#	$1	- channel
#	$2	- duty cycle
#	$3	- frequency
setPwmChannel () {
	local period=$(echo "1/$3 * 1000000000" | bc -l)
	local pulseWidth=$(echo "$period * $2 / 100" | bc -l)
	period=$(echo "scale=0; $period/1" | bc -l)
	pulseWidth=$(echo "scale=0; $pulseWidth/1" | bc -l)
	# echo "period = $period"
	# echo "pulseWidth = $pulseWidth"

	# set the PWM
	echo "$1" > /sys/class/pwm/pwmchip0/export

	echo "$period" > /sys/class/pwm/pwmchip0/pwm$1/period
	echo "$pulseWidth" > /sys/class/pwm/pwmchip0/pwm$1/duty_cycle

	echo "1" > /sys/class/pwm/pwmchip0/pwm$1/enable

	echo "$1" > /sys/class/pwm/pwmchip0/unexport
}

disablePwmChannel () {
	# disable the PWM chanel
	echo "$1" > /sys/class/pwm/pwmchip0/export
	echo "0" > /sys/class/pwm/pwmchip0/pwm$1/enable
	echo "$1" > /sys/class/pwm/pwmchip0/unexport
}

########################################
###     OnionOS Functions
########################################
onionOsUpdate () {
	_Print "Updating OnionOS"
	# update OnionOS
	opkg update > /dev/null
	opkg upgrade onion-os > /dev/null
	# remove any out-dated packages
	for pkg in "oos-app-camera" "oos-app-editor" "oos-app-nfc-exp" "oos-app-nfc-exp" "oos-app-sensor-monitor" "oos-app-power-dock-2"
	do
		opkg remove $pkg > /dev/null
	done
	# remove any out-dated files
	for dir in "editor" "nfc-rfid-exp" "oos-app-camera"
	do
		if [ -d "/www/apps/$dir" ]; then
			rm -rf /www/apps/$dir
		fi
	done
	# update any outdated apps
	for pkg in "oos-app-sensor-monitor" "oos-app-power-dock-2"
	do
		local exists=$(opkg list-installed | grep $pkg)
		if [ "$exists" != "" ]; then
			opkg upgrade $pkg > /dev/null
		fi
	done
	_Print "Done"
}

onionOSVersion () {
	local fwVer=$(uci -q get onion.@onion[0].version)
	local fwBuild=$(uci -q get onion.@onion[0].build)
	local fw="v$fwVer b$fwBuild"
	local osVer=$(opkg list-installed | grep onion-os)
	local appsVers=$(opkg list-installed | grep oos-)
	_Print "=== Version Info ==="
	_Print "Omega firmware: $fw"
	_Print "$osVer"
	if [ "$appsVers" != "" ]; then
		_Print " = OnionOS Apps ="
		_Print "$appsVers"
	fi
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
		time)
			bCmd=1
			scriptCommand="time"
			shift
			scriptOption0="$1"
			shift
			scriptOption1="$1"
			shift
			scriptOption2="$1"
			shift
		;;
		pwm)
			bCmd=1
			scriptCommand="pwm"
			shift
			scriptOption0="$1"
			shift
			scriptOption1="$1"
			shift
			scriptOption2="$1"
			shift
		;;
		os)
			bCmd=1
			scriptCommand="os"
			shift
			scriptOption0="$1"
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
	elif [ "$scriptCommand" == "time" ]; then
		if [ "$scriptOption0" == "list" ]; then
			listTimezones
		elif [ "$scriptOption0" == "sync" ]; then
			syncTime
		elif 	[ "$scriptOption0" == "set" ]; then
			if 	[ "$scriptOption1" == "" ] ||
					[ "$scriptOption2" == "" ];
			then
				timeUsage
				_Print ""
				_Print "ERROR: expecting timezone AND timezone string"
			else
				setTimezone "$scriptOption1" "$scriptOption2"
			fi
		fi
	elif [ "$scriptCommand" == "pwm" ]; then
		# check if pwm kernel module is installed
		pwmValid=$(isPwmAvailable)
		if [ "$pwmValid" != "1" ]; then
			echo "ERROR: PWM functionality not available"
			echo "  ensure your Omega is on the latest firmware and run:"
			echo "    opkg update"
			echo "    opkg install kmod-pwm-mediatek"
			exit 1
		fi
		# check if channel is valid
		validChannel=$(isPwmChannelValid "$scriptOption0")
		if [ "$validChannel" != "1" ]; then
			echo "ERROR: expecting channel value 0 to 1"
			pwmUsage
			exit 1
		fi
		if [ "$scriptOption1" == "disable" ]; then
			disablePwmChannel "$scriptOption0"
		else
			setPwmChannel "$scriptOption0" "$scriptOption1" "$scriptOption2"
		fi
	elif [ "$scriptCommand" == "os" ]; then
		if [ "$scriptOption0" == "update" ]; then
			onionOsUpdate
		elif [ "$scriptOption0" == "version" ]; then
			onionOSVersion
		fi
	fi

else
	usage
fi



## json finish
_Close
