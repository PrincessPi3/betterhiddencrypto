#!/bin/bash
# packages: python3, secure-delete, 7z, ugrep, sha512sum

# fail on error
set -e # important to prevent data loss in event of a failure

dir_to_encrypt="./to_encrypt"
encrypted_archive_name="./.volume.bin"
encrypted_volume_name="./.encrypted_volume.7z"
backup_dir="./.volume_old"

environment_check() {
    if ! [ -d "$dir_to_encrypt" ]; then
        echo "$dir_to_encrypt Not Found, Creating..."
        mkdir "$dir_to_encrypt" 
	fi

    if ! [ -d "$backup_dir" ]; then
		echo "$backup_dir Not Found, Creating..."
		mkdir "$backup_dir"
	fi

    if [ -f *.7z ]; then
        echo "WARNING! DANGLING UNENCRYPTED ARCHIVE FOUND"
        ls -A *.7z
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
    timestamp=$(date +"%d%m%Y-%H%M")

    echo "ENCRYPTING Starting..."
    read -s -p "Enter Passphrase: " passphrase1
    read -s -p "Repeat: " passphrase2
    if [ "$passphrase1" != "$passphrase2" ]; then
        echo "Passphrases do not match!"
        exit 1
    else
        passphrase=$passphrase1
    fi

    echo "Compressing Directory..."

    # digest the passphrase to add as a statistically indepentant 7zip passphrase
    digest_passphrase=$(echo "$passphrase" | sha512sum | awk '{print $1}')
    7z a -p"$digest_passphrase" -mhe=on "$encrypted_volume_name" "$dir_to_encrypt"

    echo "Successfully Compressed, Shredding Directory..."
    srm -rz "$dir_to_encrypt"

    echo "Successfully Shredded Directory, Encrypting..."
    python betterhiddencrypto.py enc "$passphrase" "$encrypted_volume_name" "$encrypted_archive_name"

    echo "Successfully Encrypted, Shredding Archive..."
    srm -rz "$encrypted_volume_name"

    echo "Success: Encryption Done"

    if [ -f "$encrypted_archive_name" ]; then
        echo "Backing Up Old Archive"
        cp "./$encrypted_archive_name.bak" "$backup_dir/$encrypted_archive_name.$timestamp"

        echo "Backing Up New Archive"
        cp "$encrypted_archive_name" "$backup_dir/$encrypted_archive_name.bak"
    fi
}

decrypty(){
    echo "DECRYPTION Starting..."
    read -s -p "Enter Passphrase: " passphrase

    # echo "Decrypting. Please Input Passphrase..."
    python betterhiddencrypto.py dec "$passphrase" "$encrypted_archive_name" "$encrypted_volume_name"

    echo "Successfully Decrypted Encrypted Archive, Decompressing..."
    # the statistically independent passphrase for redundant encryption
    digest_passphrase=$(echo "$passphrase" | sha512sum | awk '{print $1}')
    7z x -p"$digest_passphrase" "$encrypted_volume_name"

    echo "Successfully Decrypted, Shredding Encrypted Archive..."
    srm -rz "$encrypted_volume_name"

    echo "Success: Decryption Done"
}

# run at each start
environment_check

if [ "$1" = "encrypt" -o "$1" = "enc" -o "$1" = "e" ]; then
    encrypty
elif [ "$1" = "decrypt" -o "$1" = "dec" -o "$1" = "d" ]; then
    decrypty
else
	echo -e "\nUsage:\t\n\tEncrypt:\n\t\tbash betterhiddencrypto.sh e\n\t\tbash betterhiddencrypto.sh enc\n\t\tbash betterhiddencrypto.sh encrypt\n\tDecrypt:\n\t\tbash betterhiddencrypto.sh d\n\t\tbash betterhiddencrypto.sh dec\n\t\tbash betterhiddencrypto.sh decrypt"
fi
