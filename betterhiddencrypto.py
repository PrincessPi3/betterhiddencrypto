from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from argon2.low_level import hash_secret_raw, Type
import sys

def derive_key_from_passphrase(passphrase: str, salt: bytes = None, iv: bytes = None, key_len: int = 32) -> bytes:
    # Derive a key from a passphrase using Argon2id KDF (argon2-cffi).
    # 
    # :param passphrase: The input passphrase.
    # :param salt: A salt (should be random and stored for later use). If None, a random 16-byte salt is generated.
    # :param key_len: Length of the derived key in bytes (default 32 for AES-256).
    # :return: Derived key bytes, salt bytes, and iv bytes.
    if salt is None:
        salt = get_random_bytes(16) # 128 bits
    if iv is None:
        iv = get_random_bytes(16) # 128 bits
    # dialed these up for fun
    key = hash_secret_raw(
        secret=passphrase.encode(),
        salt=salt,
        time_cost=6,
        memory_cost=400000,  # kibibytes (400 MiB)
        parallelism=4,
        hash_len=key_len, # default 32
        type=Type.ID, # Argon2id
    )
    return key, salt, iv

# Encrypts a file using AES-256-GCM mode with Argon2id key derivation.
def encrypt_file_gcm(input_file, output_file, passphrase):
    key, salt, iv = derive_key_from_passphrase(passphrase=passphrase)
    cipher = AES.new(key, AES.MODE_GCM, nonce=iv)
    with open(input_file, 'rb') as f:
        plaintext = f.read()
    ciphertext, tag = cipher.encrypt_and_digest(plaintext)
    with open(output_file, 'wb') as f:
        f.write(salt)
        f.write(iv)
        f.write(tag)
        f.write(ciphertext)
"""
# Decrypts a file using AES-256-GCM mode with Argon2id key derivation.
def decrypt_file_gcm(input_file, output_file, passphrase):
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
"""

# Encrypts a file using AES-256-GCM mode with Argon2id key derivation.
def encrypt_file_gcm(input_file, output_file, passphrase):
    key, salt, iv = derive_key_from_passphrase(passphrase=passphrase)
    cipher = AES.new(key, AES.MODE_GCM, nonce=iv)
    with open(input_file, 'rb') as f:
        plaintext = f.read()
    ciphertext, tag = cipher.encrypt_and_digest(plaintext)
    with open(output_file, 'wb') as f:
        f.write(salt)
        f.write(iv)
        f.write(tag)
        f.write(ciphertext)

# Decrypts a file using AES-256-GCM mode with Argon2id key derivation
def decrypt_file_gcm(input_file, output_file, passphrase):
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
    # encrypt mode
    if mode in ("encrypt", "enc", "e"):
        encrypt_file_gcm(input_file, output_file, passphrase)
        print(f"Done: {input_file} encrypted into {output_file}")
    # decrypt mode
    elif mode in ("decrypt", "dec", "d"):
        decrypt_file_gcm(input_file, output_file, passphrase)
        print(f"Done: {input_file} decrypted into {output_file}")
# failure mode
else:
    print("Invalid mode. Exiting.")
    exit(1)