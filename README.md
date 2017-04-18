# ad-blocker
A simple ad-blocker for Synology devices

## Background

The main goal of this project is to setup a simple ad-blocking service that will work on all LAN-connected devices. In order to keep things simple, an additional goal is to run this service on the Synology NAS that already provides many file and network services (including DNS) for the LAN. Because the DNS service is in active use on the Synology device, many solutions (like the very nice Pi-hole package) are not applicable as there are port conflicts as to which service "owns" the DNS port. This solution has a minimal impact on the standard Synology system and so should be largely free of unwanted side effects and be "update friendly".

There are several advantages of enabling a LAN-wide ad-blocking service over traditional browser plugins:
* It's easier to maintain than ensuring all browsers have the appropriate plugins and update on all devices
* It works for mobile devices (phones, tablets, etc.) for both browser and apps
* It is effective even on devices not allowed to be modified, e.g. school-owned tablets.

## Requirements
This project requires some familiarity with the basic Unix system and tools. Additionally, access to the Synology admin interface is requried. This project _does_ involve access to the internals to your system. As such, there is always the risk of an accident or mistake leading to irrecoverable data loss. Be mindful when executing any command on your system -- especially when performing any action as root or admin.

This project should be completed in 30-60 minutes.

This service requires the following skills:
* Editing files on a Unix system (e.g. `vi`, `nano`)
* Setting up a DNS zone via the web-based DSM interface
* SSH access
* Standard Unix tools (`sudo`, `chown`, `chmod`, `mv`, `cd`, `ls`, etc.)
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
    * `wget -O ad-blocker.sh XXX`
1. Change the owner and permissions of the script
    * `chown DNSServer:DNSServer ad-blocker.sh`
    * `chmod +x ad-blocker.sh`

## List updating
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

The run time should be set to run no more than once a day and be performed at a off-peak traffic time. The block lists don't change that frequently so be courteous to the provider. It is not strictly necessary to have the run details sent via email, but enabling it may help if there's a need to troubleshoot.

## Blacklist/Whitelist
_Features under development; please stand by_
