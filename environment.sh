#!/bin/bash
# USAGE: source ./environment.sh

# passphrase var export
export test_passphrase="$(cat ./cryptanalysis/pass_used_in_testing.txt)"

# passphrase var
alias test_passphrase="echo $test_passphrase"

# nuke and reset environment with 60 second sleep
alias test_reset_sleep='echo -e "\nNuking and Resetting... wait 60 seconds...\n"; sleep 60; cd ~; rm -rf ~/betterhiddencrypto/; git clone https://github.com/PrincessPi3/betterhiddencrypto.git ~/betterhiddencrypto 2>/dev/null; cd ~/betterhiddencrypto; cp -r ./cryptanalysis/to_encrypt_testing ./to_encrypt; tree ./to_encrypt; echo; find ./to_encrypt -type f -exec cat {} \; ; echo -e "\npassphrase:"; cat ./cryptanalysis/pass_used_in_testing.txt; rm -rf /tmp/to_encrypt; source ./environment.sh'

# nuke and reset environment (no sleep)
alias test_reset='echo -e "\nNuking and Resetting...\n"; cd ~; rm -rf ~/betterhiddencrypto/; git clone https://github.com/PrincessPi3/betterhiddencrypto.git ~/betterhiddencrypto 2>/dev/null; cd ~/betterhiddencrypto; cp -r ./cryptanalysis/to_encrypt_testing /tmp/to_encrypt; tree /tmp/to_encrypt; echo; find /tmp/to_encrypt -type f -exec cat {} \; ; echo -e "\npassphrase:"; cat ./cryptanalysis/pass_used_in_testing.txt; rm -rf /tmp/to_encrypt; source ./environment.sh'

# sanity check to_encrypt dir
alias test_sanity='echo -e "\nChecking to_encrypt directory...\n"; tree /tmp/to_encrypt; echo -e "\npassphrase:"; find /tmp/to_encrypt -type f -exec cat {} \; ; cat ./cryptanalysis/pass_used_in_testing.txt;'

# update path cryptanalysis scripts
export PATH="$PATH:$PWD/cryptanalysis"