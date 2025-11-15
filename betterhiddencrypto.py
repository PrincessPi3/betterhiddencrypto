from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from argon2.low_level import hash_secret_raw, Type
import sys
import re

def hex_to_unicode_grep(hex_string):
    # Ensure even length
    if len(hex_string) % 2 != 0:
        raise ValueError("Hex string must have even length")
    # Group into two characters, format as \x{..}
    return ''.join([f"\\x{{{hex_string[i:i+2]}}}" for i in range(0, len(hex_string), 2)])

def check_passphrase(passphrase):
    # Checks password strength. Returns True if strong, else False.
    # Criteria: min 20 chars, upper, lower, digit, special char.
    if len(passphrase) < 20:
        print("Password too short (min 20 chars)")
        return False
    if not re.search(r"[A-Z]", passphrase):
        print("Password must contain an uppercase letter")
        return False
    if not re.search(r"[a-z]", passphrase):
        print("Password must contain a lowercase letter")
        return False
    if not re.search(r"[0-9]", passphrase):
        print("Password must contain a digit")
        return False
    if not re.search(r"[^A-Za-z0-9]", passphrase):
        print("Password must contain a special character")
        return False
    return True

def derive_key_from_passphrase(passphrase: str, salt: bytes = None, iv: bytes = None, key_len: int = 32) -> bytes:
    # Derive a key from a passphrase using Argon2id KDF (argon2-cffi).
    # 
    # :param passphrase: The input passphrase.
    # :param salt: A salt (should be random and stored for later use). If None, a random 16-byte salt is generated.
    # :param key_len: Length of the derived key in bytes (default 32 for AES-256).
    # :return: Derived key bytes, salt bytes, and iv bytes.
    if salt is None:
        salt = get_random_bytes(32) # 256 bits
    if iv is None:
        iv = get_random_bytes(16) # 128 bits
    # dialed these to crackhead levels for funnn
    key = hash_secret_raw(
        secret=passphrase.encode(),
        salt=salt,
        time_cost=6, # some int of time cost? idk lmfao
        memory_cost=512000,  # kibibytes (500 MiB)
        parallelism=6, # threads
        hash_len=key_len, # default 32
        type=Type.ID, # Argon2id
    )

    # print all da deets
    if debug_mode:
        # ugrep regex format
        ugrep_key = hex_to_unicode_grep(key.hex())
        ugrep_iv = hex_to_unicode_grep(iv.hex())
        ugrep_salt = hex_to_unicode_grep(salt.hex())
        # passphrase converted to hex then to ugrep format
        ugrep_passphrase = hex_to_unicode_grep(passphrase.encode().hex())
        # crib is a known plaintext value, to check for leaks
        ugrep_crib = hex_to_unicode_grep("Flap9-Parasail1-Reappoint1-Bright9-Chute6".encode().hex())

        print(f"\nPassphrase: find_bytes '{ugrep_passphrase}' .\n")
        print(f"Derived key: find_bytes '{ugrep_key}' .\n")
        print(f"Salt: find_bytes '{ugrep_salt}' .\n")
        print(f"IV: find_bytes '{ugrep_iv}' .\n")
        print(f"Crib: find_bytes '{ugrep_crib}' .\n")

    return key, salt, iv

# Encrypts a file using AES-256-GCM mode with Argon2id key derivation.
def encrypt_file_gcm(input_file, output_file, passphrase):
    # get key, salt, and iv
    key, salt, iv = derive_key_from_passphrase(passphrase=passphrase)
    # AES GCM mode with 256-bit key and that silly lil nonce
    cipher = AES.new(key, AES.MODE_GCM, nonce=iv)
    with open(input_file, 'rb') as f:
        plaintext = f.read()
    ciphertext, tag = cipher.encrypt_and_digest(plaintext)
    # Write the salt, iv, tag, and ciphertext to the output file
    with open(output_file, 'wb') as f:
        f.write(salt)
        f.write(iv)
        f.write(tag)
        f.write(ciphertext)

# Decrypts a file using AES-256-GCM mode with Argon2id key derivation
def decrypt_file_gcm(input_file, output_file, passphrase):
    # Read the salt, iv, tag, and ciphertext from the input file
    with open(input_file, 'rb') as f:
        salt = f.read(16)
        iv = f.read(16)
        tag = f.read(16)
        ciphertext = f.read()
    key, salt, iv = derive_key_from_passphrase(passphrase=passphrase, salt=salt, iv=iv, key_len=32)
    cipher = AES.new(key, AES.MODE_GCM, nonce=iv)
    plaintext = cipher.decrypt_and_verify(ciphertext, tag)
    with open(output_file, 'wb') as f:
        f.write(plaintext)

if __name__ == "__main__":
    # if less than 5 arguments are provided, print usage and exit
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <mode> <passphrase> <input_file> <output_filename>")
        exit(1)
    # get the args
    mode = sys.argv[1]
    passphrase = sys.argv[2]
    input_file = sys.argv[3]
    output_file = sys.argv[4]
    debug_mode = sys.argv[5]
    if debug_mode.lower() in ("1", "2", "true", "yes", "y"):
        debug_mode = True
    else:
        debug_mode = False 
    # check password strength before proceeding
    if not check_passphrase(passphrase):
        print("Weak password. Exiting.")
        exit(1) # explicitly fail on weak password
    # encrypt mode
    if mode in ("encrypt", "enc", "e"):
        encrypt_file_gcm(input_file, output_file, passphrase)
        # print(f"Done: {input_file} encrypted into {output_file}")
    # decrypt mode
    elif mode in ("decrypt", "dec", "d"):
        decrypt_file_gcm(input_file, output_file, passphrase)
        # print(f"Done: {input_file} decrypted into {output_file}")
# failure mode
else:
    print("Invalid mode. Exiting.")
    exit(1)