#!/bin/bash
log_file="./cryptanalysis/sha512sum-recursive-$(date "+%Y%m%d-%H%M-%S").tmp"

echo "Starting checksum calculation... $PWD"
# sha512 of each file inside of to_encrypt, recursively,  but checc to see if to_encrypt is present to prevent errorz, 2>/dev/null din seem to work idk why
if [ -d ./to_encrypt ]; then
    find ./to_encrypt -type d -name ".git" -prune -o -type f -exec sha512sum {} \; | tee -a "$log_file"
fi

# do the same for the volumes and add to log
find . -type d -name ".git" -prune -o -type f -name ".volume*" -exec sha512sum {} \; | tee -a "$log_file"

echo -e "\nDone! logged to $log_file"