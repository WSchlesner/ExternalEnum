#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 [IP] [URL]"
  exit 1
fi

IP=$1
URL=$2

# create directory for IP
DIRECTORY=$(echo $IP | tr "/" "_")
mkdir -p $DIRECTORY

# run nmap
nmap -A -p- $IP -oN $DIRECTORY/nmap.txt

# run ffuf
ffuf -u $URL/FUZZ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e .html,.php,.txt -recursion -recursion-depth 2 -o $DIRECTORY/ffuf.txt

# filter ffuf results by size and save in new file
cat $DIRECTORY/ffuf.txt | grep -vE "\[Size: [1-9]|[1-9][0-9]\]" > $DIRECTORY/ffuf_filtered.txt

# run gobuster
gobuster dns -d $URL -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o $DIRECTORY/gobuster.txt -t 50

# run dig
dig $URL any +noall +answer > $DIRECTORY/dig_any.txt
dig $URL a +noall +answer > $DIRECTORY/dig_a.txt
dig $URL ptr +noall +answer > $DIRECTORY/dig_ptr.txt
dig $URL txt +noall +answer > $DIRECTORY/dig_txt.txt
dig $URL mx +noall +answer > $DIRECTORY/dig_mx.txt

# run nslookup
nslookup -query=any $URL > $DIRECTORY/nslookup_any.txt
nslookup -query=a $URL > $DIRECTORY/nslookup_a.txt
nslookup -query=ptr $URL > $DIRECTORY/nslookup_ptr.txt
nslookup -query=txt $URL > $DIRECTORY/nslookup_txt.txt
nslookup -query=mx $URL > $DIRECTORY/nslookup_mx.txt

# add subdomains to hosts file
cat $DIRECTORY/gobuster.txt | awk '{print $2 " " "'"$IP"'"}' >> /etc/hosts

# run enum4linux with -A flag
enum4linux -A $IP > $DIRECTORY/enum4linux.txt

# attempt anonymous FTP login
echo "Anonymous FTP Login" >> $DIRECTORY/login_success.txt
echo "===================" >> $DIRECTORY/login_success.txt
ftp -n $IP <<END_SCRIPT >> $DIRECTORY/login_success.txt
quote USER anonymous
quote PASS anonymous
quit
END_SCRIPT

# attempt null session SMB login
echo "Null Session SMB Login" >> $DIRECTORY/login_success.txt
echo "======================" >> $DIRECTORY/login_success.txt
rpcclient -U "" $IP -N -c "getusername;quit" >> $DIRECTORY/login_success.txt 2>&1

# attempt null session RPC login
echo "Null Session RPC Login" >> $DIRECTORY/login_success.txt
echo "======================" >> $DIRECTORY/login_success.txt
smbclient -N -L //$IP/ >> $DIRECTORY/login_success.txt 2>&1

# run nmap service enumeration with aggressive scan
nmap -sV -A -p- $IP -oN $DIRECTORY/nmap_aggressive.txt

# run EyeWitness
EyeWitness -x $DIRECTORY/eyewitness.xml -d $DIRECTORY/eyewitness --no-prompt -f $DIRECTORY/gobuster.txt,$DIRECTORY/dig_any.txt,$DIRECTORY/dig_a.txt,$DIRECTORY/dig_ptr.txt,$DIRECTORY/dig_txt
