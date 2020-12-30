#!/bin/sh

###########################
# (C) 2017 Steven Black
# Updated by Kyle Burk
###########################
#
# 2017-04-17 - 1.0.0 Initial release
# 2017-04-18 - 1.1.0 Improved modularization; added functionality for white & black lists
# 2017-04-25 - 1.1.1 Relocated conf dir to /usr/local/etc
# 2017-04-25 - 1.1.2 Relocate script dir; update checks to create conf templates
# 2017-05-17 - 1.1.3 Remove local declarations for improved compatibility
# 2017-05-17 - 1.1.4 Cleanup syntax as per shellcheck.net suggestions
# 2020-12-28 - 2.0.0 Modify to use host file lists, remove yoyo
###########################

# routine for ensuring all necessary dependencies are found
check_deps () {
  Deps="date grep mv rm sed wget whoami su"
  MissingDeps=0

  for NeededDep in $Deps; do
    if ! hash "$NeededDep" > /dev/null 2>&1; then
      printf "Command not found in PATH: %s\n" "$NeededDep" >&2
      MissingDeps=$((MissingDeps+1))
    fi
  done

  if [ $MissingDeps -gt 0 ]; then
    printf "%d commands not found in PATH; aborting\n" "$MissingDeps" >&2
    exit 1
  fi
}

# check for whitelist/blacklist configuration files & create templates if not present
check_conf () {
  WhiteList="${ConfDir}/ad-blocker-wl.conf"
  BlackList="${ConfDir}/ad-blocker-bl.conf"

  # if no white list found, then create a template & instructions
  if [ ! -f "$WhiteList" ]; then
    printf "No white list found; creating template\n" >&2

  { echo "# White list of domains to remain unblocked for ad-blocker.sh";
      echo "# Add one fully-qualified domain name per line";
      echo "# Comments are indicated by a '#' as the first character";
      echo "# example:";
      echo "# ad.example.com"; } > "$WhiteList"
  fi

  # if no black list found, then create a template & instructions
  if [ ! -f "$BlackList" ]; then
    printf "No black list found; creating template\n" >&2

    { echo "# Black list of additional domains for ad-blocker.sh";
      echo "# Add one fully-qualified domain name per line";
      echo "# Comments are indicted by a '#' as the first character";
      echo "# example:";
      echo "# ad.example.com"; } > "$BlackList"
  fi
}

# verify running as proper user
# if not, attempt to switch and abort if cannot
check_user () {
  User=$(whoami)
  if [ "$User" != "DNSServer" ]; then
    printf "Running as %s\n" "$User" >&2
    printf "Switching to DNSServer\n" >&2
    su -m DNSServer "$0" "$@" || exit 1
  exit 0
  fi
}

# function to fetch the blocklist and update the path element
# for each entry to comply with the Synology setup

fetch_blocklist () {
  BlocklistURL="$1"
  printf "Pulling blocklist from %s\n" "${BlocklistURL}" >&2
  # the "-O-" tells wget to send the file to standard out instead of a real file
  # this makes it suitable for piping and eliminates need for another temp file
  wget -qO- "$BlocklistURL" | \
    sed -e 's/\s/ /g' | \
    sed -s -e 's/ *$//g' | \
    sed -s -r 's/([^#].*)?(#)+(.*)?/\1/g' | \
    sed -r '/^\s*$/d' | \
    sed -r 's/(.*)(\s)$/\1/g' | \
    sed -r 's/(.*\s)?(.*)$/\2/g' | \
    sed -r 's/(.*)+$/zone "\1" { type master; notify no; file "null.zone.file"; };/g' >> "/tmp/ad-blocker.new"
  printf "\n" >> "/tmp/ad-blocker.new"
}

# user-specified list of domains to be blocked in addition
apply_blacklist () {
  BlackList="${ConfDir}/ad-blocker-bl.conf"
  BlockList="/tmp/ad-blocker.new"

  # skip if the config doesn't exist
  if [ ! -f "$BlackList" ]; then
    return 0;
  fi

  # process the blacklist skipping over any comment lines
  while read -r Line
  do
    # strip the line if it starts with a '#'
    # if the line was stripped, then continue on to the next line
    Domain=$(echo "$Line" | grep -v "^[[:space:]*\#]")
    if [ -z "$Domain" ]; then
      continue;
    fi

    # if domain already listed then skip it and continue on to the next line
    # make sure you don't get a false positive with a partial match
    # by using the "-w" option on grep
    Found=$(grep -w "$Domain" "$BlockList")
    if [ ! -z "$Found" ]; then
      continue;
    fi

    # domain not found, so append it to the list
    echo "zone \"$Domain\" { type master; notify no;};" >> "$BlockList"

  done < "$BlackList"
}

update_whitelist () {
  WhiteListTmp="/tmp/ad-blocker-wl.tmp"
  WhiteListURL="$1"
  printf "Pulling whitelist from %s\n" "${WhiteListURL}" >&2
  wget -qO- "$WhiteListURL" | \
    sed -e 's/\s/ /g' | \
    sed -s -e 's/ *$//g' | \
    sed -s -r 's/([^#].*)?(#)+(.*)?/\1/g' | \
    sed -r '/^\s*$/d' | \
    sed -r 's/(.*)(\s)$/\1/g' | \
    sed -r 's/(.*\s)?(.*)$/\2/g' >> "$WhiteListTmp"
}

# user-specified list of domains to remain unblocked
apply_whitelist () {
  WhiteList="${ConfDir}/ad-blocker-wl.conf"
  BlockList="/tmp/ad-blocker.new"
  BlockListTmp="/tmp/ad-blocker.tmp"
  WhiteListTmp="/tmp/ad-blocker-wl.tmp"
  # skip if the config doesn't exist
  if [ ! -f "$WhiteList" ]; then
    return 0
  fi

  if [ -f "$WhiteListTmp" ]; then
    cat "$WhiteListTmp" | sort | uniq -i | grep -v 'zone "" { type master; notify no; file "null.zone.file"; };' > "$WhiteList"
  fi


  # process the whitelist skipping over any comment lines
  while read -r Line
  do
    # strip the line if it starts with a '#'
    # if the line was stripped, then continue on to the next line
    Domain=$(echo "$Line" | grep -v "^[[:space:]*\#]")
    if [ -z "$Domain" ]; then
      continue;
    fi

    # copy every line in the blocklist *except* those matching the whitelisted domain
    # into a temp file and then copy the temp file back over the original source
    grep -w -v "$Domain" "$BlockList" > "$BlockListTmp"
    mv "$BlockListTmp" "$BlockList"
  done < "$WhiteList"
}

# make sure the include statement is added to the ZoneDataFile
update_zone_data () {
  ZoneDataFile="${ZoneDataDir}/null.zone.file"
  ZoneDataDB="${ZoneDataDir}/ad-blocker.db"
  BlockListTmp="/tmp/ad-blocker.tmp"
  BlockList="/tmp/ad-blocker.new"
  # Remove Dupes
  cat "$BlockList" | sort | uniq -i | grep -v 'zone "" { type master; notify no; file "null.zone.file"; };' > "$BlockListTmp"
  mv "$BlockListTmp" "$BlockList"
  # move the final version of the block list to the final location
  mv "$BlockList" "$ZoneDataDB"

  # safety check: make sure both files exist before proceeding
  # check for the include statement in the ZoneDataFile
  # if it is present do nothing, else append the include statement to the ZoneDataFile
  if [ -f "$ZoneDataDB" ] && [ -f "$ZoneDataFile" ]; then
    Matches=$(grep 'include "/etc/zone/data/ad-blocker.db";' "$ZoneDataFile")
    if [ -z "$Matches" ]; then
      echo '' >> "$ZoneDataFile"
      echo 'include "/etc/zone/data/ad-blocker.db";' >> "$ZoneDataFile"
    fi
  fi
}

# update the ZoneMasterFile with an new serial number
update_zone_master () {
  Now=$(date +"%Y%m%d%S")
  ZoneMasterFile="${ZoneMasterDir}/null.zone.file"

  if [ -f "$ZoneMasterFile" ]; then
    rm -f "$ZoneMasterFile"
  fi

  # rebuild the zone master file with the updated serial number
  { echo '$TTL 86400     ; one day';
    echo '@ IN SOA ns.null.zone.file. mail.null.zone.file. (';
    echo '  '${Now}'   ; serial number YYYYMMDDNN';
    echo '  86400        ; refresh 1 day';
    echo '  7200         ; retry 2 hours';
    echo '  864000       ; expire 10 days';
    echo '  86400 )      ; min ttl 1 day';
    echo '  IN NS  ns.null.zone.file.';
    echo '  IN A   127.0.0.1';
    echo '* IN A   127.0.0.1'; } > "$ZoneMasterFile"

  # reload the server config to pick up the changes
  "${RootDir}"/script/reload.sh 'null.zone.file'
}

# manual_fixes () {
#   ZoneDataDB="${ZoneDataDir}/ad-blocker.db"
#   ZoneDataDBTmp="${ZoneDataDir}/ad-blocker.tmp"
#   cat ad-blocker.db | \
#     grep -v 'zone "format)">" { type master; notify no; file "null.zone.file"; };' | \
#     grep -v 'zone "format)</title>" { type master; notify no; file "null.zone.file"; };' > ad-blocker.tmp
#     'zone "href="rss/1.0/adservers.rss">" { type master; notify no; file "null.zone.file"; };'
# }

# Global vars for common paths
ConfDir="/usr/local/etc"
RootDir="/var/packages/DNSServer/target"
ZoneDir="${RootDir}/named/etc/zone"
ZoneDataDir="${ZoneDir}/data"
ZoneMasterDir="${ZoneDir}/master"
BlockLists=(
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  "https://mirror1.malwaredomains.com/files/justdomains"
  "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
  "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
  "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
  "https://hosts-file.net/psh.txt"
  "https://raw.githubusercontent.com/quidsup/notrack/master/trackers.txt"
  "https://v.firebog.net/hosts/Airelle-trc.txt"
  "https://hosts-file.net/ad_servers.txt"
  "https://adaway.org/hosts.txt"
  "https://v.firebog.net/hosts/AdguardDNS.txt"
  "https://v.firebog.net/hosts/Admiral.txt"
  "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
  "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
  "https://v.firebog.net/hosts/Easylist.txt"
  "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
  "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
  "https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts"
  "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts_without_controversies.txt"
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
  "https://v.firebog.net/hosts/static/w3kbl.txt"
  "https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt"
  "https://someonewhocares.org/hosts/zero/hosts"
  "https://raw.githubusercontent.com/vokins/yhosts/master/hosts"
  "https://winhelp2002.mvps.org/hosts.txt"
  "https://v.firebog.net/hosts/neohostsbasic.txt"
  "https://raw.githubusercontent.com/RooneyMcNibNug/pihole-stuff/master/SNAFU.txt"
  "https://paulgb.github.io/BarbBlock/blacklists/hosts-file.txt"
  "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
  "https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt"
  "https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt"
  "https://v.firebog.net/hosts/Prigent-Crypto.txt"
  "https://mirror.cedia.org.ec/malwaredomains/immortal_domains.txt"
  "https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt"
  "https://phishing.army/download/phishing_army_blocklist_extended.txt"
  "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt"
  "https://v.firebog.net/hosts/Shalla-mal.txt"
  "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
  "https://urlhaus.abuse.ch/downloads/hostfile/"
  "https://v.firebog.net/hosts/Prigent-Malware.txt"
  "https://raw.githubusercontent.com/HorusTeknoloji/TR-PhishingList/master/url-lists.txt"
)
WhiteLists=(
  "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt"
)

# Main Routine
check_deps
check_conf
check_user "$@"
for list in ${BlockLists[@]}; do
  fetch_blocklist $list
done
for wlist in ${WhiteLists[@]}; do
  update_whitelist $wlist
done
apply_blacklist
apply_whitelist
update_zone_data
update_zone_master

exit 0
