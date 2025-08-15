from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from argon2.low_level import hash_secret_raw, Type
from time import time
import sys

def derive_key_from_passphrase(passphrase: str, salt: bytes = None, iv: bytes = None, key_len: int = 32) -> bytes:
    """
    Derive a key from a passphrase using Argon2id KDF (argon2-cffi).
    
    :param passphrase: The input passphrase.
    :param salt: A salt (should be random and stored for later use). If None, a random 16-byte salt is generated.
    :param key_len: Length of the derived key in bytes (default 32 for AES-256).
    :return: Derived key bytes, salt bytes, and iv bytes.
    """
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
        hash_len=key_len,
        type=Type.ID,
    )

    # Return salt + key so you can store and reuse the salt for verification/decryption
    return key, salt, iv

def pad(data):
    """
    Pads the input data to be a multiple of the block size (16 bytes).
    """
    pad_len = 16 - (len(data) % 16)
    return data + bytes([pad_len] * pad_len)

def unpad(data):
    """
    Removes padding from the input data.
    """
    pad_len = data[-1]
    return data[:-pad_len]

def encrypt_file_cbc(input_file, output_file, password):
    """
    Encrypts a file using AES in CBC mode with Argon2id key derivation.
    """
    key, salt, iv = derive_key_from_passphrase(passphrase=password)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    with open(input_file, 'rb') as f:
        plaintext = f.read()
    padded = pad(plaintext)
    ciphertext = cipher.encrypt(padded)
    with open(output_file, 'wb') as f:
        f.write(salt)
        f.write(iv)
        f.write(ciphertext)

def decrypt_file_cbc(input_file, output_file, password):
    """
    Decrypts a file using AES in CBC mode with Argon2id key derivation.
    """
    with open(input_file, 'rb') as f:
        salt = f.read(16)
        iv = f.read(16)
        ciphertext = f.read()
    key, salt_gen, iv = derive_key_from_passphrase(passphrase=password, salt=salt, iv=iv, key_len=32)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    padded_plaintext = cipher.decrypt(ciphertext)
    plaintext = unpad(padded_plaintext)
    with open(output_file, 'wb') as f:
        f.write(plaintext)
if __name__ == "__main__":
    # default
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <mode> <passphrase> <input_file> <output_filename>")
        exit(1)
    mode = sys.argv[1]
    passphrase = sys.argv[2]
    input_file = sys.argv[3]
    output_file = sys.argv[4]    
    # encryption mode
    if mode in ("encrypt", "enc", "e"):
        encrypt_file_cbc(input_file, output_file, passphrase)
        print(f"Done: {input_file} compressed, encrypted into {output_file}")
    # decryption mode
    elif mode in ("decrypt", "dec", "d"):
        decrypt_file_cbc(input_file, output_file, passphrase)
        print(f"Done: {input_file} decompressed, decrypted into {output_file}")
    # fail mode
    else:
        print("Invalid mode. Exiting.")
        exit(1)