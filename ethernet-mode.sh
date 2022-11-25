#!/bin/sh /etc/rc.common
# Copyright (C) 2019 Onion Corporation
START=51

USE_PROCD=1
KEY1="40a36bc00000"
KEY2="881e59000000"

generateMacUid () {
    macId=$(hexdump -s 4 -n 6 /dev/mtd2 | sed -n '1p' | awk '{print substr($2,3) substr($2,1,2) substr($3,3) substr($3,1,2) substr($4,3) substr($4,1,2)}')
    echo $macId
}

boot() {
    mac=$(generateMacUid)
    echo "$mac" > /tmp/mac.boot
    if [ "$mac" == "$KEY1" ] || [ "$mac" == "$KEY2" ]; then
        # enable telnet server daemon
        telnetd
    else
        # check if client mode, if not, switch to client mode
        mode=$(onion ethernet check)
        if [ "$mode" != "client" ]; then
            onion ethernet client
        fi
    fi
}
