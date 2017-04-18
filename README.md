# ad-blocker
A simple ad-blocker for Synology devices

## Background

The main goal of this project is to setup a simple ad-blocking service that will work on all LAN-connected devices. In order to keep things simple, an additional goal is to run this service on the Synology NAS that already provides many file and network services (including DNS) for the LAN. Because the DNS service is in active use on the Synology device, many solutions (like the very nice Pi-hole package) are not workable as there are conflicts over the DNS port. This solution has a minimal impact on the standard Synology system and so should be largely free of unwanted side effects and be "update friendly".

There are several advantages of enabling a LAN-wide ad-blocking service over traditional browser plugins:
* It's easier to maintain than ensuring all browsers have the appropriate plugins and remain updated on all devices
* It works for mobile devices (phones, tablets, etc.) for both browser and apps
* It is effective even on devices not allowed to be modified, e.g. school-owned tablets

## Requirements
This project requires some familiarity with the basic Unix system and tools. Additionally, access to the Synology admin interface is requried. This project _does_ involve access to the internals to your system. As such, there is always the risk of an accident or mistake leading to irrecoverable data loss. **Be mindful when logged onto your system -- especially when performing any action as root or admin.**

This project should be completed in 30-60 minutes.

This service requires the following skills:
* Editing files on a Unix system (e.g. `vi`, `nano`)
* Setting up a DNS zone via the web-based DSM interface
* SSH access
* Standard Unix tools (`sudo`, `chown`, `chmod`, `mv`, `cd`, `ls`, `wget`, `cat`, etc.)
* Administration/root access to the Synology device

These instructions have been verified as working on a Synology DS1513+ running DSM 6.1-15047 Update 2. 

## DNS Service Setup
1. Log in as adminstrator to the Synology DSM (administration interface)
1. In the Package Center, open the "DNS Server" app.
1. Select the "Zones" tab and create a new Master Zone.
1. Fill in the following fields as follows:
    * Domain Type: Forward Zone
    * Domain Name: `null.zone.file`
    * Master DNS Server: `<IP Address of your Synology Device>`
    * Serial Format: Date (YYYYMMDDNN)
1. (Optional) Set a limit on the Zone Transfer rules to restrict it to your LAN
1. (Optional) Set a limit on the source IP rules to restrict it to your LAN

The Domain Name _must_ be `null.zone.file` and the Serial Format must be set as `Date` as that is what the updater script expects. The Master DNS Server should have the same IP address as your Synology device. (This will be overwritten later.)

## Script Installation
1. SSH as the administrator to the Synology device
    * `ssh admin@synology.example.com`
1. Navigate to the DNS Server package directory
    * `cd /var/packages/DNSServer/target/script`
1. Download the `ad-blocker.sh` script
    * `sudo wget -O ad-blocker.sh "https://raw.githubusercontent.com/steventblack/ad-blocker/master/ad-blocker.sh"`
1. Change the owner and permissions of the script
    * `sudo chown DNSServer:DNSServer ad-blocker.sh`
    * `sudo chmod +x ad-blocker.sh`
1. Verify the script executes properly
    * `sudo -u DNSServer ./ad-blocker.sh`
    * Verify `/var/packages/DNSServer/target/named/etc/zone/data/ad-blocker.db` exists and has ~200k of data
    * Verify `/var/packages/DNSServer/target/named/etc/zone/data/null.zone.file` has the line `include "/etc/zone/data/ad-blocker.db";`
    * Verify `/var/packages/DNSServer/target/named/etc/zone/master/null.zone.file` is updated with the correct serial number
    
The ad-blocking functionality should now be in effect. You can test the effectiveness by disabling any ad-blocking plugins in your browser and navigating to any ad-laden website to verify ads remain suppressed. Mobile devices should similarly be tested.

## List Updating
1. Log in as administrator to the Synology DSM (administration interface)
1. Open up the "Control Panel" app.
1. Select the "Task Scheduler" service.
1. Create a new Scheduled Task for a user-defined script.
1. For the "General" tab, fill in the fields as follows:
    * Task: `Ad-blocker Update`
    * User: `root`
    * Enabled: (checked)
1. For the "Schedule" tab, fill in fields as follows:
    * Run on the following days: Daily
    * First run time: `03:20`
    * Frequency: once a day
1. For the "Task Settings" tab, fill in the fields as follow:
    * Send run details by email: `<your email here>`
    * User defined script: `sudo -u DNSServer /var/packages/DNSServer/target/script/ad-blocker.sh`

The run time should be set to run no more than once a day and be performed at an off-peak traffic time. The block lists don't change that frequently so be courteous to the provider. It is not strictly necessary to have the run details sent via email, but enabling it may help if there's a need to troubleshoot.

## Blacklist/Whitelist
_Features under development; please stand by_

## Caveats
This solution works well for blocking the vast majority of ad providers. It should help speed up page rendering as well as provide a degree of privacy and security to your devices. However, it is not a panacea and you should continue to practice safe browsing habits. In particular, remember that this solution only applies to devices _within_ the LAN and so mobile devices may lose any protections it offers when using a different network.

## Thanks
This solution utilizes the block list provided by [yoyo.org](http://pgl.yoyo.org/adservers/). A big thanks goes out to them for their hard work and continued maintainence.
