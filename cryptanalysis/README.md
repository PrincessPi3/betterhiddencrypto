# crypto tests prose
1. hunt hard af for leaks of any data
   1. run an encryption with debug = True
   2. copy all the bytes output
   3. power off
   4. mount disk as ro elsewhere
   5. use ugrep to search the whole block device for leaks
      1. edit and run `hammer_for_bytes.sh`
   6. the known cleartext crib is `lap9-Parasail1-Reappoint1-Bright9-Chute6`
   7. do same but with a fuzzy match to test for any unshredded bytes and such
2. check for different checksums of identically encrypted data (done, pass)
3. sanity check algos and settings
4. sanity check that the data is properly encrypted
5. sanity check via brute force attacks
6. test new directory shred function with low level hexdump analysis of the filesystems for any evidence of leaks