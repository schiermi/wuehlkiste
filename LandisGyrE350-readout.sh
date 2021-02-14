#!/usr/bin/env bash

# Landis+Gyr E350 power meter readout via
# https://wiki.volkszaehler.org/hardware/controllers/ir-schreib-lesekopf-usb-ausgang
# connected to /dev/ttyUSB0

trap 'kill -s HUP 0' EXIT

# The power meters IR interface always starts at to 300 aud
stty -F /dev/ttyUSB0 300 evenp cs7 -opost igncr -isig -icanon -hupcl -echo -ixon -clocal

while date -Is
do
  # after the successful readout baud rate is back at 300
  stty -F /dev/ttyUSB0 300
  timeout --foreground 10s cat  < /dev/ttyUSB0 &
  sleep 0.1
  # start handshake with power meter
  echo -en '/?!\r\n' > /dev/ttyUSB0
  sleep 1.5
  # switch power meter to 4800 baud and request readout
  echo -en '\x06040\r\n' > /dev/ttyUSB0
  # wait until command is transmitted at 300 baud…
  sleep 0.2
  # … and also switch our side to the requested baud rate of 4800 to receive
  # the answer from the powermeter
  stty -F /dev/ttyUSB0 4800
  # wait for cat timeout
  wait
  echo
done
