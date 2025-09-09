#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Directories
# -----------------------------
BASE_DIR="$(pwd)"
TLS_TMP="$BASE_DIR/tls"
USER_TLS="../user_service/src/main/resources/tls"
APPT_TLS="../appointment_service/src/main/resources/tls"

mkdir -p "$TLS_TMP" "$USER_TLS" "$APPT_TLS"

# -----------------------------
# 0. Cleanup
# -----------------------------
rm -f "$TLS_TMP"/ca.srl

# -----------------------------
# 1. Root CA
# -----------------------------
echo "Generating Root CA..."
openssl genrsa -out "$TLS_TMP/ca.key" 4096
openssl req -x509 -new -nodes -key "$TLS_TMP/ca.key" -sha256 -days 3650 \
  -out "$TLS_TMP/ca.crt" -subj "/CN=MyRootCA"

# -----------------------------
# Helper to create extfile
# -----------------------------
write_extfile() {
  local file="$1"
  local cn="$2"
  local usage="$3"

  cat > "$file" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = dn
req_extensions     = req_ext
prompt             = no

[ dn ]
CN = $cn

[ req_ext ]
subjectAltName = @alt_names
extendedKeyUsage = $usage

[ alt_names ]
DNS.1 = $cn
DNS.2 = localhost
EOF
}


# -----------------------------
# 2. user_service cert (serverAuth)
# -----------------------------
echo "Generating user_service certificate..."
write_extfile "$TLS_TMP/user_service.cnf" "user-service" "serverAuth, clientAuth"

openssl genrsa -out "$TLS_TMP/user_service.key" 2048
openssl req -new -key "$TLS_TMP/user_service.key" \
  -out "$TLS_TMP/user_service.csr" -config "$TLS_TMP/user_service.cnf"

openssl x509 -req -in "$TLS_TMP/user_service.csr" \
  -CA "$TLS_TMP/ca.crt" -CAkey "$TLS_TMP/ca.key" -CAcreateserial \
  -out "$TLS_TMP/user_service.crt" -days 365 -sha256 \
  -extfile "$TLS_TMP/user_service.cnf" -extensions req_ext

# -----------------------------
# 3. appointment_service cert (clientAuth)
# -----------------------------
echo "Generating appointment_service certificate..."
write_extfile "$TLS_TMP/appointment_service.cnf" "appointment-service" "clientAuth"

openssl genrsa -out "$TLS_TMP/appointment_service.key" 2048
openssl req -new -key "$TLS_TMP/appointment_service.key" \
  -out "$TLS_TMP/appointment_service.csr" -config "$TLS_TMP/appointment_service.cnf"

openssl x509 -req -in "$TLS_TMP/appointment_service.csr" \
  -CA "$TLS_TMP/ca.crt" -CAkey "$TLS_TMP/ca.key" -CAcreateserial \
  -out "$TLS_TMP/appointment_service.crt" -days 365 -sha256 \
  -extfile "$TLS_TMP/appointment_service.cnf" -extensions req_ext

openssl pkcs8 -topk8 -nocrypt -in "$TLS_TMP/appointment_service.key" -out "$TLS_TMP/appointment_service_pkcs8.key"
openssl pkcs8 -topk8 -nocrypt -in "$TLS_TMP/user_service.key" -out "$TLS_TMP/user_service_pkcs8.key"

# -----------------------------
# 4. Copy certs to services
# -----------------------------
echo "Copying certs into services..."
cp "$TLS_TMP"/ca.crt "$TLS_TMP"/user_service*.* "$USER_TLS/"
cp "$TLS_TMP"/ca.crt "$TLS_TMP"/appointment_service*.* "$APPT_TLS/"

# -----------------------------
# 5. Permissions
# -----------------------------
chmod 600 "$USER_TLS"/*.key "$APPT_TLS"/*.key

# -----------------------------
# 6. Verification
# -----------------------------
echo
echo "=== Verify certs ==="
openssl verify -CAfile "$TLS_TMP/ca.crt" "$TLS_TMP/user_service.crt"
openssl verify -CAfile "$TLS_TMP/ca.crt" "$TLS_TMP/appointment_service.crt"

echo
echo "=== user_service cert details ==="
openssl x509 -in "$TLS_TMP/user_service.crt" -noout -text | grep -A2 "Subject:"

echo
echo "=== appointment_service cert details ==="
openssl x509 -in "$TLS_TMP/appointment_service.crt" -noout -text | grep -A2 "Subject:"

echo
echo "All certificates generated and installed into:"
echo "  - $USER_TLS"
echo "  - $APPT_TLS"
