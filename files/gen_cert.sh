#!/usr/bin/env bash

set -euo pipefail

SERVER_KEY=server-key.pem
TARGET_PATH=$1 #/etc/ssl/spice
LISTEN_TLS_HOSTNAME=$2
LISTEN_TLS_IP=$3

# creating a key for our ca
if [ ! -e ca-key.pem ]; then
    openssl genrsa -out ca-key.pem 1024
fi
# creating a ca
if [ ! -e ca-cert.pem ]; then
    openssl req -new -x509 -days 1095 -key ca-key.pem -out ca-cert.pem  -subj "/C=SA/L=Saratov/O=BaseALT/CN=BASEALT SAR AUTO CA"
fi
# create server key
if [ ! -e $SERVER_KEY ]; then
    openssl genrsa -out $SERVER_KEY 1024
fi
# create a certificate signing request (csr)
if [ ! -e server-key.csr ]; then
    openssl req -new -key $SERVER_KEY -out server-key.csr -extensions v3_req -config <(
cat <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = v3_req
distinguished_name = dn

[ dn ]
C=SA
L=Saratov
O=BaseALT
OU=Testing Domain
emailAddress=testing@smb.basealt.ru
CN = ${LISTEN_TLS_HOSTNAME}

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.0 = ${LISTEN_TLS_HOSTNAME}
IP.0 = ${LISTEN_TLS_IP}
EOF
)

fi
# signing our server certificate with this ca
if [ ! -e server-cert.pem ]; then
	openssl x509 -req -extfile <(printf "subjectAltName=DNS:${LISTEN_TLS_HOSTNAME},IP:${LISTEN_TLS_IP}") -days 1095 -in server-key.csr -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
fi

# now create a key that doesn't require a passphrase
openssl rsa -in $SERVER_KEY -out $SERVER_KEY.insecure
mv $SERVER_KEY $SERVER_KEY.secure
mv $SERVER_KEY.insecure $SERVER_KEY

# show the results (no other effect)
openssl rsa -noout -text -in $SERVER_KEY
openssl rsa -noout -text -in ca-key.pem
openssl req -noout -text -in server-key.csr
openssl x509 -noout -text -in server-cert.pem
openssl x509 -noout -text -in ca-cert.pem

# copy *.pem file to /etc/pki/libvirt-spice
if [[ ! -d "$TARGET_PATH" ]]
then
    mkdir -p "$TARGET_PATH"
fi
cp ./*.pem "$TARGET_PATH/"

# echo --host-subject
echo "your --host-subject is" \" `openssl x509 -noout -text -in server-cert.pem | grep Subject: | cut -f 10- -d " "` \"
