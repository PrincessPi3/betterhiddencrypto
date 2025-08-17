# crypto tests prose
1. hunt hard af for leaks of any data
   1. run an encryption with debug = True
   2. copy all the bytes output
   3. power off
   4. mount disk as ro elsewhere
   5. use ugrep to search the whole block device for leaks
      1. edit and run `hammer_for_bytes.sh`
   6. the known cleartext crib is `lap9-Parasail1-Reappoint1-Bright9-Chute6`
1. check for different checksums of identically encrypted data (done, pass)
2. sanity check algos and settings
3. sanity check that the data is properly encrypted
4. sanity check via brute force attacks