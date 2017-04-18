#!/bin/sh

###########################
# (C) 2017 Steven Black
###########################
#
# 2017-04-17 - 1.0.0 Initial release
#
###########################

# Relevant DNS Directories
RootDir="/var/packages/DNSServer/target"
ZoneDir="${RootDir}/named/etc/zone"
ZoneDataDir="${ZoneDir}/data"
ZoneMasterDir="${ZoneDir}/master"

# Dependencies Check
Dependencies="date grep mv rm sed wget"
MissingDep=0
for NeededDep in $Dependencies; do
  if ! hash "$NeededDep" >/dev/null 2>&1; then
    printf "Command not found in PATH: %s\n" "$NeededDep" >&2
    MissingDep=$((MissingDep+1))
  fi
done

# Bail out if missing dependencies
if [ $MissingDep -gt 0 ]; then
  printf "%d commands not found in PATH; aborting\n" "$MissingDep" >&2
  exit 1
fi

# Move to the Zone Data Dir for next bit of work
cd ${ZoneDataDir}

# Download the blacklist from "http://pgl.yoyo.org" as "ad-blocker.raw"
wget -O ad-blocker.raw "http://pgl.yoyo.org/as/serverlist.php?hostformat=bindconfig&showintro=0&mimetype=plaintext"

# Modify Zone file path from "null.zone.file" to "/etc/zone/master/null.zone.file"
# The path modification is a requirement of the Synology DNS Server.
sed -e 's/null.zone.file/\/etc\/zone\/master\/null.zone.file/g' ad-blocker.raw > ad-blocker.new
rm ad-blocker.raw

# Safety step: don't blow away an existing db unless we've got a valid new data set
if [ -f ad-blocker.new ] ; then
  mv ad-blocker.new ad-blocker.db
fi

# Include the new zone data
if [ -f ad-blocker.db ] && [ -f null.zone.file ]; then
  # if the include line doesn't already exist, then append it the the end of the null.zone.file
  grep -q 'include "/etc/zone/data/ad-blocker.db";' null.zone.file || echo 'include "/etc/zone/data/ad-blocker.db";' >> null.zone.file
fi

# Generate a timestamp in the proper format for the DNS serial number
Now=$(date +"%Y%m%d")

# Rebuild master null.zone.file with the updated serial number
cd ${ZoneMasterDir}
rm -f null.zone.file

echo '$TTL 86400     ; one day'          >> null.zone.file
echo '@ IN SOA ns.null.zone.file. mail.null.zone.file. (' >> null.zone.file
echo '  '${Now}'00   ; serial number YYYYMMDDNN'          >> null.zone.file
echo '  86400        ; refresh 1 day'    >> null.zone.file
echo '  7200         ; retry 2 hours'    >> null.zone.file
echo '  864000       ; expire 10 days'   >> null.zone.file
echo '  86400 )      ; min ttl 1 day'    >> null.zone.file
echo 'NS       ns.null.zone.file.'       >> null.zone.file
echo 'A        127.0.0.1'                >> null.zone.file
echo '* IN A   127.0.0.1'                >> null.zone.file

# Reload the server config to pick up the modifications
${RootDir}/script/reload.sh

exit 0
