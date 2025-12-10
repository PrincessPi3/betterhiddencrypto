#!/bin/bash
echo "cleanin up any previous builds"
sudo rm -rf /tmp/openssl*
sudo rm -rf /usr/local/openssl-3.6

echo "Updootin repos"
sudo apt update

echo "Installan packages"
sudo apt install 7zip openssl argon2 xxd cracklib-runtime ripgrep build-essential -y

echo "scooting over to /tmp"
cd /tmp

echo "Downdootin openssl 3.6.0"
wget https://github.com/openssl/openssl/releases/download/openssl-3.6.0/openssl-3.6.0.tar.gz

echo "extracting openssl 3.6.0"
tar xvfz openssl-3.6.0.tar.gz

echo "scootaloo into openssl-3.6.0"
cd openssl-3.6.0

echo "configurant"
./Configure \
    --prefix=/usr/local/openssl-3.6 \
    --openssldir=/usr/local/openssl-3.6/ssl \
    --libdir=/usr/local/openssl-3.6/lib64/ \
    no-shared \
    no-fips

echo "compilan"
make -j"$(nproc)"

echo "installan"
sudo make install

echo "configuran"
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

echo "tesstan"
/usr/local/openssl-3.6/bin/openssl version | less
/usr/local/openssl-3.6/bin/openssl list -cipher-algorithms | less
/usr/local/openssl-3.6/bin/openssl list -cipher-algorithms | grep -i gcm | less
/usr/local/openssl-3.6/bin/openssl aes-256-gcm -help | less

echo "donesies :3"
