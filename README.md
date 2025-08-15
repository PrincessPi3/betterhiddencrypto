# hiddencrypto
Silly lil script for using [scrypt](https://github.com/Tarsnap/scrypt), [secure-delete  (srm)](https://github.com/BlackArch/secure-delete), and tar to open and close an encrypted (scrypt) and compressed (bz2) and shred (srm) any lingering data immediately.

## Textwall about the frickin thing
Encryption MY way!
I was totally fucked off by the normie file encryption utilities like Veracrypt,. Cryptomator and `openssl enc` because in practice they have a couple absolutely glaring flaws.  
  
For one, they are STILL using PMDKF2 as the KDF (Key Derivation Function, the algo that deterministically generates the 256-bit key from a passphrase) and the simple truth is that PBDKF2 is criminally outdated and no ever increasing number of iterations into the millions and millions are ever gonna change that.  
So, I selected the gigachad KDF, Scrypt to generate the 256-bit key. It features appx. 10 billion times the hardware cost to crack vs `openssl enc` it has appx. 20,000 times greater hardware cost to crack vs PBDK2 with any number of iterations, and appx. 4,000 times the hardware cost to crack vs Bcrypt, the algo used to hash Linux passwords.  
Scrypt is stable and solid, and has passed countless rounds of cryptanalysis and revision by Cypherpunks and the wider cryptography community, so it should be quite cryptographically secure.  
  
The other glaring issue that the normie cryptography utilities had was the fact that when files are moved to the volume, there is no shredding of the "ghost" file at the location it camer from, and in some cases, even left data traes on the disk without securely shredding them to clean up.  
To that end, I'm using the secure-delete package to secure wipe any temporary or ghost bytes off the record.  
srm is used to delete files and directories immediately upon compl,eting the next step successfully.  
smem is used to wipe unallocated RAM to ensure that no remaning traces of data are left in memory even with a sophisticated memory forensics or cold boot attack.   
//todo: There will also have an option to wide empty space on a given disk for convenience.  
//todo: A feature that shreds the first 1024 bytes of the encrypted archive so that the data is completely nuked and unrecoverable even with the passphrase. The feature should be easily integrated into other systems such that a nuke order can be executed from any custom event or trigger e.g. Alexa command, key combination on another comptuer, time based dead man's switch, etc.

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

## Usage
To install:  
```
cd ~
git clone https://github.com/PrincessPi3/hiddencrypto.git
cd hiddencrypto
sudo sh hiddencrypto.sh install
```
  
To encrypt:  
`sh hiddencrypto.sh enc`  
  
To decrypt:  
`sh hiddencrypto.sh dec`  

## License
Distributed under the [WTFPL Version 2](http://www.wtfpl.net/) [![WTFPL](assets/wtfpl-badge.png)](http://www.wtfpl.net/)  
See [assets/COPYING.txt](assets/COPYING.txt) for text  
  
  
```
Todo:

Potential memory key leaks
Potential OS key leaks
Potential side-channel attacks
```