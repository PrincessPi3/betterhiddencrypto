#!/bin/bash
# if [ -z "$1" ]; then
# 	echo "Usage: scandriveforbytes.sh <block device> <num of bytes to process at a time> <key bytes> <7z key>"
# fi

device=/dev/sda # $1 # block device (ex. /dev/sdX)
atatime=1000 # $2 # num bytes process at a time (ex. 1000)
key='dimple' # key bytes like '\x22\x77\x77'
sevenzkey='testtext' # 7z passphrase like 'fad48ae' 

disktotalbytes=$(($(lsblk -b | rg 'sda' | head -1 | awk '{print $4}') * 1000))
diskdivbytes=$(($(($(lsblk -b | rg $(basename $device) | head -1 | awk '{print $4'}) * 1000)) / 1000))
diskremainderbytes=$(($(lsblk -b | rg 'sda' | head -1 | awk '{print $4}') * 1000 % $atatime))

loops=$(($diskdivbytes + 1))
offset=0

echo -e "device: $device\natatime: $atatime\nkey: $key\nsevenzkey: $sevenzkey\ndisktotalbytes: $disktotalbyte\ndiskdivbytes: $diskdivbytes\ndiskremainderbytes: $diskremainderbytes\nloops: $loops"

for (( i = 0 ; i < $loops; i++ )); do
    # echo "testing offset $offset length $atatime"

	 sudo dd if=$device bs=1 skip=$offset count=$atatime status=none |\
        rg -o -b -U -uuu --text -e 'testtext' -e "(?-u)$key" -e "(?-u)$sevenzkey"
		 
	 if [ $i -eq $loops ]; then
		 offset=$(($i * $atatime + $diskremainderbytes))
	 else
		 offset=$(($i * $atatime))
	fi
done