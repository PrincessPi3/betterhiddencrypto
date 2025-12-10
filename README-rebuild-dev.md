# betterhiddencrypto
(better) Silly lil commandline linux tool for encrypting the absolute fuck out of some shit. Using [Argon2id](https://en.wikipedia.org/wiki/Argon2), [AES-265-GCM](https://medium.com/@pravallikayakkala123/understanding-aes-encryption-and-aes-gcm-mode-an-in-depth-exploration-using-java-e03be85a3faa), [7-Zip compression and encryption](https://www.7-zip.org/7z.html), and [shred](https://linux.die.net/man/1/shred) (coreutils) to redundantly and securely open and close an encrypted and compressed directory (7z), [OpenSSL](https://www.openssl.org), and shred any lingering data immediately following checks for robust antiforensics.

## Textwall about the frickin thing
Encryption MY way!
I was totally fucked off by the normie file encryption utilities like Veracrypt,. Cryptomator and openssl because in practice they have a couple absolutely glaring flaws.  
  
For one, they are STILL using PMDKF2 as the KDF (Key Derivation Function, the algo that deterministically generates the 256-bit key from a passphrase) and the simple truth is that PBDKF2 is criminally outdated and no ever increasing number of iterations into the millions and millions are ever gonna change that.  
So, I selected the gigachad KDF, [Argon2id](https://en.wikipedia.org/wiki/Argon2) to generate the 256-bit key. It features appx. With variable cost settings for time, memory, parralellization, and with dual independant cryptographically securely randomly generated salts appended and prepended to the volume, it makes a very robust and attack resistant KDF.
  
AES with 256-bit key in GCM mode is used. GCM mode includes authtentication which is nice, and is considered one of the most secure AES modes.

The compression and redundant encryption is via 7zip. The script generates a sha512 hash of the passphrase to make sure the passphrase for the 7z archive is statistically independant from the one used in the main encryption.  
The passphrase for the inner 7z archive is digested from the same passphrase by iterating the passphrase+one salt through sha512 125 times.  

The other glaring issue that the normie cryptography utilities had was the fact that when files are moved to the volume, there is no shredding of the "ghost" file at the location it camer from, and in some cases, even left data traes on the disk without securely shredding them to clean up.  
To that end, I'm using the secure-delete package to secure wipe any temporary or ghost bytes off the record.  
srm is used to delete files and directories immediately upon compl,eting the next step successfully.  
smem is used to wipe unallocated RAM to ensure that no remaning traces of data are left in memory even with a sophisticated memory forensics or cold boot attack.   

### Volume file format
#### Outer Layer (AES-256-GCM)
| Segment | Length (bytes) |
|:---|---:|
| Salt       | 16             |
| IV         | 16             |
| GCM Tag    | 16             |
| Ciphertext | * (remaining)  |
#### Inner Layer (7zip encryption)
| Segment | Length (bytes) |
|:---|---:|
| Encrypted 7zip Archive | * (remaining)  |
| Salt                   | 16             |

Argon2id Salt: 16 bytes
Initilialization Vector (IV): 16 bytes

## Antiforensics
1. All unneeded data is robustly shredded immediately upon confirming that it is no longer needed.
2. Extremely fast, most-sensitive-first nuke mode to destory all of the data in this dir, including encrypted volumes, their backups, any dangling unencrypted data, followd by optional immediate shutdown.
3. Intense amateur antiforensics/cryptographic testing and iterative improvement going on over in [cryptanalysis/](./cryptanalysis/README.md)
4. Custom directory file name shredding function in addition to shredding files
5. All cleartext and temp files handled in ramdisk automatically

## Back Up Your Shit
* This script is probably as unstable as I am and will probably end up nuking your files
* If you lose your passphrase or type it in wrong twice on encryption, your data has gone bye bye
* For real, back up your shit
* Do not trust me or my code

## Important Details
* Each time you encrypt the directory, it will use a brand new passphrase that you input. You can still use the old one, but it is set each time to whatever you enter twice regardless of the previous passphrase
* Use a [secure passphrase](assets/how-to-create-a-secure-passphrase-2017-08-10_HQP.pdf) and DO NOT SAVE ON COMPUTER OR PASSSWORD MANAGER! Only save your passphrase on **PHYSICAL PAPER** another great tip is to have a complex password written on paper, and append to prepend or modify it in some simple way that you can easily remember so that leak of the physical paper wont immediately mean compromise.
* **Back Up Your Shit!** This is a completely unforgiving script when it comes to setting the password wrong
* When creating encrypted backups, be certain to use a seperate, completely dissimilar passphrase for it. Store this passphrase on a seperate piece of paper, stored seperately
* **Test Your Backups** Make completely sure they work and that you a precise and accurate passphrase for them
* If your system has automatic backuops, RAID, cloud storage uplaods, or any other type of redundancy system in place, you should exclude the hiddebncrypto directory from it. Otherwise, partial or even data leaking data could be copied or even uploaded
* **BE AWARE** When moving files from unencrypted drives to the encrypted arcive, **the original files may be recoverable from the original location** even if they are not visible. It is a best practice to shred empty space on that disk afterwords to ensure the orignal data is not forensically recoverable
* Best practice is to disable networking when using hiddencrypto
* **WATCH OUT FOR CLOUD STORAGE** Cloud services and backup services like Microsuck OneDrive automatically backs up any files in the OneDrive folders to the cloud **INCLUDING UNENCRYPTED FILES WHILE THEY ARE IN CLEARTEXT**

## Installation
### Prerequisites
**Made exclusively for linux**
Need these packages installed:
1. bash shell installed
2. 7z
3. git
5. python3
6. python3-pip
7. ugrep 
8. openssl

### Installation
`cd ~`
`git clone https://github.com/PrincessPi3/betterhiddencrypto.git`
`cd hiddencrypto`
`pip install -r requirements.txt`  
Autoinstaller (requires apt): `curl -s https://raw.githubusercontent.com/PrincessPi3/betterhiddencrypto/refs/heads/main/installer.sh | "$SHELL"`

## Usage
1. Files to be encrypted are placed in [to_encrypt](./to_encrypt/README.md)
2. [to_encrypt](./to_encrypt/README.md) will be shredded and gone byebye after each encryption and restored after each decryption
3. Each time an encryption is run, it outputs `./.volume.bin` and backs up any existing `./.volume.bin` to `./.volume.bin.bak` if `./volume.bin.bak` is found it is backed up to [./volume_old](./.volume_old/README.md)

### Passphrase Requirements
20+ characters long with at least one of each lowercase letter, uppercase letter, digit, and special character  

**Smart encrypt or decrypt**  
automatically detects if the to_encrypt dir is present and if so, defaults to encrypt mode otherwise defaults to decrypt mode.  
`bash hiddencrypto.sh`  

**Help**  
Display help test.
(All aliasses are identical)  
`bash hiddencrypto.sh h` OR  
`bash hiddencrypto.sh help`  

**Encrypt explicitly**  
(All aliasses are identical)  
`bash hiddencrypto.sh e`  OR  
`bash hiddencrypto.sh enc`  OR  
`bash betterhiddencrypto.sh encrypt`  
  
**Decrypt explicitly**  
(All aliasses are identical)  
`bash hiddencrypto.sh d`  OR  
`bash hiddencrypto.sh dec`  OR  
`bash hiddencrypto.sh decrypt`

**EMERGENCY NUKE EVERYTHING RIGHT FUCKING NOW (NO RECOVERY POSSIBLE) (WITH SHUTDOWN)**  
Attempts to destroy as much of the data in the betterhiddencrypto dir as possible and shutdown immediately upon completion  
(passwordless sudo, shutdown sticky bit, etc advised to prevent having to enter password to power down)  
1. First shreds 125 bytes from the start of each of the encrypted volume, destroying them
2. Then shreds the to_encrypt dir if present
3. Next shreds any dangling archives or temp files
4. then shreds this entire directory
(All aliasses are identical)
(Arguments referencing reboot are a misnomer, they all only shut down immediately upon completing)  

`bash hiddencrypto.sh nr` OR  
`bash hiddencrypto.sh ns` OR  
`bash hiddencrypto.sh shutdown` OR  
`bash hiddencrypto.sh reboot` OR  
`bash hiddencrypto.sh nukereboot` OR  
`bash hiddencrypto.sh killitwithfire` OR  

**EMERGENCY NUKE EVERYTHING RIGHT FUCKING NOW (NO RECOVERY POSSIBLE) (NO SHUTDOWN)**  
Same as above but does not shut down upon completion  
(All aliasses are identical)  
`bash hiddencrypto.sh nuke` OR  
`bash hiddencrypto.sh emergncy_nuke` OR  
`bash hiddencrypto.sh n` OR  
`bash hiddencrypto.sh wipe` OR  
`bash hiddencrypto.sh shred` OR  
`bash hiddencrypto.sh emergency`

## Cryptanalysis
To test and hammer it for peak robustness, testing is going on in [cryptanalysis](./cryptanalysis/README.md
)

## License
 [![WTFPL](assets/wtfpl-badge-1.png)](http://www.wtfpl.net/)  
Distributed under the [WTFPL Version 2](http://www.wtfpl.net/)  
See [assets/COPYING.txt](assets/COPYING.txt) for text  
