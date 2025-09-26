#!/bin/bash
# USAGE: source ./environment.sh

# passphrase var export
export passphrase="$(cat ./cryptanalysis/pass_used_in_testing.txt)"

# nuke and reset environment with 60 second sleep
alias test_reset_sleep='echo -e "\nNuking and Resetting... wait 60 seconds...\n"; sleep 60; cd ~; rm -rf ~/betterhiddencrypto/; git clone https://github.com/PrincessPi3/betterhiddencrypto.git ~/betterhiddencrypto 2>/dev/null; cd ~/betterhiddencrypto; cp -r ./cryptanalysis/to_encrypt_testing ./to_encrypt; tree ./to_encrypt; echo; find ./to_encrypt -type f -exec cat {} \; ; echo -e "\npassphrase:"; cat ./cryptanalysis/pass_used_in_testing.txt'

# nuke and reset environment (no sleep)
alias test_reset='echo -e "\nNuking and Resetting...\n"; cd ~; rm -rf ~/betterhiddencrypto/; git clone https://github.com/PrincessPi3/betterhiddencrypto.git ~/betterhiddencrypto 2>/dev/null; cd ~/betterhiddencrypto; cp -r ./cryptanalysis/to_encrypt_testing ./to_encrypt; tree ./to_encrypt; echo; find ./to_encrypt -type f -exec cat {} \; ; echo -e "\npassphrase:"; cat ./cryptanalysis/pass_used_in_testing.txt'

# update path cryptanalysis scripts
export PATH="$PATH:$PWD/cryptanalysis"