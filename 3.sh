#!/bin/bash

# Set up arguments
IP=$1
URL=$2

# Set up directories
mkdir -p $IP
cd $IP
mkdir -p nmap ffuf gobuster eyewitness enum4linux

# Run NMAP and save output
nmap -A -sC -sV -p- -T4 $IP -oN nmap/nmap.txt

# Run dig and nslookup commands for all record types and save output
for record in A PTR TXT ANY MX; do
    dig $URL $record > dig/$record.txt
    nslookup -type=$record $URL >> dig/$record.txt
done

# Run ffuf and filter output by size
ffuf -w /usr/share/wordlists/dirb/common.txt -u "http://$URL/FUZZ" -recursion -recursion-depth 1 -e .php,.html,.txt,.bak,.old -fs 1565 -o ffuf.txt

# Run GoBuster and save output
gobuster dns -d $URL -o gobuster/subdomains.txt -t 50

# Add all subdomains to /etc/hosts
grep $URL gobuster/subdomains.txt | awk '{print $2" "$1}' >> /etc/hosts

# Run additional dig and nslookup commands for subdomains and attempt zone transfer
while read subdomain; do
    for record in A PTR TXT ANY MX; do
        dig $subdomain $record > dig/$subdomain-$record.txt
        nslookup -type=$record $subdomain >> dig/$subdomain-$record.txt
    done
    dig axfr $subdomain > dig/$subdomain-zone-transfer.txt
done < gobuster/subdomains.txt

# Run enum4linux and save output
enum4linux -a $IP > enum4linux/enum4linux.txt

# Attempt to login to services and save output
echo "Anonymous FTP login:" > enum4linux/enum4linux.log
echo "====================" >> enum4linux/enum4linux.log
ftp $IP >> enum4linux/enum4linux.log 2>&1
echo "" >> enum4linux/enum4linux.log

echo "SMBClient null session login:" >> enum4linux/enum4linux.log
echo "=============================" >> enum4linux/enum4linux.log
smbclient -L //$IP -U "%" >> enum4linux/enum4linux.log 2>&1
echo "" >> enum4linux/enum4linux.log

echo "RPCClient null session login:" >> enum4linux/enum4linux.log
echo "============================" >> enum4linux/enum4linux.log
rpcclient -U "" $IP >> enum4linux/enum4linux.log 2>&1
echo "" >> enum4linux/enum4linux.log

# Run EyeWitness and save output
EyeWitness --web -f gobuster/subdomains.txt --no-prompt -d eyewitness/
