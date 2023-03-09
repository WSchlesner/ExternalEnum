#!/bin/bash

# Check if IP and URL are provided as arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <IP> <URL>"
    exit 1
fi

IP=$1
URL=$2

# Create a directory for each IP
if [ ! -d "$IP" ]; then
    mkdir "$IP"
fi

# Nmap scan for service enumeration
echo "Running Nmap service enumeration..."
nmap -sS -sV -A -T4 -oA "$IP/nmap-aggressive" "$IP"

# Dig for DNS enumeration
echo "Running dig enumeration..."
for type in A PTR TXT ANY MX; do
    dig "$URL" "$type" +short > "$IP/dig_$type.txt"
    nslookup -query="$type" "$URL" > "$IP/nslookup_$type.txt"
done
for sub in $(cat "$IP/ffuf.txt" | awk -F "." '{print $1}' | sort -u); do
    for type in A PTR TXT ANY MX; do
        dig "$sub.$URL" "$type" +short >> "$IP/dig_$type.txt"
        nslookup -query="$type" "$sub.$URL" >> "$IP/nslookup_$type.txt"
    done
done

# Domain transfer attempts
echo "Running domain transfer attempts..."
for sub in $(cat "$IP/dig_A.txt" | grep "NS" | awk '{print $1}'); do
    host -l "$URL" "$sub" >> "$IP/domain_transfer.txt"
done

# Ffuf for vhost enumeration
echo "Running ffuf enumeration..."
ffuf -w /usr/share/wordlists/dirb/vhosts.txt -u "http://$IP/" -H "Host: FUZZ.$URL" -o "$IP/ffuf.txt"
cat "$IP/ffuf.txt" | grep -E '^200|^30[12357]' | grep -vE 'Content-Length: (0|404)' > "$IP/ffuf-filtered.txt"

# Gobuster for subdomain and directory enumeration
echo "Running gobuster enumeration..."
gobuster dns -d "$URL" -w /usr/share/wordlists/dns/all.txt -o "$IP/gobuster-subdomains.txt" -t 100
gobuster dir -u "http://$IP/" -w /usr/share/wordlists/dirb/big.txt -t 100 -o "$IP/gobuster-directories.txt"

# Add subdomains to /etc/hosts
echo "Adding subdomains to /etc/hosts..."
for sub in $(cat "$IP/gobuster-subdomains.txt" | grep -v "#" | cut -d " " -f 2); do
    echo "$IP $sub" >> /etc/hosts
done

# Dig for subdomain enumeration
echo "Running dig subdomain enumeration..."
for sub in $(cat "$IP/gobuster-subdomains.txt" | grep -v "#" | cut -d " " -f 2); do
    for type in A PTR TXT ANY MX; do
        dig "$sub" "$type" +short >> "$IP/dig_$type.txt"
        nslookup -query="$type" "$sub" >> "$IP/nslookup_$type.txt"
    done
done

# Enum4linux for SMB enumeration
echo "Running enum4linux for SMB enumeration..."
enum4linux "$IP"

# Null session login attempts
echo "Attempting null session login..."
if smbclient -N -L //$IP/ | grep -
