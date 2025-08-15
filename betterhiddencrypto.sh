#!/bin/sh
# packages: scrypt, secure-delete

# fail on error
set -e

dir_to_encrypt=./to_encrypt
encrypted_archive_name=./.volume.bin
encrypted_volume_name=./.encrypted_volume.tar.bz2

encrypty(){
    timestamp=$(date +"%d%m%Y-%H%M")

    echo "Starting..."
    read -s -p "Enter Passphrase: " passphrase1
    read -s -p "Enter Passphrase: " passphrase2
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
    cp ./.volume.bin ./.volume_old/.volume.bin.$timestamp
    cp ./.volume.bin.bak ./.volume_old/.volume.bin.bak.$timestamp

    echo "Backing Up New Archive"
    cp ./.volume.bin ./.volume.bin.bak
}

decrypty(){
    echo "Starting..."
    read -s -p "Enter Passphrase: " passphrase

    echo "Decrypting. Please Input Passphrase..."
    python betterhiddencrypto.py dec $passphrase $encrypted_archive_name $dir_to_encrypt

    echo "Successfully Decrypted, Shredding Encrypted Archive..."
    srm -rz $encrypted_archive_name

    echo "Successfully Shredded Encrypted Archive, Decompressing..."
    tar xfj $encrypted_volume_name

    echo "Successfully Decompressed Decrypted Archive, Shredding Decrypted Archive..."
    srm -rz $encrypted_volume_name

    echo "Success: Done"
}

if [ "$1" = "enc" ]; then
    encrypty
elif [ "$1" = "dec" ]; then
    decrypty
elif [ $1 = "install" ]; then 
	if ! [ -f "$(command -v scrypt)" ] &&  [ -f "$(command -v tar)" ] && [ -f "$(command -v make)" ]; then
        	echo "Needed Applications Not Found, Installing..."
	        sudo apt install scrypt secure-delete tar build-essential
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
	echo "Usage:\nEncrypt:\n\tsh hiddencrypto.sh enc\nDecrypt:\n\tsh hiddencrypto.sh dec\nInstall:\n\tsh hiddencrypto.sh install"
fi
