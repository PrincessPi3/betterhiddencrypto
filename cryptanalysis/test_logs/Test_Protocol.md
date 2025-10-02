# Test Protocol
## Linux Install
1. zero out a drive `sudo dd if=/dev/zero of=/dev/sdX status=progress`
2. install linux to it
3. boot into it
4. install betterhiddencrypto
5. enable debug moed
6. run it with test case and test password a few times
7. shut down
8. boot another linux box
9. in that one, attach the drive
10. hammer it for bytes `sudo rg -aobUuuu -e 'testtext' -e '<256bit key in hex bytes>' /dev/sdX`