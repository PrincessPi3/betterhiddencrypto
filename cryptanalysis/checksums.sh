#!/bin/bash
log_file=$(sha512sum-recursive-$(date "+%Y%m%d-%H%M-%S").tmp)

echo "Starting checksum calculation..."
# sha512 of each file inside of to_encrypt, recursively
find to_encrypt -type f -exec sha512sum {} \; | tee -a "$log_file" 2>/dev/null # silent on fail
# do the same for the volumes and add to log
find . -type f -name ".volume*" -exec sha512sum {} \; | tee -a "$log_file" 2>/dev/null # silent on fail

echo "Done! logged to $log_file"