#!/bin/sh

# Launch the SuperCollider MIDI thru patch.
# Unloads PulseAudio JACK modules to avoid conflicts, then starts sclang
# with main.scd from the module directory.

if [ -f /usr/local/pisound/scripts/common/common.sh ]; then
    . /usr/local/pisound/scripts/common/common.sh
fi

export XAUTHORITY=/home/patch/.Xauthority
export DISPLAY=:0.0
export XDG_RUNTIME_DIR=/run/user/1000
export JACK_NO_AUDIO_RESERVATION=1
export QT_QPA_PLATFORM="offscreen"
export QT_WEBENGINE_DISABLE_SANDBOX=1

pactl unload-module module-jackdbus-detect 2>/dev/null
pactl unload-module module-jack-sink 2>/dev/null
pactl unload-module module-jack-source 2>/dev/null

MODULE_DIR="$(dirname "$(readlink -f "$0")")"
sclang "$MODULE_DIR/main.scd"
