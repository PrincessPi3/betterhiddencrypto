#!/bin/bash
# USAGE: source ./environment.sh
to_encrypt_dir="/tmp/to_encrypt" # only in memory fs for security
passphrase_file="./cryptanalysis/pass_used_in_testing.txt" # file containing passphrase for testing
passphrase="$(cat $passphrase_file)" # passphrase for testing

# passphrase var export
export test_passphrase="$passphrase"

# passphrase alias
alias test_passphrase="echo $passphrase"

# nuke and reset environment with 60 second sleep
alias test_reset_sleep="echo -e '\nNuking and Resetting... wait 60 seconds...\n'; sleep 60; cd ~; rm -rf ~/betterhiddencrypto/; git clone https://github.com/PrincessPi3/betterhiddencrypto.git ~/betterhiddencrypto 2>/dev/null; cd ~/betterhiddencrypto; cp -r ./cryptanalysis/to_encrypt_testing $to_encrypt_dir; tree $to_encrypt_dir; echo; find $to_encrypt_dir -type f -exec cat {} \; ; echo -e '\npassphrase:'; cat ./cryptanalysis/pass_used_in_testing.txt; source ./environment.sh'"

# nuke and reset environment (no sleep)
alias test_reset="echo -e '\nNuking and Resetting...\n'; cd ~; rm -rf ~/betterhiddencrypto/; git clone https://github.com/PrincessPi3/betterhiddencrypto.git ~/betterhiddencrypto 2>/dev/null; cd ~/betterhiddencrypto; cp -r ./cryptanalysis/to_encrypt_testing $to_encrypt_dir; tree $to_encrypt_dir; echo; find $to_encrypt_dir -type f -exec cat {} \; ; echo -e '\npassphrase:'; cat ./cryptanalysis/pass_used_in_testing.txt; source ./environment.sh'"

# sanity check to_encrypt dir
alias test_sanity="echo -e '\nChecking $to_encrypt_dir directory...\n'; tree $to_encrypt_dir; echo -e '\npassphrase:'; find $to_encrypt_dir -type f -exec cat {} \; ; cat ./cryptanalysis/pass_used_in_testing.txt;"

# update path cryptanalysis scripts
export PATH="$PATH:$PWD/cryptanalysis"