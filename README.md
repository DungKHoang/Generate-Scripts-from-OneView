# Generate PS scripts from OneView

Generate-scripts.PS1 is a PowerShell script that generates PowwerShell code to configure new OneView instances. The script queries an existing OV instance (called 'Master') and based on resources and attributes configured in this instance, it will create scripts that call OV PowerShell library (POSH). Those scripts can then run against new OV instance to re-create the environment. 

There are two categories of scripts
   * OV settings - the scripts are used to configure OV settings including : firmware baseline - time & locale - address pool/subnet ....
   * OV resources - those scripts are used to create OV resoruces including
        * Ethernet newtorks
        * Network set
        * FC / FCOE networks
        * SAN Manager
        * Storage Systems
        * Storage Volume templates
        * Storage Volumes
        * Logical InterConnect Groups
        * Uplink Sets
        * Enclosure Groups
        * Enclosures
        * Network connections
        * Local Storage connections
        * SAN Storage connections
        * Server Profile Templates
        * Server Profiles


## Prerequisites
Both scripts require the OneView PowerShell library at least v4.1 : https://github.com/HewlettPackard/POSH-HPOneView/releases


## Syntax

### To create Address Pools

```
    .\Generate-scripts.ps1     --> You will be prompted for credential and IP address of the master OV appliance
    .\Generate-scripts.ps1 -OVApplianceIP <OV-IP-Address-of-the-master-OV> -OVAdminName <Admin-name> -OVAdminPassword <password> -OVAuthDomain <local or AD-domain>

```
Scripts will be created under the folder Scripts