#!/bin/sh

# Stop the SuperCollider processes started by launch.sh.

. /usr/local/pisound/scripts/common/common.sh

killall sclang
killall scsynth
