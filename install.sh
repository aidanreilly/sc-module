#!/bin/sh
# Requires SuperCollider and a working JACK configuration already installed.
echo "Ensure SuperCollider and JACK are configured."
sudo apt-get install -y liboscpack-dev cmake
cd ~ || exit
rm -rf sendosc
git clone https://github.com/yoggy/sendosc.git
cd sendosc || exit
cmake .
make
sudo make install
