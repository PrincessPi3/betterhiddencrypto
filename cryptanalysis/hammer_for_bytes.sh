#!/bin/bash
# usage:
## run betterhiddencrypto.sh after enabling debug in betterhiddencrypto.py
## copy all the bytes regex to below
## logs to ./silly_hammer_for_bytes_log_<start unix seconds>.txt
##  bash hammer_for_bytes.sh /path/to/disk/image

# EDIT THESE FRONG
passphrase_regex='\x{49}\x{64}\x{6c}\x{79}\x{31}\x{2d}\x{4f}\x{69}\x{6c}\x{38}\x{2d}\x{53}\x{74}\x{79}\x{6c}\x{69}\x{6e}\x{67}\x{34}\x{2d}\x{47}\x{6f}\x{6f}\x{64}\x{38}\x{2d}\x{43}\x{61}\x{6d}\x{65}\x{6f}\x{37}'
salt_regex='\x{37}\x{0d}\x{94}\x{88}\x{d7}\x{1e}\x{ff}\x{70}\x{c7}\x{ef}\x{7a}\x{61}\x{66}\x{d6}\x{d5}\x{a0}'
iv_regex='\x{b8}\x{b9}\x{bc}\x{cb}\x{94}\x{0c}\x{a7}\x{31}\x{e2}\x{b0}\x{f7}\x{4c}\x{55}\x{4b}\x{50}\x{05}'
crib_regex='\x{46}\x{6c}\x{61}\x{70}\x{39}\x{2d}\x{50}\x{61}\x{72}\x{61}\x{73}\x{61}\x{69}\x{6c}\x{31}\x{2d}\x{52}\x{65}\x{61}\x{70}\x{70}\x{6f}\x{69}\x{6e}\x{74}\x{31}\x{2d}\x{42}\x{72}\x{69}\x{67}\x{68}\x{74}\x{39}\x{2d}\x{43}\x{68}\x{75}\x{74}\x{65}\x{36}'

uniz_seconds=$(date +%s)
dog_file="./silly_hammer_for_bytes_log_$uniz_seconds.txt"

# uses ugrep
# -X hexdump all matches
# -z decompress files if need be to scan them (supports zip/7z/tar/pax/cpio/gz/Z/bz/bz2/lzma/xz/lz4/zstd/brotli)
# -R recursive search through dirs and subdirs
# -H make sure to display filename even when scanning a single file
# -n output line number of match
# -b output byte offset of match
# -o output only the matched part
find_bytes() {
    echo -e  "\nSEARCHING FOR $3 BYTES $1 IN $2 AT $uniz_seconds\n" | tee -a $dog_file
    ug -X -z -R -H -n -b -o $1 $2 | tee -a $dog_file
}

# start da log
echo -e "\nFIND SOME MOFUCKIN BYTES STARTING AT $(date)\n" | tee -a $dog_file

# passphrase
find_bytes $passphrase_regex $1 "PASSPHRASE"
# salt
find_bytes $salt_regex $1 "SALT"
# iv
find_bytes $iv_regex $1 "IV"
# crib
find_bytes $crib_regex $1 "CLEARTEST CRIB"

# finish da log
echo -e "\nDONE FINDIN SOME MOFUCKIN BYTES FINISHED AT $(date)\n" | tee -a $dog_file
