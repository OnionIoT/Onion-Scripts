#!/bin/sh /etc/rc.common
# Copyright (C) 2019 Onion Corporation
START=90

USE_PROCD=1

generateMacUid () {
    # grab line 2 of iwpriv output
    line1=$(iwpriv ra0 e2p | sed -n '2p')
    # isolate bytes at addresses 0x0004 and 0x0006, and perform byte swap
    bytes5432=$(echo $line1 |  awk '{print $3":"$4}' | \
      awk -F ":" \
      '{print substr($2,3) substr($2,1,2) substr($4,3) substr($4,1,2)}')

    # grab line 3 of iwpriv output
    line2=$(iwpriv ra0 e2p | sed -n '3p')
    # isolate bytes at address 0x0008 and perform byte swap
    bytes10=$(echo $line2 | awk '{print $1}' | \
      awk -F ":" '{print substr($2,3) substr($2,1,2)}')

    macId=$(echo ${bytes5432}${bytes10})
    echo $macId
}

boot() {
    mac=$(generateMacUid)
    echo "$mac" > /tmp/mac.boot
    if [ "$mac" == "40A36BC00000" ]; then
        # switch to ethernet host mode
        onion -t ethernet host
    fi
}

