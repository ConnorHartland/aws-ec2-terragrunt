#!/bin/bash
set -euo pipefail

echo "=== Configuring nftables base firewall ==="

# Enable nftables
sudo systemctl enable nftables

# Create base nftables configuration
cat << 'NFTABLES' | sudo tee /etc/nftables.conf
#!/usr/sbin/nft -f

# Flush existing rules
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    
    # Accept loopback
    iif lo accept
    
    # Accept established/related connections
    ct state established,related accept
    
    # Accept ICMP (ping)
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept
    
    # Accept SSH (for SSM and emergency access)
    tcp dport 22 accept
    
    # Accept app port (will be configured per-service)
    # tcp dport 3000 accept
    
    # Log dropped packets (rate limited)
    limit rate 5/minute log prefix "nftables-dropped: " level warn
  }
  
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
  
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
NFTABLES

# Create directory for service-specific rules
sudo mkdir -p /etc/nftables.d

# Create template for app port rule (applied at boot)
cat << 'APPPORT' | sudo tee /etc/nftables.d/app-port.nft.template
# App port rule - generated at boot
add rule inet filter input tcp dport APP_PORT accept
APPPORT

echo "=== nftables base firewall configured ==="
