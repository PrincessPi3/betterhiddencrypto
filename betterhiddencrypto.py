import subprocess
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
# from argon2 import PasswordHasher
# from Crypto.Protocol.KDF import Argon2id
from argon2.low_level import hash_secret_raw, Type
import os
import getpass

def derive_key_from_passphrase(passphrase: str, salt: bytes = None, iv: bytes = None, key_len: int = 32) -> bytes:
    """
    Derive a key from a passphrase using Argon2id KDF (argon2-cffi).
    
    :param passphrase: The input passphrase.
    :param salt: A salt (should be random and stored for later use). If None, a random 16-byte salt is generated.
    :param key_len: Length of the derived key in bytes (default 32 for AES-256).
    :return: Derived key bytes.
    """
    if salt is None:
        salt = os.urandom(16)

    if iv is None:
        iv = get_random_bytes(16)

    key = hash_secret_raw(
        secret=passphrase.encode(),
        salt=salt,
        time_cost=2,
        memory_cost=102400,  # kibibytes (100 MiB)
        parallelism=2,
        hash_len=key_len,
        type=Type.ID,
    )
    # Return salt + key so you can store and reuse the salt for verification/decryption
    return key, salt, iv

def run_command(command):
    """
    Runs a shell command and returns its output as a string.
    """
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return result.stdout

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
    key, salt, iv = derive_key_from_passphrase(password)
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
    key = Argon2(password, salt, 32, type='ID')
    cipher = AES.new(key, AES.MODE_CBC, iv)
    padded_plaintext = cipher.decrypt(ciphertext)
    plaintext = unpad(padded_plaintext)
    with open(output_file, 'wb') as f:
        f.write(plaintext)

derive_key_from_passphrase(get_random_bytes(16))

"""
# Usage
if __name__ == "__main__":
    mode = getpass.getpass("Enter mode (encrypt/decrypt): ")
    password = getpass.getpass("Enter password: ")
    if mode == "encrypt" or mode == "enc" or mode == "e":
        encrypt_file_cbc('plain.txt', 'encrypted.bin', password)
    elif mode == "decrypt" or mode == "dec" or mode == "d":
        decrypt_file_cbc('encrypted.bin', 'decrypted.txt', password)
"""