#!/usr/bin/env bash

# Auf ADAPTEC RAID5 zugreifen ohne passenden Controller
# mit Erhalt der original Adaptec Metadaten

modprobe brd          # Blockdevice RAM Disk
modprobe dm_snapshot  # Devicemapper Snapshot

# Devicemapper Snapshots /dev/mapper/cow_sd[bcd] für
# physische Geräte erstellen
# => leitet Schreibzugriffe in RAM-Disks (/dev/ram[012]) aus

dmsetup create cow_sdb --table "0 $(blockdev --getsize /dev/sdb) \
  snapshot /dev/sdb /dev/ram0 N 1"

dmsetup create cow_sdc --table "0 $(blockdev --getsize /dev/sdc) \
  snapshot /dev/sdc /dev/ram1 N 1"

dmsetup create cow_sdd --table "0 $(blockdev --getsize /dev/sdd) \
  snapshot /dev/sdd /dev/ram2 N 1"

# Linux Kernel Software-RAID (md) erstellen
#
# --assume-clean keinen Rebuild starten
# --chunksize 256 muss der Stripesize des bestehenden RAIDs entsprechen
# --level=5 --raid-devices=3 RAID5 über drei physische Geräte
# --metadata 1.0 schreibt wie Adaptec den RAID-Superblock an das
# Ende der physischen Geräte
# Mögliche Werte:
#   1.0: Ende des Blockdevice
#   1.1: Anfang des Blockdevice (würde in diesem Fall Nutzdaten überschreiben)
#   1.2: bei 4096 Byte an den Anfang des Blockdevice
#        (mdadm Standard, würde in diesem Fall auch Nutzdaten überschreiben)
# --parity la Paritätsanordnung
# Adaptec verwendet gem.
# http://www.techsec.com/pdf/Wednesday/RAID%20Rebuilding%20-%20Dickerman.pdf
# Seite 27 "Backward Parity", das entspricht gem.
# http://www.ufsexplorer.com/inf_raid.php dem Modus Left Asymmetric => "la"
# /dev/mapper/cow... Geräte in ehemaliger Portreihenfolge des Controlleres
# ACHTUNG: NICHT /dev/sd[bcd] verwenden - der Adaptec RAID Superblock würde
# überschrieben

mdadm --create /dev/md0 --assume-clean --chunk=256 --level=5 \
  --raid-devices=3 --metadata=1.0 --parity=la \
  /dev/mapper/cow_sdb /dev/mapper/cow_sdc /dev/mapper/cow_sdd 
