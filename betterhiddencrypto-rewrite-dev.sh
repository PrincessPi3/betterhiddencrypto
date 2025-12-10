#!/bin/bash
# fail on error
set -e # important to prevent data loss in event of a failure

# debug settings
DEBUG=0 # 0 = no debug, 1 = console debug, 2 = log file+console debug
debug_log_file="$PWD/$(date +%s)_debug_log.txt" # log file for debug mode

# crypto settings
## sHARED SETTINGs
paraellism_int=4 # number of cores to allow used to compute the key, making it run faster without a direct security tradeoff. default=1
salt_shared_length_int=32 # in 8-bit bytes (32 bytes = 256 bits)
## AES and AES layer KDF settings    
aes_time_cost_int=64 # numbrt iterations to use aka time cost -t default=3
aes_memory_cost_int=17 # memory cost in 2^n KiB. At 16, memory cost is 65536 KiB ~67mb. 17 is 131072 KiB ~134Mb default=12 (4096 KiB ~4Mb)
aes_iv_length_int=12 # bytes (12 bytes = 96 bits and is the usual length for aes gcm)
appended_aes_gcm_tag_length=16 # todo: figure dis out
## 7z and 7z layer KDFsettings a bit different for fun :3
7z_hash_len_int=64 # bytes length of output hash aka -l makin it 512 bits here basically for da lulz default=32 
7z_time_cost_int=62
7z_memory_cost_int=16 # ~67MB

# commands needed
required_cmds_arr=(7z openssl argon2 xxd cracklib-check rg shred mktemp sha512sum)
packages_debian=(7zip openssl argon2 xxd cracklib-runtime ripgrep coreutils coreutils coreutils)
# todo: figure out the yumfags
# packages_fedora=()
# todo: figure out te pacmanfags
# packages_arch=()

# shred settings
max_length_dir_name_shred_int=64 # max length for renaming dirs during shred
shred_iterations_int=2 # number of iterations to do shredding files and dir names

# arg friendly names
provided_mode_str="$1"
provided_encrypted_bin_file_path_str="$2"

# tmp files
## mktemp --dry-run just generates the filenames in /tmp to be created later as needd
## globals so dey can be tested for and shredded as need be
bin_archive_file_tmp="$(mktemp --dry-run)"
7z_archive_file_tmp="$(mktemp --dry-run)"
to_encrypt_dir_tmp="$(mktemp --dry-run)" # --directory not passed as not needed here

# gloBALS (empty at start)
## aes/argon2id globals
appended_aes_gcm_tag_hex_str=""
appended_aes_iv_hex_str=""
appended_aes_salt_hex_str=""
aes_key_derived_hex_str=""
## 7z/argon2id globals
appended_7z_salt_hex_str=""
7z_derived_passphrase_str=""
# shared globals
passphrase_checked_str=""

# todo:
# betterhiddencrypto_decrypt ()
# betterhiddencrypto_encrypt ()
# cleanup () # test for and shred temp files, shred and unset vars
# NUKE_REKT ()
# environment_check ()
# get_real_user ()
# fix_file_perms (chmod: dirs to 700 files to 600 chown to $real_user:$real_user)

# switchan to shred and find because secure-delete is old af
# also shred gives much ore opttions better for ssds and also lets me zero the files out before they remov
shred_dir () {
    if [ -d "$1" ]; then # if its a dir
        debug_echo "Shredding and deleting directory: $1 with $shred_iterations iterations"

        # next phase is to shred all files in the dir
        find "$1" -type f -exec shred --zero --remove --force --iterations=$shred_iterations_int "{}" \;

        # randomly rename all da dirrrrs and fuiels
        # todo: depth first order to prevent errorzzz
        for ((i=0; i<$shred_iterations_int; i++)); do
            find "$1" -type d -exec mv "{}" "$(openssl rand -hex $max_length_dir_name_shred_int)" \;
            find "$1" -type f -exec mv "{}" "$(openssl rand -hex $max_length_dir_name_shred_int)" \;
        done

        # then nuke the all empty dirs
        rm -rf "$1"
    elif [ -f "$1" ]; then # if its a file        
        # three iterations plus a zeroing and deletion
        debug_echo "Shredding and deleting file: $1 with $shred_iterations_int iterations"
        shred --zero --remove --force --iterations=$shred_iterations_int "$1" # 1>/dev/null 2>/dev/null
    else # fail
        echo "FAIL: Directory or file not found: $1 EXITING"
        exit 1 # explicitly fail
    fi
}

aes_derive_keys_passphrase_from_file () {
    # get the salt and iv
    appended_aes_salt_hex_str=$(retreive_chop_appended_data_from_file $salt_shared_length_int "$provided_encrypted_bin_file_path_str")
    appended_aes_iv_hex_str=$(retreive_chop_appended_data_from_file $aes_iv_length_int "$provided_encrypted_bin_file_path_str")
    appended_aes_gcm_tag_hex_str=$(retreive_chop_appended_data_from_file $appended_aes_gcm_tag_length "$provided_encrypted_bin_file_path_str")

    # generate the 256 bit key as hex string save aS global
    aes_key_derived_hex_str=$(echo -n "$passphrase_checked_str" | argon2 "$(echo -n \"$appended_aes_salt_hex_str\" | xxd -d -p)" -id -r -l 32 -t $aes_time_cost_int -m $aes_memory_cost_int -p $paraellism_int)
}

generate_salts_and_iv () {
    # these outpoot as globalz :pidreaming:
    appended_7z_salt_hex_str=$(openssl rand -hex $salt_shared_length_int)
    appended_aes_salt_hex_str=$(openssl rand -hex $salt_shared_length_int)
    appended_aes_iv_hex_str=$(openssl rand -hex $aes_iv_length_int)
}

aes_derive_keys_new () {
    # generater new random data and derive passphrase, savin shit as globals
    generate_salts_and_iv
    aes_key_derived_hex_str=$(echo -n "$passphrase_checked_str" | argon2 "$(echo -n \"$appended_aes_salt_hex_str\" | xxd -d -p)" -id -r -l 32 -t $aes_time_cost_int -m $aes_memory_cost_int -p $paraellism_int)
}

# handle debuggan modes
# usage:
#   debug_echo <string message to show and/or log when in debug mode
debug_echo () {
    if [ $DEBUG -eq 1 ]; then
        echo -e "$1"
    elif [ $DEBUG -eq 2 ]; then
        echo -e "$1" | tee -a "$debug_log_file"
    else
        return 0 # do nothing
    fi
}

# usage:
#   directly:
#       check_requirements ls cd mv cp
#   with variable:
#       required_cmds=(ls cd mv cp)
#       check_requirements "${required_cmds[@]}"
check_requirements () {
    local missing=() # make da empty arr

    # Loop over all arguments (each should be a command name)
    for cmd in "$@"; do # "$@" ish da aray of all arguments
        if ! command -v "$cmd" >/dev/null 2>&1; then # fail silently if not found
            missing+=("$cmd") # append missing to missing arr
        fi
    done

    if (( ${#missing[@]} > 0 )); then # if missing arr not empty
        echo "The following required commands are missing:"
        for m in "${missing[@]}"; do # loop through missing
            echo "  - $m" # eho the missing ones
        end
        exit 1 # explicitly fail
    fi

    return 0
}

# add the hex str data $1 to a file $2
append_data_to_file () {
    local hex_str="$1"
    local file_path="$PWD/$(basename $2)"

    if [ -z "$hex_str" ]; then
        echo "append_data_to_file FAIL: arguement 1 (hex string) not providedd!"
        exit 1
    fi

    if [ -z "$2" ]; then
        echo "append_data_to_file FAIL: arguement 2 (file) not providedd!"
        exit 1
    fi

    if [ ! -f "$file_path" ]; then
        echo "append_data_to_file FAIL: $file_path is not a file!"
        exit 1
    fi

    printf "$hex_str" >> "$file_path"
}

# retreive_chop_appended_data_from_file <int num of hex bytes in hex string> <str file path>
retreive_chop_appended_data_from_file () {
    local data_length=$1 # bytes
    local file_path="$PWD/$(basename $2)" # absolute path
    local hex_data_length=$((2 * $data_length)) # double the bytes for hex str

    if [ -z "$data_length" ]; then
        echo "append_data_to_file FAIL: arguement 1 (int data length) not providedd!"
        exit 1
    fi

    if [ -z "$2" ]; then
        echo "append_data_to_file FAIL: arguement 2 (str file path) not providedd!"
        exit 1
    fi

    if [ ! -f "$file_path" ]; then
        echo "append_data_to_file FAIL: $file_path is not a file!"
        exit 1
    fi

    # echo the hex str from b ottom of file to $hex_data_length bytes fron $file_path
    tail -c $hex_data_length "$file_path"

    # remove $hex_data_length from bottom of $file_path
    truncate -s -$hex_data_length "$file_path"
}

# nuke mode, explicitly NUKE case sensitive
if [[ "$provided_mode_str" == "NUKE" ]]; then
    NUKE_REKT
    exit 0
fi

# decrypt mode
## if $1 starts with d/D case insensitive
if [[ "$provided_mode_str" =~ ^[dD] ]]; then
    betterhiddencrypto_decrypt
# encrypt mode
## if $1 starts with e/E case insensitive
elif [[ "$provided_mode_str" =~ ^[eE] ]]; then
    betterhiddencrypto_encrypt
# new volume
## if $1 starts with N/n case insensitive
elif [[ "$provided_mode_str" =~ ^[nN] ]]; then
    # get absolute path of $2
    bin_encrypted_archive_file_safe="$PWD/$(basename $2)"

    # make sure the second arg is there
    if [ -z "$provided_encrypted_bin_file_path_str" ]; then
        echo "FAIL no second argument"
        exit 1
    fi

    # ccheck if file exists
    if [ -f "$bin_encrypted_archive_file_safe" ]; then
        bin_encrypted_archive_file_safe="$bin_encrypted_archive_file_safe"
        betterhiddencrypto_decrypt
    fi

    # make the temp dir path
    to_encrypt_dir_tmp=$(mktmp --directory --dry-run)
    ## actually create the temp dir
    mkdir "$to_encrypt_dir_tmp"

    echo "$to_encrypt_dir_tmp"
    betterhiddencrypto_encrypt
else
    # DEFAULT mode aand bin
    # todo: search $PWD for .bins error if none
fi