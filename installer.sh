#!/bin/bash
echo -e "\nupdatin repos\n"
sudo apt update

echo -e "\ndoin a full upgrade\n"
sudo apt full-upgrade -y

echo -e "\ninstallan needed tools\n"
sudo apt install ripgrep openssl git python3 python3-pip 7z openssl -y

echo -e "\ncleaning up apt\n"
sudo apt autoremove -y

echo "cloning betterhiddencrypto to $HOME/betterhiddencrypto"
cd $HOME
git clone https://github.com/PrincessPi3/betterhiddencrypto.git
cd ~/betterhiddencrypto 

echo "installin python requirements"
pip install -r ./requirements.txt

echo "shuddan down in 2 mins lol"
sudo shutdown -r +2