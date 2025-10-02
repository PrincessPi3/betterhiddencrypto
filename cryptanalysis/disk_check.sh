#!/bin/bash
set -e
echo "mounting disk"
sudo mount -o uid=1000,gid=1002,umask=0022 /dev/sda1 /mnt/media/
echo "downloading code:"
git clone https://github.com/PrincessPi3/betterhiddencrypto.git /tmp/betterhiddencrypto
echo "moving code around"
mv /tmp/betterhiddencrypto/cryptanalysis/to_encrypt_testing /tmp/to_encrypt
echo "cleaning up code"
rm -rf /tmp/betterhiddencrypto/.git
rm -rf /tmp/betterhiddencrypto/cryptanalysis
echo "puttan da code on da disk"
cp -r /tmp/betterhiddencrypto /mnt/media
cd /mnt/media/betterhiddencrypto
echo "encryption 1/5"
echo "pass: testtextpassword0000OO!!111111111"
bash betterhiddencrypto.sh
echo "decryption 2/5"
echo "pass: testtextpassword0000OO!!111111111"
bash betterhiddencrypto.sh
echo "encryption 3/5"
echo "pass: testtextpassword0000OO!!111111111"
bash betterhiddencrypto.sh
echo "decryption 4/5"
echo "pass: testtextpassword0000OO!!111111111"
bash betterhiddencrypto.sh
echo "encryption 5/5"
echo "pass: testtextpassword0000OO!!111111111"
bash betterhiddencrypto.sh
echo "unmounting disk"
cd /home/princesspi
sudo umount /mnt/media
echo "makin a copy of the whole disk"
sudo dd if=/dev/sda of=/home/princesspi/DELETEMEDISKIMAGE.bin status=progress
echo "makin a sha256 checksum"
sha256sum /home/princesspi/DELETEMEDISKIMAGE.bin | tee -a /home/princesspi/teehee.dat 
echo "runnan da search"
rg -oUabIN -e '\x30\xf5\xfe\x7a\x95\x02\xd2\x86\xf8\x19\x5f\xb5\xae\x52\x34\xfd\x16\x6c\xc5\x4d\xbc\x5d\xdc\xa6\xbe\x2b\x8a\xcc\x77\x00\xf7\xdd' -e 'testtext' -e '44a2aa9151a65f2a590187d74bc98c47024e0da30b5e6d9cd5f75b1904c55788195297d764011ce6d820d38ce29b8d84b90a9a1a9a81bdac9088f0214c6e1275' -e 'testtextpassword0000OO!!111111111' -e '\xde\xad\xbe\xef' /home/princesspi/DELETEMEDISKIMAGE.bin | tee -a /home/princesspi/teehee.dat
echo "DONE :3"
