#!/bin/sh

# Stop the SuperCollider processes started by launch.sh.

if [ -f /usr/local/pisound/scripts/common/common.sh ]; then
    . /usr/local/pisound/scripts/common/common.sh
fi

killall sclang 2>/dev/null
killall scsynth 2>/dev/null
