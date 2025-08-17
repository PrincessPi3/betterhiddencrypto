# crypto tests prose
1. run an encryption with debug = True
   1. copy all the bytes output
   2. power off
   3. mount disk as ro elsewhere
   4. use ugrep to search the whole block device for leaks
      1. edit and run `hammer_for_bytes.sh`
   5. the known cleartext crib is `lap9-Parasail1-Reappoint1-Bright9-Chute6`
2. check for different checksums of identically encrypted data
3. sanity check algos and settings
4. sanity check that the data is properly encrypted
5. sanity check via brute force attacks

### tooling
check checksums recursively of to_encrypt and output to a unique timestamped file
   ``