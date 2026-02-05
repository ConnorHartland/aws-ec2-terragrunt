#!/bin/bash
set -euo pipefail

echo "=== Setting up SSL/TLS base configuration ==="

# Create directories for certificates
sudo mkdir -p /etc/pki/app/{certs,private,kafka,kerberos}
sudo chmod 755 /etc/pki/app
sudo chmod 755 /etc/pki/app/certs
sudo chmod 700 /etc/pki/app/private
sudo chmod 700 /etc/pki/app/kafka
sudo chmod 700 /etc/pki/app/kerberos

# Update CA trust bundle
sudo update-ca-trust

# Create OpenSSL config for apps
cat << 'SSLCONF' | sudo tee /etc/pki/app/openssl.cnf
[default]
ssl_conf = ssl_sect

[ssl_sect]
system_default = system_default_sect

[system_default_sect]
MinProtocol = TLSv1.2
CipherString = DEFAULT:@SECLEVEL=2
SSLCONF

# Set ownership (nodeapp user will be created in next script)
sudo chown -R root:root /etc/pki/app

echo "=== SSL/TLS base configuration complete ==="
