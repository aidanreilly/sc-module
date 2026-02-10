#!/bin/sh
python3 -c "
import socket, struct
def osc_string(s):
    b = s.encode('ascii') + b'\x00'
    b += b'\x00' * ((-len(b)) % 4)
    return b
msg = osc_string('/nextPreset') + osc_string(',i') + struct.pack('>i', 1)
socket.socket(socket.AF_INET, socket.SOCK_DGRAM).sendto(msg, ('127.0.0.1', 57120))
"
