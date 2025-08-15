import subprocess
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from argon2 import PasswordHasher
import getpass

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

def do_kdf(passphrase, salt):
    return PasswordHasher(salt_len=16, type='id').hash(passphrase, salt=salt)

def encrypt_file_cbc(input_file, output_file, password):
    """
    Encrypts a file using AES in CBC mode with Argon2id key derivation.
    """
    salt = get_random_bytes(16)
    key = do_kdf(password, salt)
    iv = get_random_bytes(16)
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

# Usage
if __name__ == "__main__":
    mode = getpass.getpass("Enter mode (encrypt/decrypt): ")
    password = getpass.getpass("Enter password: ")
    if mode == "encrypt" or mode == "enc" or mode == "e":
        encrypt_file_cbc('plain.txt', 'encrypted.bin', password)
    elif mode == "decrypt" or mode == "dec" or mode == "d":
        decrypt_file_cbc('encrypted.bin', 'decrypted.txt', password)