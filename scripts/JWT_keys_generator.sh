#!/bin/bash

# Create directories if they don't exist
mkdir -p ../user_service/src/main/resources
mkdir -p ../jwt_security_common/src/main/resources

# Generate private key for user_service
openssl genpkey -algorithm RSA -out ../user_service/src/main/resources/private.key -pkeyopt rsa_keygen_bits:2048 -outform PEM
echo "Private key generated at user_service/src/main/resources/private.key"

# Generate public key from private key for jwt_security_common
openssl rsa -pubout -in ../user_service/src/main/resources/private.key -out ../jwt_security_common/src/main/resources/public.key
echo "Public key generated at jwt_security_common/src/main/resources/public.key"

echo "Done!"
