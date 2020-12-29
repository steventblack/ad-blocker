wget -O /usr/local/bin/ad-blocker.sh "https://raw.githubusercontent.com/0xW1sKy/ad-blocker/master/ad-blocker.sh"
chown root:root /usr/local/bin/ad-blocker.sh
chmod 755 /usr/local/bin/ad-blocker.sh
touch /usr/local/etc/ad-blocker-wl.conf
touch /usr/local/etc/ad-blocker-bl.conf
chown DNSServer:DNSServer /usr/local/etc/ad-blocker-wl.conf
chmod 777 /usr/local/etc/ad-blocker-wl.conf
chown DNSServer:DNSServer /usr/local/etc/ad-blocker-bl.conf
chmod 777 /usr/local/etc/ad-blocker-bl.conf
/bin/sh /usr/local/bin/ad-blocker.sh

FILESIZE=$(du -h "/var/packages/DNSServer/target/named/etc/zone/data/ad-blocker.db" | cut -f1)
INCLUDES=$(if grep -q 'include "/etc/zone/data/ad-blocker.db";' /var/packages/DNSServer/target/named/etc/zone/data/null.zone.file; then echo "True"; else echo "False"; fi)
MODDATE=$(cut -c -8 <<<$(cat /var/packages/DNSServer/target/named/etc/zone/master/null.zone.file | grep 'serial number YYYYMMDDNN' | awk -F ';' '{print $1}' | sed -e 's/\s//g'))

echo "Size of Database File: $FILESIZE"
echo "Database reference in null.zone.file?: $INCLUDES"
echo "null.zone.file Last Updated: $(date -d $MODDATE +"%A %B %d, %Y")"

