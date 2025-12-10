#!/bin/bash
mountpoint=/mnt/analysis_fs

if [ ! -d $mountpoint ]; then
    echo "Creating mountpoint at $mountpoint"
    sudo mkdir -p $mountpoint
fi

echo "WILL WIPE DISK USE WITH CARE"

echo -e "\nListing Disks"
lsblk
echo -e "\nEnter disk (e.x. sda or sdb - BE CAREFUL)"
read disk
block="/dev/${disk}"

echo -e "\nZeroing $block"
sudo dd if=/dev/zero of=$block status=progress bs=32M conv=fdatasync

echo -e "\nCreating Partitions on $block"
sudo echo ',,b;' | sudo sfdisk $block
echo -e "\n\nEnter Disk (e.x. sda1 or sdb1)"
lsblk
read part
partition="/dev/${part}"
echo -e "\nMaking FAT32 Filesystem on $partition"
sudo mkfs.vfat -F 32 $partition
echo -e "\n$block Status:"
sudo sfdisk -l $block
echo -e "\nMounting $partition at $mountpoint"
sudo mount $partition $mountpoint
echo -e "\nDone"
