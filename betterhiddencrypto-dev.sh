#!/bin/bash
# packages: 7z, openssl, argon2, xxd, cracklib-runtime
#   cryptanalysis only: ripgrep

# fail on error
set -e # important to prevent data loss in event of a failure

# CHANGE da config here if ya like
DEBUG=0 # 0 = no debug, 1 = console debug, 2 = log file+console debug
ramdisk="/ramdisk"
ramdisk_file="$ramdisk/.ramdisk"
default_size=2G
mode=1777
# dir_to_encrypt="./to_encrypt"
dir_to_encrypt="$ramdisk/to_encrypt" # only in memory fs for security
encrypted_archive_name="./.volume.bin"
encrypted_archive_name_tmp="$ramdisk/.volume.bin.tmp"
encrypted_volume_name="$ramdisk/.encrypted_volume.7z"
backup_dir="./.volume_old"
salt_length=16 # in 8-bit bytes (16 bytes = 128 bits)
max_length_dir_name_shred=64 # max length for renaming dirs during shred
shred_iterations=3 # number of iterations to do shredding files and dir names
log_file="./$(date +%s)_debug_log.txt" # log file for debug mode

debug_echo() {
    if [ $DEBUG -eq 1 ]; then
        echo -e "$1"
    elif [ $DEBUG -eq 2 ]; then
        echo -e "$1" | tee -a "$log_file"
    else
        return # : # do nothing
    fi
}

environment_check() {
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

    # used to use command -v instead of which and i dont remember why
    if ! [ -f "$(which git)" ] && [ -f "$(which 7z)" ] && [ -f "$(which python)" ] && [ -f "$(which shred)" ] && [ -f "$(which sha512sum)" ] && [ -f "$(which sha256sum)" ]; then
        echo "Needed Applications Not Found!"
        echo "Depends on git, 7z, ugrep, python3, and sha512sum"
        # todo: maybe make a clever installer function
        # sudo apt update
        # sudo apt install git 7z ugrep python3 python3-pip openssl coreutils -y
        # pip install -r requirements.txt
        # echo "Success: Installed"
    fi
}

fix_ramdisk_perms() {
    debug_echo "fix_ramdisk_perms: chmoding $ramdisk to 777 recursively"
    sudo chmod -R 777 "$ramdisk"
    debug_echo "fix_ramdisk_perms: chowning $ramdisk to $USER:USER recursively"
    sudo chown -R $USER:$USER "$ramdisk"
}

# switchan to shred and find because secure-delete is old af
# also shred gives much ore opttions better for ssds and also lets me zero the files out before they remov
shred_dir() {
    fix_ramdisk_perms

    if [ -d "$1" ]; then # if its a dir
        debug_echo "Shredding and deleting directory: $1 with $shred_iterations iterations"

        # next phase is to shred all files in the dir
        find "$1" -path ".git" -prune -o -type f -exec shred --zero --remove --force --iterations=$shred_iterations {} \;

        # attempt to rename dirs to random names first
        # first phase is to rename all dirs to random names to break the structure
        # for i in $(seq 1 $shred_iterations); do
        #     # get random starting dir name for this iteration
        #     random_start_name=$(openssl rand -hex $max_length_dir_name_shred)
        # 
        #     # make the random starting dir
        #     if [ -d "$1" ]; then
        #         echo "Renaming start dir ($1) to random start dir ($random_start_name) for iteration $i"
        #         mv "$1" "$random_start_name"
        #     elif [ -d "$old_random_start_name" ]; then
        #         echo "Renaming old random start dir ($old_random_start_name) to new random start dir ($random_start_name) for iteration $i"
        #         mv "$old_random_start_name" "$random_start_name"
        #     else
        #         echo "FAIL: Directory not found: $1 EXITING"
        #         exit 1 # explicitly fail
        #     fi
        # 
        #     # rename all dirs to random names
        #     echo "find operation iteration $i"
        #     find "$random_start_name" -mindepth 1 -type d -exec mv {} $(openssl rand -hex $max_length_dir_name_shred) \;
        # 
        #     old_random_start_name=$random_start_name # store for next iteration
        # done
        
        # then rename dirs to nullbytes to make sure no names remain
        # TODO: fix this to work
        # find "$1" -mindepth 1 -type d -exec mv {} "$(dd if=/dev/zero bs=1 count=$max_length_dir_name_shred status=none)" \;

        # find "$1" -mindepth 2 -type d -exec mv {} $(openssl rand -hex $max_length_dir_name_shred) \; # remove empty dirs

        # then nuke the all empty dirs
        rm -rf "$1"
    elif [ -f "$1" ]; then # if its a file        
        # three iterations plus a zeroing and deletion
        debug_echo "Shredding and deleting file: $1 with $shred_iterations iterations"
        shred --zero --remove --force --iterations=$shred_iterations "$1" # 1>/dev/null 2>/dev/null
    else # fail
        echo "FAIL: Directory or file not found: $1 EXITING"
        exit 1 # explicitly fail
    fi
}

ramdisk_toggle() {
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
EMERGENCY_NUKE() {
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

# usage:
#   my_salt="$(new_7z_salt)"
new_7z_salt() {
    # nice solid cryptographically secure rng asssss
    openssl rand $salt_length # echo the salt bytes
}

# appends the salt to the file to be removed when retreived with retrieve_7z_salt
# usage:
#   append_7z_salt "$salt"
append_7z_salt() {
    fix_ramdisk_perms
    local_salt="$1"
    # append the salt to the encrypted archive
    printf "$local_salt" >> "$encrypted_archive_name"
}

# todo sanity checks and silent it
# prepend_7z_salt() {
#     fix_ramdisk_perms
#     # echo "$salt$(cat $encrypted_archive_name)" > "$encrypted_archive_name"
#     echo -n "$1$(cat $encrypted_archive_name)" > "$encrypted_archive_name"
# }

# todo sanity checks and silent it
# retrieve_prepend_7z_salt() {
#     fix_ramdisk_perms
# 
#     # get the stored salt
#     head -c $salt_length "$encrypted_archive_name"
#    
#     # remove the salt from the archive
#     ## redirect stdout to /dev/null and allow stderr (progress) to show
#     # dd if="$encrypted_archive_name" of="$encrypted_archive_name_tmp" bs=1 skip=$salt_length status=progress 1>/dev/null
# 
#     truncate -s $salt_length "$encrypted_archive_name"
# 
#     # do da thingggg reset working bin to the the tmp file var
#     encrypted_archive_name="$encrypted_archive_name_tmp"
# }

# 7z salt is appended to the file when made with append_7z_salt and removed when retreived
# usage:
#   retrieve_7z_salt (no args)
retrieve_7z_salt() {
    # get the stored salt
    tail -c $salt_length "$encrypted_archive_name"
    # remove the salt from the archive
    truncate -s -$salt_length "$encrypted_archive_name"
}

# todo: sanity checks
# usage: digest_passphrase <string passphrase> <bytes raw salt>
# like my_digest=$(digest_passphrase "my_passphrase")
# 7z_digest_passphrase() {
#     iter="$1"
#     salt="$2"
#     for i in {1..125}; do # 125 rotations set here, seems slow :flushed:
#         iter=$(echo "$iter$salt" | sha512sum | awk '{print $1}') # add dat salt for each rot
#     done
# 
#     # meant for usage like my_var=$(7z_digest_passphrase "my_passphrase")
#     echo "$iter"
# }

# usage:
#   7z_digest_passphrase 'my passphrase' new_7z_salt/retrieve_7z_salt
7z_digest_passphrase() {
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

encrypty() {
    if [ $DEBUG -gt 0 ]; then
        debug_echo "ENCRYPTING Starting..."
    else
        debug_echo "ENCRYPTION STARTING: vars: dir_to_encrypt: $dir_to_encrypt, encrypted_archive_name: $encrypted_archive_name, encrypted_volume_name: $encrypted_volume_name, backup_dir: $backup_dir, salt_length: $salt_length, max_length_dir_name_shred: $max_length_dir_name_shred, shred_iterations: $shred_iterations"
    fi

    # check da passphrases for match
    echo -e "\nEnter Passphrase: "
    read -s passphrase1
    echo -e "Repeat Passphrase:"
    read -s passphrase2
    if [ "$passphrase1" != "$passphrase2" ]; then
        echo -e "\nPassphrases do not match! Exiting!\n"
        exit 1 # otherwise explicitly fail
    else
        debug_echo "Passwords match!"
        passphrase="$passphrase1"
    fi

    # generate new salt
    debug_echo "Generating new salt for first pass..."
    salt="$(new_7z_salt)"

    debug_echo "Salt: $(echo $salt | xxd -p)" # print salt in hex

    debug_echo "Compressing Directory and performing first pass encryption..."
    # digest the passphrase for use as a statistically indepentant 7zip passphrase
    debug_echo "Digesting passphrase phase 1..."
    digested_passphrase=$(7z_digest_passphrase "$passphrase" "$salt")
    debug_echo "Digested Passphrase: $digested_passphrase"

    fix_ramdisk_perms

    if [ $DEBUG -gt 0 ]; then
        debug_return=$(7z a -p"$digested_passphrase" "$encrypted_volume_name" "$dir_to_encrypt")
        debug_echo "$debug_return"
    else
        # 7z <mode> -p"<passphrase>" <new volume path (.7z)> <directory path to encrypt>
        #   a: create archive
        #   -p"my passphrase" passphrase for encryptiom (note no whitespace betwen -p and the string)
        7z a -p"$digested_passphrase" "$encrypted_volume_name" "$dir_to_encrypt" # 1>/dev/null # silent unless error
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
        7z t -p"$digested_passphrase" "$encrypted_volume_name" # 1>/dev/null # do this silently unless fail
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

decrypty() {
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
