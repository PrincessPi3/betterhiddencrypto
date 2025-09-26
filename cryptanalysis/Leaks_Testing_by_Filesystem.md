# Leaks Testing by Filesystem
## Methodology
### Create Test Disk
[zero_recreate_disk.sh](./zero_recreate_disk.sh)
### OS disk
1. Zwer
2. Install OS on drive
3. Update OS
4. Install any needed remaining tools
5. git clone after reboot
6. Run encryption 
7. Run dedcryption
8. Tun encryption
9. Boot into real disk
10. Hammer device for leaks
### Non-OS Disk
1. Zero a drive
2. Format as specific filesystem
3. Mount drive
4. Perform all the operations on that drive
5. Unmount
6. Hammer for leaks

## Tests
### Linux
#### FAT32
* 32GB USB-A 3.0 Drive
* Zeroed via `cat /dev/zero /dev/sda`
* FAT32 formatted via 
#### NTFS
#### EXT4
#### ZFS
#### BTRFS
### Windows (WSL)
#### NTFS
#### FAT32
#### EXFAT