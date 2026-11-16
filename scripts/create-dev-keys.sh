#!/bin/sh
# Development CA + signing key for RAUC bundles, and the matching site.conf lines.
# Usage: scripts/create-dev-keys.sh <build-dir>
# DEVELOPMENT ONLY: unencrypted keys on disk. Production signing keys belong in an HSM
# or a separate signing machine, and the layer never contains any key.
# Certificate extensions follow rauc/meta-rauc-community create-example-keys.sh (MIT).
set -eu
BUILD=${1:?build dir}
K="$BUILD/dev-keys"
if [ -e "$K/ca.cert.pem" ]; then echo "keys already in $K"; exit 0; fi
mkdir -p "$K" "$BUILD/conf"
cat > "$K/ext.cnf" <<'CNF'
[req]
distinguished_name = dn
[dn]
[v3_ca]
basicConstraints = critical,CA:true
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[v3_leaf]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
CNF
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 -subj "/O=rromero dev/CN=rromero RAUC development CA" \
    -keyout "$K/ca.key.pem" -out "$K/ca.cert.pem" -config "$K/ext.cnf" -extensions v3_ca
openssl req -config "$K/ext.cnf" -newkey rsa:4096 -nodes -subj "/O=rromero dev/CN=rromero RAUC development signer" \
    -keyout "$K/dev.key.pem" -out "$K/dev.csr.pem"
openssl x509 -req -in "$K/dev.csr.pem" -CA "$K/ca.cert.pem" -CAkey "$K/ca.key.pem" -CAcreateserial \
    -days 1825 -extfile "$K/ext.cnf" -extensions v3_leaf -out "$K/dev.cert.pem"
openssl verify -CAfile "$K/ca.cert.pem" "$K/dev.cert.pem"
cat > "$BUILD/conf/site.conf" <<CONF
RAUC_KEYRING_FILE = "$K/ca.cert.pem"
RAUC_KEY_FILE = "$K/dev.key.pem"
RAUC_CERT_FILE = "$K/dev.cert.pem"
CONF
echo "wrote $BUILD/conf/site.conf"
