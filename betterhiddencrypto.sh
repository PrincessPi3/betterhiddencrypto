#!/bin/bash
# packages: python3, pip, 7z, ripgrep, coreutils, openssl
# pip packages: pycryptodome, argon2-cffi

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
        : # do nothing
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
    sudo chmod -R 777 "$ramdisk"
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
    # make the mount point if not exist
    if [ ! -d "$ramdisk" ]; then
        echo "$ramdisk doensnt exist, creating..."
        sudo mkdir -p "$ramdisk"
    fi

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

# usage my_salt=$(new_7z_salt)
new_7z_salt() {
    # nice solid cryptographically secure rng asssss
    openssl rand $salt_length # echo the salt bytes
}

# todo sanity checks and silent it
append_7z_salt() {
    fix_ramdisk_perms
    salt="$1"
    # append the salt to the encrypted archive
    printf "$salt" >> "$encrypted_archive_name"
}

# todo sanity checks and silent it
prepend_7z_salt() {
    fix_ramdisk_perms
    # echo "$salt$(cat $encrypted_archive_name)" > "$encrypted_archive_name"
    echo -n "$1$(cat $encrypted_archive_name)" > "$encrypted_archive_name"
}

# todo sanity checks and silent it
retrieve_prepend_7z_salt() {
    fix_ramdisk_perms

    # get the stored salt
    head -c $salt_length "$encrypted_archive_name"
   
    # remove the salt from the archive
    ## redirect stdout to /dev/null and allow stderr (progress) to show
    # dd if="$encrypted_archive_name" of="$encrypted_archive_name_tmp" bs=1 skip=$salt_length status=progress 1>/dev/null

    truncate -s $salt_length "$encrypted_archive_name"

    # do da thingggg reset working bin to the the tmp file var
    encrypted_archive_name="$encrypted_archive_name_tmp"
}

# todo sanity checks and silent it
retrieve_7z_salt() {
    # get the stored salt
    tail -c $salt_length "$encrypted_archive_name"
    # remove the salt from the archive
    truncate -s -$salt_length "$encrypted_archive_name"
}

# todo: sanity checks
# usage: digest_passphrase <string passphrase> <bytes raw salt>
# like my_digest=$(digest_passphrase "my_passphrase")
7z_digest_passphrase() {
    iter="$1"
    salt="$2"
    for i in {1..125}; do # 125 rotations set here, seems slow :flushed:
        iter=$(echo "$iter$salt" | sha512sum | awk '{print $1}') # add dat salt for each rot
    done

    # meant for usage like my_var=$(7z_digest_passphrase "my_passphrase")
    echo "$iter"
}

encrypty(){
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
        passphrase=$passphrase1
    fi

    # generate new salt
    debug_echo "Generating new salt for first pass..."
    salt=$(new_7z_salt)

    debug_echo "Salt: $(echo $salt | xxd -p)" # print salt in hex

    debug_echo "Compressing Directory and performing first pass encryption..."
    # digest the passphrase to add as a statistically indepentant 7zip passphrase
    debug_echo "Digesting passphrase phase 1..."
    digested_passphrase=$(7z_digest_passphrase "$passphrase" "$salt")
    debug_echo "Digested Passphrase: $digested_passphrase"

    fix_ramdisk_perms

    if [ $DEBUG -gt 0 ]; then
        debug_return=$(7z a -p"$digested_passphrase" "$encrypted_volume_name" "$dir_to_encrypt")
        debug_echo "$debug_return"
    else
        7z a -p"$digested_passphrase" "$encrypted_volume_name" "$dir_to_encrypt" # 1>/dev/null # silent unless error
    fi

    fix_ramdisk_perms

    # test the new archive for integrity before nuking shit
    debug_echo "Successfully compressed, Testing archive integrity..."
    if [ $DEBUG -gt 0 ]; then
        debug_return=$(7z t -p"$digested_passphrase" "$encrypted_volume_name")
        debug_echo "$debug_return"
    else
        7z t -p"$digested_passphrase" "$encrypted_volume_name" # 1>/dev/null # do this silently unless fail
    fi

    fix_ramdisk_perms

    # nuke to_encrypt dir
    debug_echo "Archive passed check, Shredding directory..."
    shred_dir "$dir_to_encrypt"

    fix_ramdisk_perms

    # do the second pass encryption
    debug_echo "Successfully shredded directory, Running second pass encryption..."
    if [ $DEBUG -gt 0 ]; then
        debug_return=$(python betterhiddencrypto.py enc "$passphrase" "$encrypted_volume_name" "$encrypted_archive_name" $DEBUG)
        debug_echo "$debug_return"
    else
        python betterhiddencrypto.py enc "$passphrase" "$encrypted_volume_name" "$encrypted_archive_name" $DEBUG
    fi

    # shred da 7z file
    debug_echo "Successfully encrypted, Shredding Archive..."
    shred_dir "$encrypted_volume_name"

    fix_ramdisk_perms

    # check for bak archive and backup if exists
    if [ -f "$encrypted_archive_name.bak" ]; then
        timestamp=$(date +"%d%m%Y-%H%M")
        debug_echo "\tBacking up old archive ($encrypted_archive_name.bak.$timestamp)"
        cp "$encrypted_archive_name.bak" "$backup_dir/$encrypted_archive_name.bak.$timestamp"
    fi

    # check for existing archive and backup if exists
    if [ -f "$encrypted_archive_name" ]; then
        debug_echo "\tBacking up new archive ($encrypted_archive_name.bak)"
        cp "$encrypted_archive_name" "$encrypted_archive_name.bak"
    fi

    fix_ramdisk_perms

    # prepend salt bytes to archive
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

    echo -e "\nEnter Passphrase: "
    read -s passphrase

    debug_echo "\tPassphrase: $passphrase"

    fix_ramdisk_perms

    # retreive da salt
    debug_echo "Retrieving salt for first pass..."
    salt=$(retrieve_7z_salt)

    debug_echo "Salt: $(echo $salt | xxd -p)" # print salt in hex

    fix_ramdisk_perms

    # first comes the python crypt
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
    debug_echo "Digesting passphrase phase 1..."
    digested_passphrase=$(7z_digest_passphrase "$passphrase" "$salt")
    debug_echo "Digested Passphrase: $digested_passphrase"

    fix_ramdisk_perms

    if [ $DEBUG -gt 0 ]; then
        debug_return=$(7z x -p"$digested_passphrase" "$encrypted_volume_name" -o$ramdisk)
        debug_echo "$debug_return"
    else
        7z x -p"$digested_passphrase" "$encrypted_volume_name" -o$ramdisk # 1>/dev/null
    fi

    # shred the 7z file
    debug_echo "Successfully decrypted, Shredding encrypted archive..."
    shred_dir "$encrypted_volume_name"

    echo -e "\nSuccess: Decryption done! Decrypted to $dir_to_encrypt"
}

# main
if [ $DEBUG -gt 0 ]; then
    echo -e "\nWARNING: DEBUG MODE IS UNSAFE LOGGING TO $log_file\n"
    echo -e "Debug Log - $(date)\n" > "$log_file" # create/clear log file
fi

# check for ramdisk file and if not, make it
if [ ! -f "$ramdisk_file" ]; then
    ramdisk_gimme
fi

# operating modes
if [ "$1" = "encrypt" -o "$1" = "enc" -o "$1" = "e" ]; then
    # encrypt mode
    environment_check
    encrypty
elif [ "$1" = "decrypt" -o "$1" = "dec" -o "$1" = "d" ]; then
    # decrypt mode
    environment_check
    decrypty
elif [ "$1" = "help" -o "$1" = "h" ]; then
    # halp moed
    # no environment check
    echo -e "\nUsage:\t\n\tEncrypt:\n\t\tbash betterhiddencrypto.sh e\n\t\tbash betterhiddencrypto.sh enc\n\t\tbash betterhiddencrypto.sh encrypt\n\tDecrypt:\n\t\tbash betterhiddencrypto.sh d\n\t\tbash betterhiddencrypto.sh dec\n\t\tbash betterhiddencrypto.sh decrypt\n\tHelp:\n\t\tbash betterhiddencrypto.sh h\n\t\tbash betterhiddencrypto.sh help\n\tSmart (default):\n\t\tbash betterhiddencrypto.sh\n"
elif [ "$1" = "nuke" -o "$1" = "emergency_nuke" -o "$1" = "n" -o "$1" = "wipe" -o "$1" = "shred" -o "$1" = "emergency" ]; then
    # emergency nuke mode
    # no environment check
    EMERGENCY_NUKE
elif [ "$1" = "nukereboot" -o "$1" = "nr" -o "$1" = "reboot" -o "$1" = "shutdown" -o "$1" = "killitwithfire" -o "$1" = "ns" ]; then
    # NUKE SHUTDOWN MODE
    # no environment check
    EMERGENCY_NUKE KILLITWITHFIRE
else
    # smart mode
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
