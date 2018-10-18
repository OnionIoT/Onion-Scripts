#!/bin/sh

## script to deploy compiled code to an omega

if [ "$1" == "" ]; then
        echo "ERROR: expecting Omega IP address or mdns name"
        exit
fi

rsync -va onion.sh root@"$1":/usr/bin/onion
