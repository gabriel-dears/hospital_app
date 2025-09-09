#!/bin/bash
set -e

# Base paths
CERTS_DIR="../rabbitmq/certs"
RESOURCES_DIR="/home/gabriel/Documents/fiap/ADJ8/projects/03/hospital_app"
SERVICES=(
    "appointment_service"
    "notification_service"
    "appointment_history_service"
)

# Create certs dir
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# 1. Create CA
openssl genpkey -algorithm RSA -out ca.key
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=MyOrg/OU=IT/CN=MyRootCA"

# 2. Server key & certificate
openssl genpkey -algorithm RSA -out server.key
openssl req -new -key server.key -out server.csr \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=MyOrg/OU=IT/CN=rabbitmq"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650 -sha256

# 3. Client key & certificate
openssl genpkey -algorithm RSA -out client.key
openssl req -new -key client.key -out client.csr \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=MyOrg/OU=IT/CN=client"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3650 -sha256

# 4. Client keystore (PKCS12)
openssl pkcs12 -export -in client.crt -inkey client.key \
  -out client_keystore.p12 -name client -CAfile ca.crt -caname root \
  -passout pass:changeit

# 5. Truststore (Java keystore with CA)
keytool -import -file ca.crt -keystore truststore.p12 -alias root \
  -storepass changeit -noprompt

# 6. Copy keystore & truststore to each service
for SERVICE in "${SERVICES[@]}"; do
  mkdir -p "$RESOURCES_DIR/$SERVICE/src/main/resources/rabbitmq"
  cp client_keystore.p12 "$RESOURCES_DIR/$SERVICE/src/main/resources/rabbitmq"
  cp truststore.p12 "$RESOURCES_DIR/$SERVICE/src/main/resources/rabbitmq"
done

echo "Certificates, keystore, and truststore generated and copied successfully."
