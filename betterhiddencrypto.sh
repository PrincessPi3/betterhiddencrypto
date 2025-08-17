#!/bin/bash
# packages: python3, pip, 7z, ugrep, coreutils

# fail on error
set -e # important to prevent data loss in event of a failure

dir_to_encrypt="to_encrypt"
encrypted_archive_name="./.volume.bin"
encrypted_volume_name="./.encrypted_volume.7z"
backup_dir="./.volume_old"

environment_check() {
    # if ! [ -d "$dir_to_encrypt" ] && [ -f "$encrypted_archive_name" ]; then
    #     echo "$dir_to_encrypt and $encrypted_archive_name Not Found, Creating..."
    #     mkdir "$dir_to_encrypt" 
	# fi

    if ! [ -d "$backup_dir" ]; then
		echo "$backup_dir Not found, creating..."
		mkdir "$backup_dir"
	fi

    if [ -f *.7z ]; then
        echo "WARNING! DANGLING UNENCRYPTED ARCHIVE FOUND"
        ls -AR ./*.7z
    fi

    # used to use command -v instead of which and i dont remember why
    if ! [ -f "$(which git)" ] && [ -f "$(which 7z)" ] && [ -f "$(which python)" ] && [ -f "$(which srm)" ] && [ -f "$(which sha512sum)" ]; then
        echo "Needed Applications Not Found!"
        echo "Depends on git, 7z, ugrep, python3, and sha512sum"
        # sudo apt update
        # sudo apt install git secure-delete 7z ugrep python3 -y
        # pip install -r requirements.txt
        # echo "Success: Installed"
    fi
}

# switchan to shred and find because secure-delete is old af
# also shred gives much ore opttions better for ssds and also lets me zero the files out before they remov
shred_dir() {
    if [ -d "$1" ]; then # if its a dir
        # three iterations plus a zeroing and deletion then rm -rf to remove the directory structure
        # all the uses of shred redirect all output to /dev/null so that its silent af
        # also all find operatons on nukin shit excludes any dir named .git for speed
        find -type d -name ".git" -prune -o "$1" -type f -exec shred --zero --remove --force {} \; 1>/dev/null 2>/dev/null
        rm -rf "$1" 1>/dev/null 2>/dev/null
    elif [ -f "$1" ]; then # if its a file
        # three iterations plus a zeroing and deletion
        shred --zero --remove --force "$1" 1>/dev/null 2>/dev/null
    else # fail
        echo "FAIL: Directory or file not found: $1 EXITING"
        exit 1 # explicitly fail
    fi
}

EMERGENCY_NUKE() {
    # NUKE EVERYFUCKINGTHING IN THIS DIR
    # CRASH IT WITH NO SURVIVors

    echo "NUKANNN"

    # first phase just tosses the encryption headers (top 100 bytes) from the .volume.bin files and backups
    # this is done first and fast as possible for emergencies
    find . -type d -name ".git" -prune -o -type f -name "*.volume.bin*" -exec shred --size=100 --force {} \; # 1>/dev/null 2>/dev/null

    # next stage is to shred to_encrypt if it exists
    if [ -d "$dir_to_encrypt" ]; then
        shred_dir "$dir_to_encrypt" # 1>/dev/null 2>/dev/null
        echo $?
    fi

    # third stage is to nuke any remaining dangling files explicitly
    find . -type d -name ".git" -prune -o -type f -name "*.7z" -o -type f -name "*.bak*" -o -type f -name "*.tmp*" -exec shred --force {} \; # 1>/dev/null 2>/dev/null

    # third stage is to go log the current dir's name, go up a directory, and shred everyfucking thing remaining
    # all dis shit is done silently fuck errors
    current_dir=$(basename "$PWD") # 1>/dev/null 2>/dev/null
    cd .. # 1>/dev/null 2>/dev/null
    shred_dir "$current_dir" # 1>/dev/null 2>/dev/null

    # optionally reboot immediately to wipe memory
    # runs when called with any argument at all
    if ! [ -z "$1" ]; then
        sudo shutdown now
    fi
}

encrypty(){
    echo "ENCRYPTING Starting..."
    echo -e "\nEnter Passphrase: "
    read -s passphrase1
    echo -e "Repeat Passphrase:"
    read -s passphrase2
    if [ "$passphrase1" != "$passphrase2" ]; then
        echo -e "\nPassphrases do not match! Exiting!\n"
        exit 1
    else
        echo -e "\n\tPasswords match!"
        passphrase=$passphrase1
    fi

    echo -e "\tCompressing Directory and performing first pass encryption..."
    # digest the passphrase to add as a statistically indepentant 7zip passphrase
    digest_passphrase=$(echo "$passphrase" | sha512sum | awk '{print $1}')
    7z a -p"$digest_passphrase" "$encrypted_volume_name" "$dir_to_encrypt" 1>/dev/null # silent unless error

    echo -e "\tSuccessfully compressed, Testing archive integrity..."
    7z t -p"$digest_passphrase" "$encrypted_volume_name" 1>/dev/null # do this silently unless fail 
    if [ $? -ne 0 ]; then # explicitly exit on fail integrity check
        echo "Archive integrity test failed!"
        exit 1
    fi

    echo -e "\tArchive passed check, Shredding directory..."
    shred_dir "$dir_to_encrypt"

    echo -e "\tSuccessfully shredded directory, Running second pass encryption..."
    python betterhiddencrypto.py enc "$passphrase" "$encrypted_volume_name" "$encrypted_archive_name"

    echo -e "\tSuccessfully encrypted, Shredding Archive..."
    shred -z "$encrypted_volume_name"

    # check for bak archive and backup if exists
    if [ -f "$encrypted_archive_name.bak" ]; then
        echo -e "\tBacking up old archive ($encrypted_archive_name.bak)"
        cp "$encrypted_archive_name.bak" "$backup_dir/$encrypted_archive_name.bak.$(date +"%d%m%Y-%H%M")"
    fi

    # check for existing archive and backup if exists
    if [ -f "$encrypted_archive_name" ]; then
        echo -e "\tBacking up new archive ($encrypted_archive_name.bak)"
        cp "$encrypted_archive_name" "$encrypted_archive_name.bak"
    fi

    echo -e "\nSuccess: Encryption done! Encrypted to $encrypted_archive_name"

}

decrypty(){
    echo "DECRYPTION Starting..."
    echo -e "\nEnter Passphrase: "
    read -s passphrase

    echo -e "\n\tDecrypting first pass..."
    python betterhiddencrypto.py dec "$passphrase" "$encrypted_archive_name" "$encrypted_volume_name"

    echo -e "\tSuccessfully decrypted first pass encryption, Decompressing second pass decrypting..."
    # the statistically independent passphrase for redundant encryption
    digest_passphrase=$(echo "$passphrase" | sha512sum | awk '{print $1}')
    7z x -p"$digest_passphrase" "$encrypted_volume_name" 1>/dev/null

    echo -e "\tSuccessfully decrypted, Shredding encrypted archive..."
    srm -rz "$encrypted_volume_name"

    echo -e "\nSuccess: Decryption done! Decrypted to $dir_to_encrypt"
}

# run at each start
environment_check

# opreating modez
if [ "$1" = "encrypt" -o "$1" = "enc" -o "$1" = "e" ]; then
    encrypty
elif [ "$1" = "decrypt" -o "$1" = "dec" -o "$1" = "d" ]; then
    decrypty
elif [ "$1" = "help" -o "$1" = "h" ]; then
    echo -e "\nUsage:\t\n\tEncrypt:\n\t\tbash betterhiddencrypto.sh e\n\t\tbash betterhiddencrypto.sh enc\n\t\tbash betterhiddencrypto.sh encrypt\n\tDecrypt:\n\t\tbash betterhiddencrypto.sh d\n\t\tbash betterhiddencrypto.sh dec\n\t\tbash betterhiddencrypto.sh decrypt\n\tHelp:\n\t\tbash betterhiddencrypto.sh h\n\t\tbash betterhiddencrypto.sh help\n\tSmart (default):\n\t\tbash betterhiddencrypto.sh\n"
elif [ "$1" = "nuke" -o "$1" = "emergency_nuke" -o "$1" = "n" -o "$1" = "wipe" -o "$1" = "shred" -o "$1" = "emergency" ]; then
    EMERGENCY_NUKE
else
    # smart mode
    if [ -d "$dir_to_encrypt" ]; then
        echo -e "Found existing directory to encrypt ($dir_to_encrypt), defaulting to encryption...\n"
        encrypty
    else
        echo -e "No directory found to encrypt ($dir_to_encrypt), defaulting to decryption...\n"
        decrypty
    fi
fi
