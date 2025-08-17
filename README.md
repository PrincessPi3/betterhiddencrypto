# betterhiddencrypto
(better) Silly lil script for using [Argon2id](https://en.wikipedia.org/wiki/Argon2), [secure-delete  (srm)](https://github.com/BlackArch/secure-delete), AES265-GCM and 7zip to redundantly and securely open and close an encrypted and compressed directory (7z) and shred (srm) any lingering data immediately following checks.

## Textwall about the frickin thing
Encryption MY way!
I was totally fucked off by the normie file encryption utilities like Veracrypt,. Cryptomator and openssl because in practice they have a couple absolutely glaring flaws.  
  
For one, they are STILL using PMDKF2 as the KDF (Key Derivation Function, the algo that deterministically generates the 256-bit key from a passphrase) and the simple truth is that PBDKF2 is criminally outdated and no ever increasing number of iterations into the millions and millions are ever gonna change that.  
So, I selected the gigachad KDF, [Argon2id](https://en.wikipedia.org/wiki/Argon2) to generate the 256-bit key. It features appx. With variable cost settings for time, memory, parralellization, and with an added cryptographically securely randomly generated salt, it makes a very robust and attack resistant KDF.
  
AES with 256bit key in GCM mode is used. GCM mode includes authtentication which is nice, and is considered one of the most secure AES modes.

The compression and redundant encryption is via 7zip. The script generates a sha512 hash of the passphrase to make sure the passphrase for the 7z archive is statistically independant from the one used in the main encryption.

The other glaring issue that the normie cryptography utilities had was the fact that when files are moved to the volume, there is no shredding of the "ghost" file at the location it camer from, and in some cases, even left data traes on the disk without securely shredding them to clean up.  
To that end, I'm using the secure-delete package to secure wipe any temporary or ghost bytes off the record.  
srm is used to delete files and directories immediately upon compl,eting the next step successfully.  
smem is used to wipe unallocated RAM to ensure that no remaning traces of data are left in memory even with a sophisticated memory forensics or cold boot attack.   

## Back Up Your Shit
* This script is probably as unstable as I am and will probably end up nuking your files
* If you lose your passphrase or type it in wrong twice on encryption, your data has gone bye bye
* For real, back up your shit
* Do not trust me or my code

## Important Details
* Each time you encrypt the directory, it will use a brand new passphrase that you input. You can still use the old one, but it is set each time to whatever you enter twice regardless of the previous passphrase
* Use a [secure passphrase](assets/how-to-create-a-secure-passphrase-2017-08-10_HQP.pdf) and DO NOT SAVE ON COMPUTER OR PASSSWORD MANAGER! Only save your passphrase on **PHYSICAL PAPER**
* **Back Up Your Shit!** This is a completely unforgiving script when it comes to setting the password wrong
* When creating encrypted backups, be certain to use a seperate, completely dissimilar passphrase for it. Store this passphrase on a seperate piece of paper, stored seperately
* **Test Your Backups** Make completely sure they work and that you a precise and accurate passphrase for them
* If your system has automatic backuops, RAID, cloud storage uplaods, or any other type of redundancy system in place, you should exclude the hiddebncrypto directory from it. Otherwise, partial or even data leaking data could be copied or even uploaded
* **BE AWARE** When moving files from unencrypted drives to the encrypted arcive, **the original files may be recoverable from the original location** even if they are not visible. It is a best practice to shred empty space on that disk afterwords to ensure the orignal data is not forensically recoverable
* Best practice is to disable networking when using hiddencrypto

## Installation
Prerequisites:
```
sudo apt update
sudo apt install 7z git secure-delete python3 ugrep
```

Installation:
```
cd ~
git clone https://github.com/PrincessPi3/betterhiddencrypto.git
cd hiddencrypto
pip install -r requirements.txt
```

## Usage
1. Files to be encrypted are placed in [to_encrypt](./to_encrypt/README.md)
2. [to_encrypt](./to_encrypt/README.md) will be shredded and gone byebye after each encryption and restored after each decryption
3. Each time an encryption is run, it outputs `./.volume.bin` and backs up any existing `./.volume.bin` to `./.volume.bin.bak` if `./volume.bin.bak` is found it is backed up to [./volume_old](./.volume_old/README.md)

Smart encrypt or decrypt  
`bash hiddencrypto.sh`  

Help:  
`bash hiddencrypto.sh h` or  
`bash hiddencrypto.sh help`  

Encrypt explicitly:  
`bash hiddencrypto.sh e`  or  
`bash hiddencrypto.sh enc`  or  
`bash betterhiddencrypto.sh encrypt`  
  
Decrypt explicitly:  
`bash hiddencrypto.sh d`  or  
`bash hiddencrypto.sh dec`  or  
`bash hiddencrypto.sh decrypt`

## License
Distributed under the [WTFPL Version 2](http://www.wtfpl.net/) [![WTFPL](assets/wtfpl-badge.png)](http://www.wtfpl.net/)  
See [assets/COPYING.txt](assets/COPYING.txt) for text  
