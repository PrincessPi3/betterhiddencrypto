# Leaks Testing by Filesystem
## Methodology
### OS disk
1. Zero a drive
2. Install Kali on drive
3. Update Kali
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
### FAT32
* 32GB USB-A 3.0 Drive
* Zeroed via `cat /dev/zero /dev/sda`
* FAT32 formatted via 
### NTFS
### EXT4
### ZFS
### BTRFS