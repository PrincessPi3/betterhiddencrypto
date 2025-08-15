import subprocess
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from argon2.low_level import hash_secret_raw, Type
from time import time
import os
import sys
import getpass
import tarfile
import bz2

def bz2_compress_directory(directory_path, output_bz2_file):
    """
    Compresses a directory into a .tar.bz2 file.
    :param directory_path: Path to the directory to compress.
    :param output_bz2_file: Output .tar.bz2 file path.
    """
    tar_path = output_bz2_file + ".tmp.tar"
    # Create tar archive
    with tarfile.open(tar_path, "w") as tar:
        tar.add(directory_path, arcname=os.path.basename(directory_path))       
    # Compress with bz2
    with open(tar_path, 'rb') as f_in, bz2.open(output_bz2_file, 'wb') as f_out:
        for chunk in iter(lambda: f_in.read(1024 * 1024), b''):
            f_out.write(chunk)
    os.remove(tar_path)

def bz2_decompress_directory(bz2_file, output_dir):
    """
    Decompresses a .tar.bz2 file into a directory.
    :param bz2_file: Path to the .tar.bz2 file.
    :param output_dir: Directory to extract the contents to.
    """
    tar_path = bz2_file + ".tmp.tar"
    # Decompress bz2 to tar
    with bz2.open(bz2_file, 'rb') as f_in, open(tar_path, 'wb') as f_out:
        for chunk in iter(lambda: f_in.read(1024 * 1024), b''):
            f_out.write(chunk)
    # Extract tar
    with tarfile.open(tar_path, "r") as tar:
        tar.extractall(path=output_dir)
    os.remove(tar_path)

def derive_key_from_passphrase(passphrase: str, salt: bytes = None, iv: bytes = None, key_len: int = 32) -> bytes:
    """
    Derive a key from a passphrase using Argon2id KDF (argon2-cffi).
    
    :param passphrase: The input passphrase.
    :param salt: A salt (should be random and stored for later use). If None, a random 16-byte salt is generated.
    :param key_len: Length of the derived key in bytes (default 32 for AES-256).
    :return: Derived key bytes, salt bytes, and iv bytes.
    """
    if salt is None:
        salt = os.urandom(16) # 128 bits

    if iv is None:
        iv = get_random_bytes(16) # 128 bits

    # dieled these up for funnn
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
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input_file> [output_file]")
        exit(1)
    input_file = sys.argv[1]
    output_file = None
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]

    mode = getpass.getpass("Enter mode (encrypt/decrypt enc/dec e/d): ")

    # encryption mode
    if mode in ("encrypt", "enc", "e"):
        password1 = getpass.getpass("Enter password: ")
        password2 = getpass.getpass("Re-enter password: ")
        if password1 != password2:
            print("Passwords do not match. Exiting.")
            exit(1)
        password = password1
        if os.path.isdir(input_file):
            # Directory: compress then encrypt
            if not output_file:
                output_file = "./encrypted"
            compressed_file = output_file + ".bz2"
            bz2_compress_directory(input_file, compressed_file)
            encrypt_file_cbc(compressed_file, output_file + ".enc", password)
            # os.remove(compressed_file)
            print(f"Done: {input_file} compressed, encrypted into {output_file}")
        else:
            # File: just encrypt
            if not output_file:
                output_file = "encrypted"
            encrypt_file_cbc(input_file, output_file, password)
            print(f"Done: {input_file} encrypted into {output_file}")
    # decryption mode
    elif mode in ("decrypt", "dec", "d"):
        password = getpass.getpass("Enter password: ")
        if not output_file:
            output_file = "./decrypted"
        decrypted_file = output_file
        output_file = decrypted_file + str(time())
        decrypt_file_cbc(input_file, decrypted_file, password)
        # If the decrypted file is a .bz2, decompress it to a directory
        if decrypted_file.endswith('.bz2') or decrypted_file.endswith('.bz2.enc') or decrypted_file.endswith('.tmp.bz2'):
            bz2_decompress_directory(decrypted_file, output_file)
            # os.remove(decrypted_file)
            print(f"Done: {input_file} decrypted and decompressed into {extract_dir}")
        else:
            print(f"Done: {input_file} decrypted into {output_file}")
    # fail mode
    else:
        print("Invalid mode. Exiting.")
        exit(1)