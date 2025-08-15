#!/bin/bash
# packages: python3, secure-delete

# fail on error
set -e

dir_to_encrypt=./to_encrypt
encrypted_archive_name=./.volume.bin
encrypted_volume_name=./.encrypted_volume.tar.bz2

encrypty(){
    timestamp=$(date +"%d%m%Y-%H%M")

    echo "Starting..."
    read -s -p "Enter Passphrase: " passphrase1
    read -s -p "Repeat: " passphrase2
    if [ "$passphrase1" != "$passphrase2" ]; then
        echo "Passphrases do not match!"
        exit 1
    else
        passphrase=$passphrase1
    fi

    echo "Compressing Directory..."
    tar cfj $encrypted_volume_name $dir_to_encrypt

    echo "Successfully Compressed, Shredding Directory..."
    srm -rz $dir_to_encrypt

    echo "Successfully Shredded Directory, Encrypting. Please Input Passphrase..."
    python betterhiddencrypto.py enc $passphrase $encrypted_volume_name $encrypted_archive_name

    echo "Successfully Encrypted, Shredding Archive..."
    srm -rz $encrypted_volume_name

    echo "Success: Encryption Done"
    
    echo "Backing Up Old Archive"
    cp ./.volume.bin.bak ./.volume_old/.volume.bin.bak.$timestamp

    echo "Backing Up New Archive"
    cp ./.volume.bin ./.volume.bin.bak
}

decrypty(){
    echo "Starting..."
    read -s -p "Enter Passphrase: " passphrase

    echo "Decrypting. Please Input Passphrase..."
    python betterhiddencrypto.py dec $passphrase $encrypted_archive_name $encrypted_volume_name

    echo "Successfully Decrypted Encrypted Archive, Decompressing..."
    tar xfj $encrypted_volume_name

    echo "Successfully Decrypted, Shredding Encrypted Archive..."
    srm -rz $encrypted_volume_name

    echo "Success: Done"
}

if [ "$1" = "encrypt" -o "$1" = "enc" -o "$1" = "e" ]; then
    encrypty
elif [ "$1" = "decrypt" -o "$1" = "dec" -o "$1" = "d" ]; then
    decrypty
elif [ "$1" = "install" -o "$1" = "i" ]; then
	if ! [ -f "$(command -v git)" ] && [ -f "$(command -v tar)" ] && [ -f "$(command -v make)" ]; then
        	echo "Needed Applications Not Found, Installing..."
            sudo apt update
	        sudo apt install git secure-delete tar build-essential -y
            pip install -r requirements.txt
	        echo "Success: Installed"
	fi

    if ! [ -f "./.secure-delete/smem" ]; then
        echo "Building Edited secure-delete Utilities..."
        cd ./.secure-delete
        sudo make

        echo "Installing Edited secure-delete Utiliies..."
        sudo make install
        
        echo "Cleaning Up From Build..."
        cd ..
        sudo srm -rz ./.secure-delete

        echo "Success: secure-delete Installed"
    fi

	if ! [ -d $dir_to_encrypt ]; then
		echo "$dir_to_encrypt Not Found, Creating..."
		mkdir $dir_to_encrypt
	fi

	echo "Success: Ready to use"
else
	echo -e "\nUsage:\t\n\tEncrypt:\n\t\tbash betterhiddencrypto.sh e\n\t\tbash betterhiddencrypto.sh enc\n\t\tbash betterhiddencrypto.sh encrypt\n\tDecrypt:\n\t\tbash betterhiddencrypto.sh d\n\t\tbash betterhiddencrypto.sh dec\n\tbash betterhiddencrypto.sh decrypt\n\tInstall:\n\t\tbash betterhiddencrypto.sh i\n\t\tbash betterhiddencrypto.sh install"
fi
