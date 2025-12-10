#!/bin/bash
# sudo rm -rf /tmp/openssl*; sudo rm -rf /usr/local/openssl-3.6
# sudo apt update
# sudo apt purge openssl
# sudo apt install libcrypto++-dev -y

cd /tmp
wget https://github.com/openssl/openssl/releases/download/openssl-3.6.0/openssl-3.6.0.tar.gz
tar xvfz openssl-3.6.0.tar.gz
cd openssl-3.6.0

#b sudo mkdir -p /usr/local/openssl-3.6/ssl
#b sudo mkdir -p /usr/local/openssl-3.6/bin

./Configure \
    --prefix=/usr/local/openssl-3.6 \
    enable-ec_nistp_64_gcc_128 \
    enable-ktls \
    enable-rc5 \
    enable-camellia \
    enable-chacha \
    enable-poly1305 \
    no-fips
    # enable-aesni \

make -j"$(nproc)"
sudo make install

cat <<EOF | sudo tee /usr/local/openssl-3.6/ssl/openssl.cnf > /dev/null
openssl_conf = openssl_init

[openssl_init]
providers = provider_init

[provider_init]
default = default_provider
base = base_provider

[default_provider]
activate = 1

[base_provider]
activate = 1
EOF

/usr/local/openssl-3.6/bin/openssl list -cipher-algorithms
/usr/local/openssl-3.6/bin/openssl list -cipher-algorithms | grep -i gcm
/usr/local/openssl-3.6/bin/openssl aes-256-gcm -help