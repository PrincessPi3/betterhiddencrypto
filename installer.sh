#!/bin/bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install ripgrep openssl git python3 python3-pip 7z openssl -y
sudo apt autoremove -y
pip install -r ./requirements.txt
sudo shutdown -r +2