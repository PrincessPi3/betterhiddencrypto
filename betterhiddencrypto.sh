#!/bin/bash
# packages: python3, secure-delete, 7z, ugrep, sha512sum

# fail on error
set -e # important to prevent data loss in event of a failure

dir_to_encrypt="./to_encrypt"
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
    srm -rz "$dir_to_encrypt"

    echo -e "\tSuccessfully shredded directory, Running second pass encryption..."
    python betterhiddencrypto.py enc "$passphrase" "$encrypted_volume_name" "$encrypted_archive_name"

    echo -e "\tSuccessfully encrypted, Shredding Archive..."
    srm -rz "$encrypted_volume_name"

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

    echo -e "\tDecrypting first pass..."
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
