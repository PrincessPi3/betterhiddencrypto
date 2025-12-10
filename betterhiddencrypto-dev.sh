#!/bin/bash
# packages: 7z, openssl, argon2, xxd, cracklib-runtime
#   cryptanalysis only: ripgrep

# fail on error
set -e # important to prevent data loss in event of a failure

# commands needed
required_cmds=(7z openssl argon2 xxd cracklib-check rg) 
packages_debian=(7z openssl argon2 xxd cracklib-runtime ripgrep)

# ramdisk config
ramdisk="/ramdisk" # mountpoint for the ramdisk
ramdisk_file="$ramdisk/.ramdisk" # file to make clear ramdisk is mounted/not mounted
default_size=2G # size of the ramdisk to spin up
mode=1700 # ramdisk perms minimal as possible

# file and dir path
# todo: get script path and make those paths absolute
dir_to_encrypt="$ramdisk/to_encrypt" # only in memory fs for security
encrypted_archive_name="./.volume.bin" # path to encrypted archive, safe to have on non-volatile memory
encrypted_archive_name_tmp=$(mktemp) # temp .bin file # todo: shred after
encrypted_volume_name="$ramdisk/.encrypted_volume.7z" # the 7z file path # todo: maybe use this use mktemp
backup_dir="./.volume_old" # where to put archives .bins

# shred settings
max_length_dir_name_shred=64 # max length for renaming dirs during shred
shred_iterations=3 # number of iterations to do shredding files and dir names

# debug settings
log_file="./$(date +%s)_debug_log.txt" # log file for debug mode
DEBUG=0 # 0 = no debug, 1 = console debug, 2 = log file+console debug

# crypto settings
salt_length=32 # in 8-bit bytes (32 bytes = 256 bits)
aes_iv_length=12 # bytes (12 bytes = 96 bits and is the usual length for aes gcm)

# globals
7z_salt='' # maek a globallll (hex string)
7z_passphrase='' # holds dadigested passphrase to use as a passphrase for 7z encryptin
aes_salt='' # globetrotter (hex string)
aes_iv='' # for durr iv (hex string)
aes_key='' # hex string of derived key for aes
passphrase='' # passphrase globaele

debug_echo () {
    if [ $DEBUG -eq 1 ]; then
        echo -e "$1"
    elif [ $DEBUG -eq 2 ]; then
        echo -e "$1" | tee -a "$log_file"
    else
        return 0 # do nothing
    fi
}


environment_check () {
    # chezh em if both dir and archive dont exist
    if ! [ -d "$dir_to_encrypt" ] && ! [ -f "$encrypted_archive_name" ]; then
        debug_echo "$dir_to_encrypt and $encrypted_archive_name not found, Creating $dir_to_encrypt..."
        mkdir "$dir_to_encrypt"
    fi

    # cerate backup dir if missin
    if ! [ -d "$backup_dir" ]; then
        debug_echo "$backup_dir not found, creating..."
		mkdir "$backup_dir"
	fi

    # make the ramdisk mount point if not exist
    if [ ! -d "$ramdisk" ]; then
        echo "$ramdisk doensnt exist, creating..."
        sudo mkdir -p "$ramdisk"
    fi

    # check for any dangling .7z files
    # todo: convert this to find?
    if [ -f *.7z ]; then
        echo "WARNING! DANGLING UNENCRYPTED ARCHIVE FOUND! EXITING"
        ls -AR ./*.7z
        exit 1 # explicitly fail
    fi

    # check if needed packagees installed
    check_requirements "${required_cmds[@]}"
}

generate_salts_and_iv () {
    # these outpoot as globalz :pidreaming:
    7z_salt=$(openssl rand -hex $salt_length)
    aes_salt=$(openssl rand -hex $salt_length)
    aes_iv=$(openssl rand -hex $aes_iv_length)
}

# usage
#   argon2id_drive_key (no params)
argon2id_derive_keys () {
    # AES settings    
    aes_hash_len=32 # 256 bit key ofc
    aes_time_cost=64 # numbrt iterations to use aka time cost -t default=3
    aes_memory_cost=17 # memory cost in 2^n KiB. At 16, memory cost is 65536 KiB ~67mb. 17 is 131072 KiB ~134Mb default=12 (4096 KiB ~4Mb)
    # 7z settings a bit different for fun :3
    7z_hash_len=64 # bytes length of output hash aka -l makin it 512 bits here basically for da lulz default=32 
    7z_time_cost=62
    7z_memory_cost=16 # ~67MB
    # sHARED SETTING
    paraellism=4 # number of cores to allow used to compute the key, making it run faster without a direct security tradeoff. default=1

    # echo
    #   -n: do not add trailing newline to echoed message
    # argon2
    #   -id: use argon2id algo not the default argon2i
    #   -r: output raw hex bytes string
    #   -l: output hash length in bytes, default=32
    #   -t: time cost: int number of iterations, default=3
    #   -m: memory cost in 2^n KiB, default 12
    #   -p: paralellism: number of cores to allow to use to process the hash, making it faster without a direct security tradeoff, default=1

    # AES key
    aes_key=$(echo -n "$passphrase" | argon2 "$aes_salt" -id -r -l $aes_hash_len -t $aes_time_cost -m $aes_memory_cost -p $paraellism)

    # 7z passphrase digest
    7z_passphrase=$(echo -n "$passphrase" | argon2 "$7z_salt" -id -r -l $7z_hash_len -t $7z_time_cost -m $7z_memory_cost -p $paraellism)
}

aes_gcm_256_encrypt () {
    tag_bin=$(mktemp) # use a tmp file

    openssl aes-256-gcm -e \
        -K "$aes_key" \
        -iv "$aes_iv" \
        -tag "$tag_bin" \
        -in "$encrypted_volume_name" \
        -out "$encrypted_archive_name_tmp"
    
    tag_hex=$(xxd -p "$tag_bin")
    
    # append hex to tmp file
    append_data "$tag_hex" "$encrypted_archive_name_tmp"

    # clean up tag binary
    shred --force --remove --zero --iterations=3 "$tag_bin"    
}

fix_ramdisk_perms () {
    debug_echo "fix_ramdisk_perms: chmoding $ramdisk dirs to 700 recursively"
    sudo find "$ramdisk" -type d -exec chmod 700 "{}" \;
    
    debug_echo "fix_ramdisk_perms: chmoding $ramdisk files to 700 recursively"
    sudo find "$ramdisk" -type f -exec chmod 600 "{}" \; 

    debug_echo "fix_ramdisk_perms: chowning $ramdisk to $USER:$USER recursively"
    sudo chown -R $USER:$USER "$ramdisk"
}

ramdisk_toggle () {
    # if the ramdisk is active (ramdisk_file exists)
    if [ -f "$ramdisk_file" ]; then
        echo "ramdisk is operating, umounting"
        sudo umount "$ramdisk"
        exit 0
    fi

    # handle ramdisk size and default
    if [ -z "$1" ]; then
        echo "Using default ramdisk size of $default_size"
        ramdisk_size=$default_size
    else
        echo "Using size $1"
        ramdisk_size=$1
    fi

    # mount ramdisk
    sudo mount -t tmpfs -o rw,nodev,size=$ramdisk_size,mode=$mode tmpfs $ramdisk
    ret=$?

    # check
    if [ $ret -ne 0 ]; then
        echo "Error mounting ramdisk $ramdisk ($ramdisk_size) return code $ret"
    else
        echo "Mounted ramdisk $ramdisk ($ramdisk_size)"

        # create the ramdisk_file
        echo 1 > "$ramdisk_file" 
    fi
}

# note: rework and add nuke alias to rcfile something llike
##   alias EMERGENCY_NUKE='setsid bash /path/to/betterhiddencrypto.sh ns; clear; exit'
EMERGENCY_NUKE () {
    # NUKE EVERYFUCKINGTHING IN THIS DIR
    # CRASH IT WITH NO SURVIVors

    fix_ramdisk_perms

    # first phase just tosses the encryption headers (top 164 bytes) from the .volume.bin files and backups
    # this is done first and fast as possible for emergencies
    # this is done blocking to make sure it completes before moving on
    find . -path ".git" -prune -o -type f -name "*.volume.bin*" -exec shred --size=164 --zero --force {} \; # 1>/dev/null 2>/dev/null

    # next stage is to shred to_encrypt if it exists
    # TODO: make sure this runs non-blocking and fast as possible
    if [ -d "$dir_to_encrypt" ]; then
        shred_dir "$dir_to_encrypt" # 1>/dev/null 2>/dev/null
    fi

    # third stage is to nuke any remaining dangling files explicitly
    # TODO: make sure this runs non-blocking and fast as possible
    # specifically target .7z, .bak, and .tmp files
    # use find to do this recursively and skip .git dirs for speed
    find . -path ".git" -prune -o -type f -name "*.7z" -o -type f -name "*.bak*" -o -type f -name "*.tmp*" -exec shred --zero --force {} \; # 1>/dev/null 2>/dev/null

    # third stage is to go log the current dir's name, go up a directory, and shred everyfucking thing remaining
    # all dis shit is done silently fuck errors
    current_dir=$(basename "$PWD") # 1>/dev/null 2>/dev/null
    cd ..
    shred_dir "./$current_dir" # 1>/dev/null 2>/dev/null

    # optionally reboot immediately to wipe memory
    # runs when called with any argument at all
    if ! [ -z "$1" ]; then
        sudo shutdown now
    fi
}

# appends the salt to the file to be removed when retreived with retrieve_data
# usage:
#   append_data "$data"
append_data () {
    fix_ramdisk_perms
    local_data="$1"
    # append the salt to the encrypted archive
    printf "$local_data" >> "$encrypted_archive_name"
}

# data appended to the file with append_data and removed when retreived
# echos the data retreived
# usage:
#   retrieve_appended_data <int length in bytes> <string file path>
#   retrieve_appended_data 32 /path/to/file.bin
#   my_iv=$(retrieve_appended_data 32 /path/to/file.bin)
retrieve_appended_data () {
    # maek friendly naMES
    local data_length=$1 # bytes
    local file_path="$2" # absolute path

    # sanity checks
    ## if first arg emptyy
    if [ -z "$data_length" ]; then
        echo "retrieve_appended_data FAIL: no first argument given to function"
        exit 1 # explicitly fail with error
    fi
    ## if arg 2 is empty
    if [ -z "$file_path" ]; then
        echo "retrieve_appended_data FAIL: no second arg given to function!"
        exit 1 # fail out
    fi
    ## if its present but not a file
    if [ ! -f "$file_path" ]; then
        echo "retrieve_appended_data FAIL: '$file_path' is not a file!"
        exit 1 # explicitly ffail with error
    fi

    # get the data and echo it
    # todo: make sure no newlines or anything end up in hereee
    tail -c $data_length "$file_path"

    # remove the data from the archive
    truncate -s -$data_length "$file_path"
}

# usage:
#   7z_digest_passphrase 'my passphrase' new_7z_salt/retrieve_7z_salt
7z_digest_passphrase () {
    local_passphrase="$1" # passphrase from args
    local_salt="$2" # salt from args
    hash_len=64 # bytes length of output hash aka -l default=32
    time_cost=64 # numbrt iterations to use aka time cost -t default=3
    memory_cost=17 # memory cost in 2^n KiB. At 16, memory cost is 65536 KiB ~67mb. 17 is 131072 KiB ~134Mb default=12 (4096 KiB ~4Mb)
    paraellism=4 # number of cores to allow used to compute the key, making it run faster without a direct security tradeoff. default=1

    # echo
    #   -n: do not add trailing newline to echoed message
    # argon2
    #   -id: use argon2id algo not the default argon2i
    #   -r: output raw hex bytes string
    #   -l: output hash length in bytes, default=32
    #   -t: time cost: int number of iterations, default=3
    #   -m: memory cost in 2^n KiB, default 12
    #   -p: paralellism: number of cores to allow to use to process the hash, making it faster without a direct security tradeoff, default=1
    # xxd
    #   -r: make raw bytes out of hex string
    #   -p: use plain flat hex string like
    echo -n "$local_passphrase" | argon2 "$local_salt" -id -r -l $hash_len -t $time_cost -m $memory_cost -p $paraellism | xxd -r -p
}

encrypty () {
    if [ $DEBUG -gt 0 ]; then
        debug_echo "ENCRYPTING Starting..."
    else
        debug_echo "ENCRYPTION STARTING: vars: dir_to_encrypt: $dir_to_encrypt, encrypted_archive_name: $encrypted_archive_name, encrypted_volume_name: $encrypted_volume_name, backup_dir: $backup_dir, salt_length: $salt_length, max_length_dir_name_shred: $max_length_dir_name_shred, shred_iterations: $shred_iterations"
    fi

    # get a passphrases
    echo -e "\nEnter Passphrase: "
    read -s passphrase1
    echo -e "Repeat Passphrase:"
    read -s passphrase2
    # check if passphrases match
    if [ "$passphrase1" != "$passphrase2" ]; then
        echo -e "\nPassphrases do not match! Exiting!\n"
        exit 1 # otherwise explicitly fail
    else
        debug_echo "Passwords match!"
        passphrase="$passphrase1"
    fi

    # generate new salt
    debug_echo "Generating new salts and iv ..."
    generate_salts_and_iv

    debug_echo "Deriving keys..."
    argon2id_derive_keys

    # debug_echo "Salt: $(echo $salt | xxd -p)" # print salt in hex

    debug_echo "Compressing Directory and performing first pass encryption..."
    # digest the passphrase for use as a statistically indepentant 7zip passphrase
    # debug_echo "Digesting passphrase phase 1..."
    # digested_passphrase=$(7z_digest_passphrase "$passphrase" "$salt")
    # debug_echo "Digested Passphrase: $digested_passphrase"

    fix_ramdisk_perms

    if [ $DEBUG -gt 0 ]; then
        debug_return=$(7z a -p"$7z_passphrase" "$encrypted_volume_name" "$dir_to_encrypt")
        debug_echo "$debug_return"
    else
        # 7z <mode> -p"<passphrase>" <new volume path (.7z)> <directory path to encrypt>
        #   a: create archive
        #   -p"my passphrase" passphrase for encryptiom (note no whitespace betwen -p and the string)
        7z a -p"$7z_passphrase" "$encrypted_volume_name" "$dir_to_encrypt" # 1>/dev/null # silent unless error
    fi

    fix_ramdisk_perms

    # test the new archive for integrity before nuking shit
    debug_echo "Successfully compressed, Testing archive integrity..."
    if [ $DEBUG -gt 0 ]; then
        # 7z t: test existing 7z encrypted archive
        debug_return=$(7z t -p"$digested_passphrase" "$encrypted_volume_name")
        debug_echo "$debug_return"
    else
        # 7z t: test existing 7z encrypted archive
        7z t -p"$7z_passphrase" "$encrypted_volume_name" # 1>/dev/null # do this silently unless fail
    fi

    fix_ramdisk_perms

    # nuke to_encrypt dir
    debug_echo "Archive passed check, Shredding directory..."
    shred_dir "$dir_to_encrypt" # ig we'll just leave dis here for idk anti-memory forensics/cold boot attacks?

    fix_ramdisk_perms

    # do the second pass encryption
    debug_echo "Successfully shredded directory, Running second pass encryption..."
    if [ $DEBUG -gt 0 ]; then
        # python betterhiddencrypto.py
        #       <mode>
        #       "<passphrase>"
        #       <encrypted .7z archive path>
        #       <final encrypted archive path>
        #       <debug mosw>
        #   mode:
        #        enc: encrypt archive
        #        dec: decrypt archive
        # debug mode
        #   0: normal operating mode
        #   1: DEBUG MODE DISPLAYS KEYS AND SECRETS TO TERMINAL (INSECURE)
        #   2: DEBUG MODE DISPLAY KEYS AND SECRETS TO TERMINAL AND FILE (VERY INSECURE)
        debug_return=$(python betterhiddencrypto.py enc "$passphrase" "$encrypted_volume_name" "$encrypted_archive_name" $DEBUG)
        debug_echo "$debug_return"
    else
        python betterhiddencrypto.py enc "$passphrase" "$encrypted_volume_name" "$encrypted_archive_name" $DEBUG
    fi

    # shred da 7z file
    debug_echo "Successfully encrypted, Shredding Archive..."
    shred_dir "$encrypted_volume_name" # again ig we might as well for anti-memory forensics or whatever idkfam i took drugs

    fix_ramdisk_perms

    # check for .bak backup of .bin archive, archive and backup if exists
    if [ -f "$encrypted_archive_name.bak" ]; then
        timestamp=$(date +"%d%m%Y-%H%M")
        debug_echo "\tBacking up old archive ($encrypted_archive_name.bak.$timestamp)"
        cp "$encrypted_archive_name.bak" "$backup_dir/$encrypted_archive_name.bak.$timestamp"
    fi

    # check for existing .bin archive file and backup if exists
    if [ -f "$encrypted_archive_name" ]; then
        debug_echo "\tBacking up new archive ($encrypted_archive_name.bak)"
        cp "$encrypted_archive_name" "$encrypted_archive_name.bak"
    fi

    fix_ramdisk_perms

    # append 7z digest salt bytes to .bin archive file
    debug_echo "Storing salt for first pass..."
    append_7z_salt "$salt"

    # umount ramdisk
    ramdisk_toggle

    echo -e "\nSuccess: Encryption done! Encrypted to $encrypted_archive_name"
}

decrypty () {
    if [ $DEBUG -gt 0 ]; then
        debug_echo "DECRYPTION STARTING: vars: dir_to_encrypt: $dir_to_encrypt, encrypted_archive_name: $encrypted_archive_name, encrypted_volume_name: $encrypted_volume_name, backup_dir: $backup_dir, salt_length: $salt_length, max_length_dir_name_shred: $max_length_dir_name_shred, shred_iterations: $shred_iterations"
    else
        echo "DECRYPTION STARTING..."
    fi

    # grab user input for passphrase
    echo -e "\nEnter Passphrase: "
    read -s passphrase

    debug_echo "\tPassphrase: $passphrase"

    fix_ramdisk_perms

    # retreive da salt and remove it from the .bin archive
    debug_echo "Retrieving salt for first pass..."
    salt=$(retrieve_7z_salt) 

    debug_echo "Salt: $(echo $salt | xxd -p)" # print salt in hex

    fix_ramdisk_perms

    # first comes the python decrypt (the handler for AES in GCM mode with 256-bit key)
    debug_echo "Decrypting first pass..."
    if [ $DEBUG -gt 0 ]; then
        debug_return=$(python betterhiddencrypto.py dec "$passphrase" "$encrypted_archive_name" "$encrypted_volume_name" $DEBUG)
        debug_echo "$debug_return"
    else
        python betterhiddencrypto.py dec "$passphrase" "$encrypted_archive_name" "$encrypted_volume_name" $DEBUG
    fi

    # do the 7z decryption/decompression
    debug_echo "Successfully decrypted first pass encryption, Decompressing second pass decrypting..."
    # the statistically independent passphrase for redundant encryption
    # digests the passphrase and the 7z salt to decrypt
    debug_echo "Digesting passphrase phase 1..."
    digested_passphrase=$(7z_digest_passphrase "$passphrase" "$salt")
    debug_echo "Digested Passphrase: $digested_passphrase"

    fix_ramdisk_perms

    # 7z x: decrypt 7z encrypted file and extract
    if [ $DEBUG -gt 0 ]; then
        debug_return=$(7z x -p"$digested_passphrase" "$encrypted_volume_name" -o$ramdisk)
        debug_echo "$debug_return"
    else
        7z x -p"$digested_passphrase" "$encrypted_volume_name" -o$ramdisk # 1>/dev/null
    fi

    # shred the 7z file
    debug_echo "Successfully decrypted, Shredding encrypted archive..."
    shred_dir "$encrypted_volume_name" # moar o dis ig lmfao

    echo -e "\nSuccess: Decryption done! Decrypted to $dir_to_encrypt"
}

# main
# uses "${mode_arg,,}" below for mode so that it can match case insensitively in the mode conditionals
mode_arg="$1" # main mode arguemnt

# handle debug mode > 0
if [ $DEBUG -gt 0 ]; then
    echo -e "\nWARNING: DEBUG MODE IS UNSAFE LOGGING TO $log_file\n"
    echo -e "Debug Log - $(date)\n" > "$log_file" # create/clear log file
fi

# check for ramdisk file and if not, make it
if [ ! -f "$ramdisk_file" ]; then
    ramdisk_gimme
fi

# operating modes

# encrypt mode
# any arg $1 that begins with a upper or lower case e/E will do
if [[ "${mode_arg,,}" =~ ^[e]{1} ]]; then
    # encrypt mode
    environment_check
    encrypty
# any arg $1 that begings with a upper or lower case d/D will work
elif [[ "${mode_arg,,}" =~ ^[d]{1} ]]; then
    # decrypt mode
    environment_check
    decrypty
# any arg $1 that starts with upper or lowercase h/H will go
elif [[ "${mode_arg,,}" =~ ^[h]{1} ]]; then
    # halp moed
    # no environment check
    echo -e "\nUsage:\t\n\tEncrypt:\n\t\tbash betterhiddencrypto.sh e\n\t\tbash betterhiddencrypto.sh enc\n\t\tbash betterhiddencrypto.sh encrypt\n\tDecrypt:\n\t\tbash betterhiddencrypto.sh d\n\t\tbash betterhiddencrypto.sh dec\n\t\tbash betterhiddencrypto.sh decrypt\n\tHelp:\n\t\tbash betterhiddencrypto.sh h\n\t\tbash betterhiddencrypto.sh help\n\tSmart (default):\n\t\tbash betterhiddencrypto.sh\n"
# emergency nuke mode
# nuke mode arg $1s case insensitive: nuke, wipe, shred
if [[ "${mode_arg,,}" == "nuke" || "${mode_arg,,}" == "wipe" || "${mode_arg,,}" == "shred" ]]; then
    # no environment check
    EMERGENCY_NUKE
# NUKE SHUTDOWN MODE
# works with any in arg $1, case insensitive: nr, ns, reboot, shutdown, killitwithfire
elif [[ "${mode_arg,,}" == "nukereboot" || "${mode_arg,,}" == "nr" || "${mode_arg,,}" == "reboot" || "${mode_arg,,}" == "shutdown" || "${mode_arg,,}" == "killitwithfire" ||  "${mode_arg,,}" == "ns" ]]; then
    # no environment check
    EMERGENCY_NUKE KILLITWITHFIRE
else
    # smart mode (automatic encrypt or decrypt) when no arg $1
    if [ -d "$dir_to_encrypt" ]; then
        # smart mkode encrypt
        environment_check
        echo -e "Found existing directory to encrypt ($dir_to_encrypt), defaulting to encryption...\n"
        encrypty
    else
        # smart mode decryption
        environment_check
        echo -e "No directory found to encrypt ($dir_to_encrypt), defaulting to decryption...\n"
        decrypty
    fi
fi
