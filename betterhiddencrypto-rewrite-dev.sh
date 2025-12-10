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
provided_encrypted_bin_safe_file_path_str="$2"

# tmp files
## mktemp --dry-run just generates the filenames in /tmp to be created later as needd
## globals so dey can be tested for and shredded as need be
bin_archive_file_tmp="$(mktemp --dry-run)"
7z_archive_file_tmp="$(mktemp --dry-run)"
bin_archive_file_two_tmp="$(mktemp --dry-run)"
aes_gcm_tag_bin_tmp="$(mktemp --dry-run)"
to_encrypt_dir_tmp="$(mktemp --dry-run)" # --directory not passed as not needed here because creatin later

# gloBALS (empty at start)
## aes/argon2id globals
appended_aes_gcm_tag_hex_str=''
appended_aes_iv_hex_str=''
appended_aes_salt_hex_str=''
aes_key_derived_hex_str=''
## 7z/argon2id globals
appended_7z_salt_hex_str=''
7z_derived_passphrase_str=''
## shared globals
passphrase_checked_str=''

# var, temp file, and function name arrays for later cleanup
## arr of global vars
vars_at_play_arr=(appended_7z_salt_hex_str 7z_derived_passphrase_str passphrase_checked_str appended_aes_gcm_tag_hex_str appended_aes_iv_hex_str appended_aes_salt_hex_str aes_key_derived_hex_str shred_iterations_int max_length_dir_name_shred_int packages_debian required_cmds_arr 7z_hash_len_int 7z_time_cost_int 7z_memory_cost_int aes_time_cost_int aes_memory_cost_int aes_iv_length_int appended_aes_gcm_tag_length DEBUG debug_log_file paraellism_int salt_shared_length_int)
## arr temp files used
temp_files_at_play_arr=(bin_archive_file_tmp bin_archive_file_two_tmp 7z_archive_file_tmp aes_gcm_tag_bin_tmp to_encrypt_dir_tmp)
## todo: arr of functtions to reset and unset
# functions_at_play_arr=()

# todo:
#   debug_var_dump ()

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

# make sure environment is up to sniff
# usage:
#   environment_check
environment_check () {
    check_requirements "${required_cmds[@]}"
    # todo: make sure not running as root
    # todo: test mktmp perms
    # todo: test $PWD perms
    # todo: test volume perms
}

# shreds specified file or dir
# usage:
#   shred_node <string path to file/dir>
shred_node () {
    if [ -d "$1" ]; then # if its a dir
        debug_echo "Shredding and deleting directory: $1 with $shred_iterations iterations"

        # next phase is to shred all files in the dir
        find "$1" -type f -exec shred --zero --remove --force --iterations=$shred_iterations_int "{}" \;

        # randomly rename all da dirrrrs and fuiels
        # todo: depth first order to prevent errorzzz
        # todo: file and dir paths proper
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

# shred and unset/delete temp files, vars, and functions
# usage:
#   cleanup
cleanup () {
    for tmp_file in "${temp_files_at_play_arr[@]}"; do
        debug_echo "cleanup: cleaning up $tmp_file"
        if [ -f "$tmp_file" -o -d "$tmp_file" ]; then
            shred_node "$tmp_file"
        else
            continue
        fi
    done

    for tmp_var in "${vars_at_play_arr[@]}"; do
        debug_echo "cleanup: cleaning up $tmp_var"
        # reset var to random hex
        exec "${tmp_var}='$(openssl rand -hex $max_length_dir_name_shred_int)'"
        # unset var
        exec "unset $tmp_var"
    done
}

# append hex string date to file
# usage:
#   append_data_to_file <string hex> <string file path>
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

    echo -n "$hex_str" >> "$file_path"
}

# retreive value from existing file and then chop it off that file
# user:
#   retreive_chop_appended_data_from_file <int num of hex bytes in hex string> <string file path>
retreive_chop_appended_data_from_file () {
    # todo: sanity check $1 and $2
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
    ## dont miss the - in front of $hex_data_length!
    truncate -s -$hex_data_length "$file_path"
}

# generate both random salts and random iv
# usage:
#   generate_salts_and_iv
generate_salts_and_iv () {
    # these outpoot as globalz :pidreaming:
    appended_7z_salt_hex_str=$(openssl rand -hex $salt_shared_length_int)
    appended_aes_salt_hex_str=$(openssl rand -hex $salt_shared_length_int)
    appended_aes_iv_hex_str=$(openssl rand -hex $aes_iv_length_int)
}

# derive new aes keys
# usage:
#   aes_derive_keys_new
aes_derive_keys_new () {
    # generater new random data and derive passphrase, savin shit as globals
    aes_key_derived_hex_str=$(\
        echo -n "$passphrase_checked_str" | \
            argon2 \
                "$(echo -n \"$appended_aes_salt_hex_str\" | xxd -d -p)" \
                -id \
                -r \
                -l 32 \
                -t $aes_time_cost_int \
                -m $aes_memory_cost_int \
                -p $paraellism_int
    )
}

# derive aes key, salt, tag, and iv from exist5ing file
# usage:
#   aes_derive_keys_passphrase_from_file
aes_derive_keys_passphrase_from_file () {
    # GET the info from the file and chop off
    ## aes salt hex str
    appended_aes_salt_hex_str=$(\
        retreive_chop_appended_data_from_file \
            $salt_shared_length_int \
            "$provided_encrypted_bin_file_path_str"
    )
    ## aes iv hex str
    appended_aes_iv_hex_str=$(\
        retreive_chop_appended_data_from_file \
            $aes_iv_length_int \
            "$provided_encrypted_bin_file_path_str"
    )
    ## aes gcm tag hex str
    appended_aes_gcm_tag_hex_str=$(\
        retreive_chop_appended_data_from_file \
            $appended_aes_gcm_tag_length \
            "$provided_encrypted_bin_file_path_str"
    )

    # make the tag tmp file
    echo -n "$appended_aes_gcm_tag_hex_str" | \
        xxd -p -r > "$aes_gcm_tag_bin_tmp"
    ## generate the 256 bit key as hex string save aS global
    aes_key_derived_hex_str=$(\
        echo -n "$passphrase_checked_str" | \
            argon2 \
                "$(echo -n \"$appended_aes_salt_hex_str\" | xxd -d -p)" \
                -id \
                -r \
                -l 32 \
                -t $aes_time_cost_int \
                -m $aes_memory_cost_int \
                -p $paraellism_int
    )
}

# derive new 7z passphrase
# usage:
#   7z_derive_keys_new
7z_derive_keys_new () {
    7z_derived_passphrase_str=$( \
        echo -n "$passphrase_checked_str" | \
            argon2 \
                "$(echo -n \"$appended_7z_salt_hex_str\" | xxd -r -p)" \
                -id \
                -r \
                -l $7z_hash_len_int \
                -t $7z_time_cost_int \
                -m $7z_memory_cost_int \
                -p $paraellism_int
    )
}

# derive 7z passphrase from existing file
# usage:
#   7z_derive_keys_passphrase_from_file
7z_derive_keys_passphrase_from_file () {
    # retreive 7z salt from file
    appended_7z_salt_hex_str=$(retreive_chop_appended_data_from_file $salt_shared_length_int "$provided_encrypted_bin_file_path_str")

    # derive the passphrase
    7z_derived_passphrase_str=$(\
        echo -n "$passphrase_checked_str" | \
            argon2 \
                "$(echo -n \"$appended_7z_salt_hex_str\" | xxd -r -p)" \
                -id \
                -r \
                -l $7z_hash_len_int \
                -t $7z_time_cost_int \
                -m $7z_memory_cost_int \
                -p $paraellism_int
    )
}

NUKE_REKT () {
    # todo: search certain defined dirs for .bhc files and shred dey headers
    cleanup
    # todo: force immediate shutdown
}

# secure file and dir perms
# usage:
#   fix_file_perms
fix_file_perms () {
    for tmp_file in "${temp_files_at_play_arr[@]}"; do
        debug_echo "cleanup: cleaning up $tmp_file"
        if [ -f "$tmp_file" ]; then
            sudo chmod 600 "$tmp_file"
            sudo chown $USER:$USER "$tmp_file"
        elif [ -d "$tmp_file" ]; then
            sudo find "$tmp_file" -type d -exec chmod 700 "{}" \;
            sudo find "$tmp_file" -type f -exec chmod 600 "{}" \;
            sudo chown -R $USER:$USER "$tmp_file"
        else
            continue
        fi
    done
}

# decrypt $bin_archive_file_tmp
# usage:
#   betterhiddencrypto_decrypt
betterhiddencrypto_decrypt () {
    if [ $DEBUG -gt 0 ]; then
        echo "DECRYPTING Starting..."
    else
        debug_echo "DECRYPTION STARTING: vars: provided_encrypted_bin_file_path_str: $provided_encrypted_bin_file_path_str to_encrypt_dir_tmp: $to_encrypt_dir_tmp, 7z_archive_file_tmp: $7z_archive_file_tmp, bin_archive_file_tmp: $bin_archive_file_tmp, salt_shared_length_int: $salt_shared_length_int, max_length_dir_name_shred_int: $max_length_dir_name_shred_int, shred_iterations_int: $shred_iterations_int"
    fi

    # make temp copy of safe file
    cp "$provided_encrypted_bin_safe_file_path_str" "$bin_archive_file_tmp"

    # OUTEr layer (aes gcm 256)
    ## derive keys
    aes_derive_keys_passphrase_from_file
    ## run decryption
    openssl \
        aes-256-gcm -d \
        -K "$aes_key_derived_hex_str" \
        -iv "$appended_aes_iv_hex_str" \
        -tag "$aes_gcm_tag_bin_tmp" \
        -in "$bin_archive_file_tmp" \
        -out "$7z_archive_file_tmp"

    # inner layer (7z)
    ## derive keyss and shit
    7z_derive_keys_passphrase_from_file
    ## make the temp dir to decrypt to
    mkdir "$to_encrypt_dir_tmp"
    ## 7z x: decrypt 7z encrypted file and extract
    if [ $DEBUG -gt 0 ]; then
        # -bb3 for max verbosity
        debug_return=$(7z x -p"$7z_derived_passphrase_str" "$7z_archive_file_tmp" -o"$to_encrypt_dir_tmp" -bb3)
        debug_echo "$debug_return"
    else
        7z x -p"$7z_derived_passphrase_str" "$7z_archive_file_tmp" -o"$to_encrypt_dir_tmp" # 1>/dev/null
    fi

    # show the dir
    echo "Decrypted Directory: $to_encrypt_dir_tmp"
}

# encrypt tmp dir $to_encrypt_dir_tmp
# usage:
#   betterhiddencrypto_encrypt
betterhiddencrypto_encrypt () {
    if [ $DEBUG -gt 0 ]; then
        echo "ENCRYPTION Starting..."
    else
        debug_echo "ENCRYPTION STARTING: vars: provided_encrypted_bin_file_path_str: $provided_encrypted_bin_file_path_str to_encrypt_dir_tmp: $to_encrypt_dir_tmp, 7z_archive_file_tmp: $7z_archive_file_tmp, bin_archive_file_tmp: $bin_archive_file_tmp, salt_shared_length_int: $salt_shared_length_int, max_length_dir_name_shred_int: $max_length_dir_name_shred_int, shred_iterations_int: $shred_iterations_int"
    fi

    # get a passphrases
    echo -e "\nEnter Passphrase: "
    read -s passphrase1
    echo -e "Repeat Passphrase:"
    read -s passphrase2
    ## check if passphrases match
    if [ "$passphrase1" != "$passphrase2" ]; then
        echo -e "\nPassphrases do not match! Exiting!\n"
        exit 1 # otherwise explicitly fail
    else
        debug_echo "Passwords match!"
        passphrase_checked_str="$passphrase1"
    fi

    # generate mew salts and ivs
    generate_salts_and_iv

    # inner layer (7z)
    ## derive passphrase for 7z layer
    7z_derive_keys_new
    ## create 7z archive
    if [ $DEBUG -gt 0 ]; then
        # -bb3 for max verbosity
        debug_return=$(7z a -p"$7z_derived_passphrase_str" "$7z_archive_file_tmp" "$to_encrypt_dir_tmp" -bb3)
        debug_echo "$debug_return"
    else
        # 7z <mode> -p"<passphrase>" <new volume path (.7z)> <directory path to encrypt>
        #   a: create archive
        #   -p"my passphrase" passphrase for encryptiom (note no whitespace betwen -p and the string)
        7z a -p"$7z_derived_passphrase_str" "$7z_archive_file_tmp" "$to_encrypt_dir_tmp" # 1>/dev/null # silent unless error
    fi
    ## test 7z archive
    if [ $DEBUG -gt 0 ]; then
        # 7z t: test existing 7z encrypted archive
        ## -bb3 -slt max verbosity plus technical info
        debug_return=$(7z t -p"$7z_derived_passphrase_str" "$7z_archive_file_tmp -bb3 -slt")
        debug_echo "$debug_return"
    else
        # 7z t: test existing 7z encrypted archive
        7z t -p"$7z_derived_passphrase_str" "$7z_archive_file_tmp" # 1>/dev/null # do this silently unless fail
    fi
    ## add the salt to the 7z temp file
    append_data_to_file "$appended_7z_salt_hex_str" "$7z_archive_file_tmp"

    # outer layer (aes gcm 256)
    ## derive keys
    aes_derive_keys_new
    ## run encryption
    openssl \
        aes-256-gcm -e \
        -K "$aes_key_derived_hex_str" \
        -iv "$appended_aes_iv_hex_str" \
        -tag "$(echo -n $appended_aes_gcm_tag_hex_str | xxd -p -r)" \
        -in "$bin_archive_file_tmp" \
        -out "$bin_archive_file_two_tmp"
    ## append data in order 
    append_data_to_file "$appended_aes_gcm_tag_hex_str" "$provided_encrypted_bin_file_path_str"
    append_data_to_file "$appended_aes_iv_hex_str" "$provided_encrypted_bin_file_path_str"
    append_data_to_file "$appended_aes_salt_hex_str" "$provided_encrypted_bin_file_path_str"
    ## todo: test it workan
    cp "$bin_archive_file_two_tmp" "$provided_encrypted_bin_file_path_str"
    ## cleanup
    cleanup
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
    # provided_encrypted_bin_safe_file_path_str="$PWD/$(basename $2)"

    # make sure the second arg is there
    if [ -z "$provided_encrypted_bin_file_path_str" ]; then
        echo "FAIL no second argument"
        exit 1
    fi

    # ccheck if file exists
    if [ -f "$provided_encrypted_bin_safe_file_path_str" ]; then
        # provided_encrypted_bin_safe_file_path_str="$provided_encrypted_bin_safe_file_path_str"
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