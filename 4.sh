#!/bin/bash

IP=$1
URL=$2

# Create a directory for each IP
mkdir $IP && cd $IP

# Run NMAP aggressive scan and output results to file
nmap -A -oN nmap.txt $IP

# Run dig to enumerate vhosts and output results to file
dig +noall +answer $URL | awk '{print $5}' > vhosts.txt

# Run additional dig requests for subdomains and attempt domain transfer
for domain in $(cat vhosts.txt); do
    echo "-----------------------"
    echo "Performing DNS enumeration on domain: $domain"
    echo "-----------------------"
    dig $domain A >> dig_results.txt
    dig $domain PTR >> dig_results.txt
    dig $domain TXT >> dig_results.txt
    dig $domain ANY >> dig_results.txt
    dig $domain MX >> dig_results.txt
    nslookup -query=A $domain >> nslookup_results.txt
    nslookup -query=PTR $domain >> nslookup_results.txt
    nslookup -query=TXT $domain >> nslookup_results.txt
    nslookup -query=ANY $domain >> nslookup_results.txt
    nslookup -query=MX $domain >> nslookup_results.txt
    dig axfr $domain >> dig_axfr_results.txt
done

# Add subdomains to /etc/hosts file
while read line; do
    if [ ! -z "$line" ]; then
        echo "$IP $line" >> /etc/hosts
    fi
done < vhosts.txt

# Run GoBuster to discover subdomains and directories
gobuster dns -t 20 -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt -d $URL -o gobuster_dns_results.txt
gobuster dir -t 20 -u http://$URL -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -o gobuster_dir_results.txt

# Run ffuf to enumerate vhosts and output results to file
ffuf -w vhosts.txt -u http://$URL -H "Host: FUZZ" -fs $(echo -n "FUZZ" | wc -c) -mc 200 -ac -o ffuf_results.txt

# Filter ffuf results to only include successful ones
cat ffuf_results.txt | grep "200 OK" | awk '{print $1}' > ffuf_results_filtered.txt

# Run EyeWitness to generate report
eyewitness -f eye_report.html -d $URL -x nmap.txt

# Run enum4linux with -A flag and output results to file
enum4linux -A $IP > enum4linux_results.txt

# Attempt to login to FTP, smbclient, and rpcclient with null session and log success
echo "Attempting anonymous FTP login..."
echo "-----------------------"
echo "" | ftp $IP | tee -a ftp_results.txt
echo "-----------------------"

echo "Attempting SMB client null session login..."
echo "-----------------------"
smbclient -N -L //$IP | tee -a smbclient_results.txt
echo "-----------------------"

echo "Attempting RPC client null session login..."
echo "-----------------------"
rpcclient -U "" $IP -c "getusername;quit" | tee -a rpcclient_results.txt
echo "-----------------------"

# Return to the parent directory
cd ..
