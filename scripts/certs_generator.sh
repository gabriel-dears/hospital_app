#!/bin/bash
set -e

TLS_DIR="./tls"
mkdir -p $TLS_DIR

# -----------------------------
# 1. Root CA
# -----------------------------
echo "Generating Root CA..."
openssl genrsa -out $TLS_DIR/ca.key 4096
openssl req -x509 -new -nodes -key $TLS_DIR/ca.key -sha256 -days 365 \
    -out $TLS_DIR/ca.crt -subj "/CN=MyRootCA"

# -----------------------------
# 2. user_service cert
# -----------------------------
echo "Generating user_service certificate..."
cat > $TLS_DIR/user_service.cnf <<EOL
[ req ]
default_bits       = 2048
distinguished_name = dn
req_extensions     = req_ext
prompt             = no

[ dn ]
CN = user-service

[ req_ext ]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth

[ alt_names ]
DNS.1 = user-service
DNS.2 = localhost
EOL

openssl genrsa -out $TLS_DIR/user_service.key 2048
openssl req -new -key $TLS_DIR/user_service.key -out $TLS_DIR/user_service.csr -config $TLS_DIR/user_service.cnf
openssl x509 -req -in $TLS_DIR/user_service.csr -CA $TLS_DIR/ca.crt -CAkey $TLS_DIR/ca.key \
    -CAcreateserial -out $TLS_DIR/user_service.crt -days 365 -sha256 \
    -extfile $TLS_DIR/user_service.cnf -extensions req_ext

# -----------------------------
# 3. appointment_service cert
# -----------------------------
echo "Generating appointment_service certificate..."
cat > $TLS_DIR/appointment_service.cnf <<EOL
[ req ]
default_bits       = 2048
distinguished_name = dn
req_extensions     = req_ext
prompt             = no

[ dn ]
CN = appointment-service

[ req_ext ]
subjectAltName = @alt_names
extendedKeyUsage = clientAuth

[ alt_names ]
DNS.1 = appointment-service
DNS.2 = localhost
EOL

openssl genrsa -out $TLS_DIR/appointment_service.key 2048
openssl req -new -key $TLS_DIR/appointment_service.key -out $TLS_DIR/appointment_service.csr -config $TLS_DIR/appointment_service.cnf
openssl x509 -req -in $TLS_DIR/appointment_service.csr -CA $TLS_DIR/ca.crt -CAkey $TLS_DIR/ca.key \
    -CAcreateserial -out $TLS_DIR/appointment_service.crt -days 365 -sha256 \
    -extfile $TLS_DIR/appointment_service.cnf -extensions req_ext

echo "All certificates generated in $TLS_DIR"
