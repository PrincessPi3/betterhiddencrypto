#!/bin/bash
# curl -s https://raw.githubusercontent.com/PrincessPi3/betterhiddencrypto/refs/heads/main/installer.sh | "$SHELL"

set -e

echo -e "\nupdatin repos\n"
sudo apt update

echo -e "\ndoin a full upgrade\n"
sudo apt full-upgrade -y

echo -e "\ninstallan needed tools\n"
sudo apt install ripgrep openssl git python3 python3-pip xxd 7zip argon2 -y

echo "cloning betterhiddencrypto to $HOME/betterhiddencrypto"
git clone https://github.com/PrincessPi3/betterhiddencrypto.git $HOME/betterhiddencrypto 
cd $HOME/betterhiddencrypto 

echo "installin python requirements"
pip install -r ./requirements.txt

echo -e "\ncleaning up apt\n"
sudo apt autoremove -y

echo "shuddan down in 1 min lol"
sudo shutdown -r +1