#!/usr/bin/env bash

# Landis+Gyr E350 power meter readout via
# https://wiki.volkszaehler.org/hardware/controllers/ir-schreib-lesekopf-usb-ausgang
# connected to /dev/ttyUSB0 (based on LandisGyrE350-readout.sh)
#
# Prints system time, L1…3 voltage- & energy readings in InfluxDB UDP line protocol formatting.
#
# To send output to InfluxDB on 127.0.0.1 call:
# ./LandisGyrE350-readout-to-influxdb.sh /dev/udp/127.0.0.1/8089

# Query for Grafana
# SELECT DERIVATIVE(realpower_kWh, 1s)*1000*60*60 FROM (SELECT MAX("energy_kWh") AS energy_kWh FROM "powermeter" WHERE $timeFilter GROUP BY time($__interval));


if [ $# -eq 1 ]; then
  exec > "$1"
fi

buffer="$(TMPDIR=/dev/shm mktemp)"
exec 10<> "${buffer}"
rm "${buffer}"

trap 'kill -s HUP 0' EXIT

stty -F /dev/ttyUSB0 300 evenp cs7 -opost igncr -isig -icanon -hupcl -echo -ixon -clocal

while true; do
  stty -F /dev/ttyUSB0 300
  timeout --foreground 10s cat < /dev/ttyUSB0 > /dev/fd/10 &
  sleep 0.1
  echo -en '\r\n/?!\r\n' > /dev/ttyUSB0
  sleep 1.5
  d=$(date +%s)
  echo -en '\x06040\r\n' > /dev/ttyUSB0
  sleep 0.2
  stty -F /dev/ttyUSB0 4800
  wait
  echo "powermeter $(
    awk -F '[(*]' '
      /^!$/ { exit }
      /^1\.8\.0\(/ { printf ("energy_kWh=%.3f", $(NF-1)); }
      /^32\./ { l=1 }
      /^52\./ { l=2 }
      /^72\./ { l=3 }
      /^[357]2\.7\(/ { printf (",l%d_V=%d", l, $(NF-1)); }
    ' /dev/fd/10) $d" 
done
