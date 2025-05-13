<!-- (C) Copyright 2024-2025 Hewlett Packard Enterprise Development LP -->

RHEL/Oracle Linux/Rocky Linux Bring Your Own Image (BYOI) for HPE Private Cloud Enterprise - Bare Metal
=============================

* [Overview](#overview)
* [Quick Guide for Build Process](#quick-guide-for-build-process)
* [Detailed Version of Build Process](#detailed-version-of-build-process)
  *   [Setup Linux system for imaging build](#setup-linux-system-for-imaging-build)
  *   [Downloading recipe repo from GitHub](#downloading-recipe-repo-from-github)
  *   [Downloading RHEL ISO file](#downloading-rhel-iso-file)
  *   [Building the Bare Metal RHEL image and service](#building-the-bare-metal-rhel-image-and-service)
* [Customizing RHEL image](#customizing-rhel-image)
  *   [Modifying the way the image is built](#modifying-the-way-the-image-is-built)
* [Using the RHEL service and image](#using-the-rhel-service-and-image)
  *   [Adding RHEL service to Bare Metal portal](#adding-rhel-service-to-bare-metal-portal)
  *   [Creating an RHEL Host with RHEL Service](#creating-an-rhel-host-with-rhel-service)
  *   [Triage of image deployment problems](#triage-of-image-deployment-problems)
  *   [Known Observations and Limitations](#known-observations-and-limitations)
  *   [Troubleshooting](#troubleshooting)
  *   [OS License](#os-license)
  *   [Storage Volumes iSCSI and FC](#storage-volumes-iscsi-and-fc)


----------------------------------

# Overview

This GitHub repository provides the scripts, templates, and documentation needed to create a Red Hat Enterprise Linux (RHEL) service for  
HPE Private Cloud Enterprise (PCE) Bare Metal (BM) using a RHEL installation .ISO file. By following this process to build a custom image,  
you gain full control over the specific version of RHEL used and can customize the installation process through a kickstart file.  
After creating the image, you can seamlessly add the new service to the HPE Bare Metal Portal (https://client.greenlake.hpe.com/) and  
deploy hosts using this tailored image. This offers a streamlined, flexible solution for your enterprise infrastructure needs.

# Supported HPE PCE Bare Metal Operating Systems

> [!IMPORTANT]  
> **This BYOI RHEL recipe has been shown to work with RHEL, Oracle Linux, and Rocky Linux.**

**GitHub Public Repository**: https://github.com/HewlettPackard/hpegl-metal-os-rhel-iso

Service Category | Service Flavor    | Service Version 
---------------- | ----------------- | --------------------------------------------
Linux            | RHEL              | 8.6, 8.7, 8.10, 9.0, 9.1, 9.2, 9.4, 9.5
Linux            | Oracle Linux (OL) | 8.6, 8.9, 9.3, 9.4
Linux            | Rocky Linux       | 8.8, 9.0

## Supported Network Bonding Configuration for HPE PCE Bare Metal
This section provides the BMaaS OS configurations for RHEL and its derivatives (Oracle Linux and Rocky Linux), outlining Switch LAG (Link Aggregation Group) settings along with bonding modes and key configuration parameters.<BR><BR>
**Additional Reference:** For a detailed overview of bonding modes and the required switch settings, please refer to the official [RHEL9 Networking Guide](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/configuring-network-bonding_configuring-and-managing-networking#configuring-network-bonding_configuring-and-managing-networking).

Switch LAG   | Configuration Details |
------------ | --------------------- |
**Disabled** <BR> (Default Configuration) | **Configuration Details:** This is the **$${\color{red}default}$$** bonding  mode for the host. <BR><BR> **Behavior:** When the switch LAG is disabled, the bond mode is set to TLB (Transmit Load Balancing). In this mode, only one network port will receive incoming traffic, while all network ports in the bond will participate in transmitting outgoing traffic. |
**Enabled** <BR> (User Configurable)  | **Configuration Details:** When the switch LAG is enabled, the bonding mode **needs to be set manually to Balance XOR**. <BR><BR> **Behavior:** When the switch LAG is enabled and the bond mode is set to XOR, the switch is configured to allow receiving traffic on both network ports. <BR><BR> **Configuration Steps:** <BR> <1> Set `no_switch_lag` to `false` in the **OS Image Service file** ([glm-service.yml.template](glm-service.yml.template)) <BR> <2> In the cloud-init configuration file ([glm-cloud-init.template](glm-cloud-init.template)), update the bonding mode by setting: <BR> `bond-mode: balance-xor`. |


# Quick Guide for Build Process

Workflow for Building Image:

![image](https://github.com/user-attachments/assets/ced85a55-118b-42b2-8d24-2a6e0de3ed3f)


**Prerequisites:**
```
This setup ensures a reliable and secure process for managing and deploying OS images in your HPE Bare Metal environment.
1. You will need a web server with HTTPS support to store the HPE Base Metal images.
2. The Web Server is anything that:
    A. you can upload large OS image (.iso) to, and
    B. is on a network that will be reachable from the HPE On-Premises Controller.
       When an OS image service (.yml) is used to create an HPE Bare Metal Host, the HPE Bare Metal
       OS image (.iso) will be downloaded via the `secure_url` mentioned in the service file (.yml).
3. IMPORTANT:
   The test `glm-test-service-image.sh` script is to verify the HPE Bare Metal OS image (.iso).
   To run this test, edit the file `./glm-build-image-and-service.sh` to set the required
   Web Server-related parameters are listed below:
      +----------------------------------------------------------------------------
      | +--------------------------------------------------------------------------
      | | File `./glm-build-image-and-service.sh`
      | |   <1> WEB_SERVER_IP: IP address of web server to transfer ISO to (via SSH)
      | |       Example: WEB_SERVER_IP="10.152.3.96"
      | |   <2> REMOTE_PATH:   Path on a web server to copy files to
      | |       Example: REMOTE_PATH="/var/www/images/"
      | |   <3> SSH_USER:      Username for SSH transfer
      | |       Example: SSH_USER_NAME="root"
      | | Note: Add your Linux test machine's SSH key to the Web Server
      | +--------------------------------------------------------------------------
      +----------------------------------------------------------------------------
   In this document, for the manual build example:
   A. a local Web Server "https://10.152.3.96" is used for the storage of OS images (.iso).
   B. we are assuming that the HPE Bare Metal OS images will be kept in: https://10.152.3.96/images/<.iso>
4. Linux machine for building OS image:
   A. Image building has been successfully tested with the following list of Ubuntu OS and its LTS versions:
      Ubuntu 20.04.6 LTS (focal)
      Ubuntu 22.04.5 LTS (jammy)
      Ubuntu 24.04.1 LTS (noble)
   B. Install supporting tools (git, xorriso, and isomd5sum)
```

Step 1. Source code readiness

A. Clone the GitHub Repo `hpegl-metal-os-rhel-iso`
```
git clone https://github.com/HewlettPackard/hpegl-metal-os-rhel-iso.git
```
B. Change the Directory to the Cloned Repository and Create a Temporary Folder to Download ISO Image
```
cd hpegl-metal-os-rhel-iso
mkdir images
```

Step 2. Download the RHEL .ISO image to your local build environment via whatever method you prefer (Web Browser, etc)
For example, we will assume that you have downloaded the RHEL .ISO image into the local directory (images/RHEL-9.0.0-20220810.0-x86_64-dvd1.iso).

Step 3. Run the script [glm-build-image-and-service.sh](glm-build-image-and-service.sh) to generate an output Bare Metal image .ISO as well as Bare Metal Service .yml:

Example for running the build including artifact verification:
```
./glm-build-image-and-service.sh \
 -i images/RHEL-9.0.0-20220810.0-x86_64-dvd1.iso \
 -v 9.0 \
 -r qPassw0rd \
 -p https://10.152.3.96 \
 -o images/RHEL-9.0-BareMetal.iso \
 -s images/RHEL-9.0-BareMetal.yml
```
Example for running the build excluding artifact verification:
```
./glm-build-image-and-service.sh \
 -i images/RHEL-9.0.0-20220810.0-x86_64-dvd1.iso \
 -v 9.0 \
 -r qPassw0rd \
 -p https://10.152.3.96 \
 -o images/RHEL-9.0-BareMetal.iso \
 -s images/RHEL-9.0-BareMetal.yml \
 -x true
```

Example build result for reference:
```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal RHEL service/image
| | that consists of the following 2 new files:
| |     RHEL-9.0-BareMetal.iso
| |     RHEL-9.0-BareMetal.yml
| |
| | To use this new Bare Metal RHEL service/image in the HPE Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (RHEL-9.0-BareMetal.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/RHEL-9.0-BareMetal.iso
| |
| | (2) Add the Bare Metal Service file (RHEL-9.0-BareMetal.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Bare Metal Service file,
| |     sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

Step 4: Upload the Output Bare Metal Image (.ISO) to the Web Server
- Copy the generated Bare Metal image (.ISO) to the designated Web Server.

Step 5: Add the Bare Metal Service .yml File to the Portal
To upload the Bare Metal service .yml file, follow these steps:
- Sign in to the HPE Bare Metal Portal
  - Log in using your credentials.
- Select Your Tenant
  - Click "Go to tenant" to choose the appropriate tenant.
- Access the Metal Consumption Dashboard
  - Click on the "Metal Consumption" tile on the dashboard.
- Navigate to the OS/Application Images Tab
  - Click on the "OS/application images" tab.
- Upload the Service .yml File
  - Click the "Add OS/application image" button to upload the service .yml file.

Step 6: Create a New Bare Metal Host Using the OS Image Service
To create a new Bare Metal host, follow these steps:
- Sign in to the HPE Bare Metal Portal
  - Log in to the portal and click "Go to tenant" to select the appropriate tenant.
- Navigate to the Compute Groups Tab
  - On the dashboard, click the "Metal Consumption" tile, then select the "Compute groups" tab.
- Create a Compute Group
  - Click the "Create compute group" button and fill in the required details.
- Create a Compute Instance
  - After creating the compute group, click the "Create compute instance" button and enter the necessary details to create the new compute instance.


# Detailed Version of Build Process

These are the high-level steps required to generate the Bare Metal RHEL service:
* Set up a Linux system with 20-40GB of free file system space for the build
* Set up a local file transfer/storage tool (E.g. **Local Web Server with HTTPS support**) that Bare Metal can reach over the network.
  * For **unsecured Web Server access**, please refer to the [Hosting](Hosting.md) for additional requirements, listed below:
    *  A. **HTTPS** with certificates signed by **publicly trusted Certificate authority**, and
    *  B. **Skip** the host’s **SSL certificate verification**.
  * For **Web Server running behind the Firewall**, the Web Server IP address and Port has to be whitelisted in the **rules** and **Proxy**.
* Install Git Version Control (git) and other ISO tools (xorriso and isomd5sum)
* Downloading recipe repo from GitHub
* Download a RHEL .ISO file
* Build the Bare Metal RHEL image/service

These are the high-level steps required to use this built Bare Metal RHEL service/image on Bare Metal:
* Copy the built Bare Metal RHEL .ISO image to your web server
* Add the Bare Metal RHEL .YML service file to the appropriate Bare Metal portal
* In Bare Metal, create a host using this RHEL image service

## Setup Linux system for imaging build

These instructions and scripts are designed to run on a Linux system.
Further, these instructions were developed and tested on a Ubuntu 20.04 VM, but they should work on other distros/versions.
The Linux host will need to have the following packages installed for these scripts to run correctly:

Packages      | Description
------------- | ---------------------
git           | a source code management tool.
xorriso       | a RockRidge filesystem manipulator, libburnia project.
isomd5sum     | utilities for working with md5sum implanted in ISO images.

On Ubuntu 20.04 VM, the necessary packages can be installed with:

```
sudo apt install git xorriso isomd5sum
```

> [!NOTE]  
> You must also have sudo (superuser do) capability so that you can mount the RHEL ISO
> and copy the files from it to generate a new RHEL .ISO file for Bare Metal.

The resulting RHEL .ISO image file from the build, needs to be uploaded to a web server that
the HPE On-Premises Controller can access over the network.  More about this later.

## Downloading recipe repo from GitHub

Once you have an appropriate Linux environment setup, then download this recipe from GitHub
for building the HPE Bare Metal RHEL by:

```
git clone https://github.com/HewlettPackard/hpegl-metal-os-rhel-iso.git
```

## Downloading RHEL .ISO file

Next, you will need to manually download the appropriate RHEL .ISO onto the Linux system.
This RHEL recipe has been successfully tested with the following list of RHEL distributions and its derivatives:
* RHEL 8.6
* RHEL 8.7
* RHEL 8.10
* RHEL 9.0
* RHEL 9.1
* RHEL 9.2
* RHEL 9.4
* RHEL 9.5
* Oracle Linux 8.6
* Oracle Linux 8.9
* Oracle Linux 9.3
* Oracle Linux 9.4
* Rocky Linux 8.8
* Rocky Linux 9.0

> [!NOTE]  
> This recipe should work on other RHEL or RHEL-based distros that support the same kickstart and .ISO construction as the recent version of RHEL.  
> **For Secure Boot, the user must have RHEL 9.1 or later.**

## Building the Bare Metal RHEL image and service

At this point, you should have a Linux system with:
* a copy of this repo
* a standard RHEL .ISO file

We are almost ready to do the build, but we need to know something about your environment.
When the build is done, it will generate two files:
* a Bare Metal modified RHEL .ISO file that needs to be hosted on a web server.
  It is assumed that you have (or can set up) a local web server that Bare Metal can reach over the network.
  You will also need login credentials on this Web Server so that you can upload the files.
* a Bare Metal service .YML file that will be used to add the RHEL service to the portal.
  This .YML file will have a URL to the Bare Metal modified RHEL .ISO file on the web server.

The build needs to know what URL can be used to download the Bare Metal modified RHEL .ISO file.
We assume that the URL can be broken into 2 parts: \<image-url-prefix\>/\<bare-metal-custom-rhel-iso\>

If the image URL can not be constructed with this simple mechanism, then you probably need to
customize this script for a more complex URL construction.

So you can run the build with the following command line parameters:

```
./glm-build-image-and-service.sh \
    -i <rhel-iso-filename> \
    -v <rhel-version-number> \
    -r <rhel-rootpw> \
    -p <image-url-prefix> \
    -o <rhel-baremetal-iso> \
    -s <rhel-baremetal-service-file>
```

When an RHEL host is created in the Bare Metal portal, the HPE On-Premises Controller will pull down this Bare Metal modified RHEL .ISO file.

### glm-build-image-and-service.sh - the top-level build script

This is the top-level build script that will take an RHEL install ISO and generate an RHEL service .yml file that can be imported as a Host OS into a Bare Metal portal.

This script 'glm-build-image-and-service.sh' does the following steps:
* process command line arguments.
* Customize the RHEL .ISO so that it works for Bare Metal.  Run: `glm-image-build.sh`
* Generate the Bare Metal service file for this Bare Metal image that we just generated. Run: `glm-service-build.sh`

Usage:

```
./glm-build-image-and-service.sh \
    -i <rhel-iso-filename> \
    -v <rhel-version-number> \
    -r <rhel-rootpw> \
    -p <image-url-prefix> \
    -o <rhel-baremetal-iso> \
    -s <rhel-baremetal-service-file>
```

Command Line Options                | Description
------------------------------------| -----------
-i \<rhel-iso-filename\>            | local filename of the standard RHEL .ISO file that was already downloaded. Used as input file.
-v \<rhel-version-number\>          | a x.y RHEL version number.  Example: -v 7.9
-r \<rhel-rootpw\>                  | clear-text password for the root user. <br> **_NOTE:_**  <br> 1. Later, this clear-text password is encrypted and the Service file (.yml) shows an encrypted password in the kick-start `/KS.cfg` file. <br> 2. This clear-test password will be visible in the build machine's command history. You may identify the command number you want to remove and then use `history -d` followed by the command number.
-o \<rhel-baremetal-iso\>           | local filename of the Bare Metal modified RHEL .ISO file that will be output by the script.  This file should be uploaded to your web server.
-p \<image-url-prefix\>             | the beginning of the image URL (on your web server). Example: -p https://10.152.3.96.
-s \<rhel-baremetal-service-file\>  | local filename of the Bare Metal .YML service file that will be output by the script.  This file should be uploaded to the Bare Metal portal.
-x \<skip-test>                     | [optional] skip the test with "-x true". <br> **_NOTE:_**  <br> By default, this script will run the test [glm-test-service-image.sh](glm-test-service-image.sh) script to verify that the upload was correct, and the size and checksum of the ISO match what is defined in the YML.

> [!NOTE]  
> The users of this script are expected to copy the \<rhel-baremetal-iso\> .ISO file to your web server
> such that the file is available at this constructed URL: \<image-url-prefix\>/\<rhel-baremetal-iso\>.
> The Bare Metal service .YML will assume that the image file will be available at a URL constructed with \<image-url-prefix\>/\<rhel-baremetal-iso\>.

### glm-image-build.sh - Customize RHEL.ISO for Bare Metal

This script `glm-image-build.sh` will repack an RHEL .ISO file for a Bare Metal RHEL install service that uses Virtual Media to
get the installation started.

The following changes are being made to the RHEL .ISO:
  1. configure to use a kickstart file on the iLO vmedia-cd and to pull the RPM packages (stage2) over vmedia
  2. setup for a text-based install (versus a GUI install)
  3. set up the console to the iLO serial port (/dev/ttyS1)
  4. eliminate the 'media check' when installing so that we get faster deployments (and parity with TGZ installs)

The RHEL .ISO is configured to use a kickstart file on the iLO vmedia-cd by adding the 'inst.ks=hd:sr0:/ks.cfg' option in
GRUB (used in UEFI) and isolinux (used in BIOS) configuration files. This option configures the RHEL installer to pull the
kickstart file from the root of the cdrom at /ks.cfg.  This kickstart option is setup by modifying the following files
on the .ISO:
  isolinux/isolinux.cfg for BIOS
  EFI/BOOT/grub.cfg for UEFI

Usage:
```
glm-image-build.sh \
    -i <rhel.iso> \
    -o <rhel-baremetal.iso>
```

Command Line Options            | Description
------------------------------- | -----------
-i \<rhel.iso\>                 | Input RHEL .ISO filename
-o \<rhel-baremetal.iso\>       | Output Bare Metal RHEL .ISO file

Example:

```
sudo ./glm-image-build.sh \
    -i RHEL-9.0.0-20220810.0-x86_64-HPE.iso \
    -o RHEL-9.0-BareMetal.iso
```

Here are the detailed changes that are made to the RHEL .ISO:
* change the default timeout to 5 seconds (instead of 60 seconds)
* change the default menu selection to the 1st entry (no media check)
* add the 'init.ks=hd:sr0:/ks.cfg' option to the various lines in the file
* also setup the serial console to ttyS1 (iLO serial port) with 115200 baud
* remove the 'quiet' option so the user can watch kernel loading and use to triage any problems

### glm-service-build.sh - Generate Bare Metal .YML service file

This script `glm-service-build.sh` generates a Bare Metal OS service .yml file appropriate for uploading to a Bare Metal portal(s).

Usage:
```
glm-service-build.sh \
    -s <service-template> \
    -o <service_yml_filename> \
    -c <svc_category> \
    -f <scv_flavor> \
    -v <svc_ver> \
    -d <display_url> \
    -u <secure_url> \
    -i <local_image_filename> [ -t <os-template> ]
```

Command Line Options        | Description
--------------------------- | -----------
-s \<service-template\>     | service template filename (input file)
-o \<service_yml_filename\> | service filename (output file)
-c \<svc_category\>         | the Bare Metal service category
-f \<scv_flavor\>           | the Bare Metal service flavor
-v \<svc_ver\>              | the Bare Metal service version
-d \<display_url\>          | used to display the image URL in the user interface
-u \<secure_url\>           | the real URL to the image file
-i \<local_image_filename\> | a full path to the image for this service. Used to get the .ISO sha256sum and size.
[ -t \<os-template\> ]      | info template files. 1st -t option should be %CONTENT1% in service-template. 2nd -> %CONTENT2%.

Example:
```
./glm-service-build.sh \
    -s /tmp/glm-service.cfg.5k70efrzd \
    -o RHEL-9.0-BareMetal.yml \
    -c linux \
    -f RHEL \
    -v 9.0-20240328-BYOI \
    -u https://10.152.3.96/images/RHEL-9.0-BareMetal.iso \
    -d RHEL-9.0.0-20220810.0-x86_64-HPE.iso \
    -i RHEL-9.0-BareMetal.iso \
    -t glm-kickstart.cfg.template \
    -t glm-cloud-init.template
```

### glm-test-service-image.sh - Verify the Bare Metal OS image

This script [glm-test-service-image.sh](glm-test-service-image.sh) will verify that the OS image referred to in a corresponding Bare Metal OS service. yml is correct.

Usage:
```
glm-test-service-image.sh <rhel-baremetal-service-file>
```

Command Line Options             | Description
-------------------------------- | -----------
\<rhel-baremetal-service-file\>  | service filename (output file)

Example:
```
./glm-test-service-image.sh RHEL-9.0-BareMetal.yml
```

# Customizing RHEL image

The RHEL image/service can be customized by:
* Modifying the way the image is built
* Modifying the RHEL kickstart file

## Modifying the way the image is built

Here is a description of the files in this repo:

Filename                       | Description
------------------------------ | -----------
README.md                      | This documentation file.
glm-build-image-and-service.sh | The top-level build script that takes an RHEL installation ISO and generates an RHEL service .yml file, which can then be imported as a Host OS into a Bare Metal portal.
glm-image-build.sh             | This script repacks the RHEL .ISO file to create a Bare Metal RHEL installation service that uses Virtual Media to initiate the installation process.
glm-service-build.sh           | This script generates a Bare Metal OS service .yml file, suitable for uploading the service to one or more Bare Metal portals.
glm-test-service-image.sh      | This script verifies the correctness of the OS image referenced in the corresponding Bare Metal OS service .yml file.
glm-kickstart.cfg.template     | The core RHEL kickstart file, templated with install-env-v1.
glm-service.yml.template       | The template for the Bare Metal .yml service file.
Hosting.md                     | This file contains additional requirements for the web server.

Please feel free to modify these files to meet your specific needs. Any general changes you'd like to contribute via a pull request are greatly appreciated.

## Modifying the RHEL kickstart file

The RHEL kickstart file is the basis of the automated install of RHEL supplied by this recipe.
Many additional changes to either of the kickstart files are possible to customize to your needs.

# Using the RHEL service and image

## Adding RHEL service to Bare Metal portal

When the build script completes successfully, you will find the following instructions to add this image to your HPE Bare Metal portal.

For example:

```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal RHEL service/image
| | that consists of the following 2 new files:
| |     RHEL-9.0-BareMetal.iso
| |     RHEL-9.0-BareMetal.yml
| |
| | To use this new Bare Metal RHEL service/image in the HPE Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (RHEL-9.0-BareMetal.iso)
| |     to your web server (https://10.152.3.96)
| |     such that the file can be downloaded from the following URL:
| |     https://10.152.3.96/images/RHEL-9.0-BareMetal.iso
| | (2) Add the Bare Metal Service file (RHEL-9.0-BareMetal.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Bare Metal Service file,
| |     sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

Follow the instructions as directed!

## Creating an RHEL Host with RHEL Service

Create a host in Bare Metal using this OS image service.

## Triage of image deployment problems

After you have created your custom RHEL image/server and created a host using this new service, you will want to monitor the deployment so for the first few times, make sure things are going as expected.
Here are some points to note:
  * This image/service is set to output to the serial console during RHEL deployment and watching the serial console is the easiest way to monitor the RHEL deployment/installation.
  * HPE GreenLake Metal tools do not monitor the serial port(s) at this time so if an error is generated by the RHEL installer, the Bare Metal tools will not know about it.
  * Sometimes for more difficult OS deployment problems you might want to gain access to the servers iLO so that you can monitor it that way. See your Bare Metal administrator.

## Known Observations and Limitations

<1> Host Readiness for User Login  
Once the host is successfully created, the Portal UI will display the state "Ready". However, the host operating system is still booting up in the background, which causes a delay of 5 to 10 minutes before the user can log in, either via the serial console or SSH.

## Troubleshooting

This section covers common problems and solutions for RHEL/Oracle Linux issues.  
<1> How to Login using Serial Console  
Linux kernels can output information including the login prompt to serial ports. Users can open the serial console window to log in to the host.  
Example for reference:   
```
Session established.
Connecting...
Connected.
     <<Press Enter to have Login Prompt>>
Oracle Linux Server 8.9
Kernel 5.15.0-200.131.27.el8uek.x86_64 on an x86_64
                                                                                                                                            
nb-ol8 login: root
Password:
Last login: Mon Aug 12 23:40:51 on ttyS1
[root@nb-ol8 ~]#
```
<2> The serial console can freeze and stop taking input.  
The user needs to access the host via SSH and run the following steps to resume the console access:  
A. Verify the following error footprints in the `/var/log/messages` log file: `getty@ttyS1.service: Failed with result 'start-limit-hit'.`  
B. Restart the service using the command: `systemctl restart  getty@ttyS1.service`  
C. Verify the `active (running)` status of this systemd service `getty@ttyS1.service`  
In case the user can't log in via SSH, please do a graceful host reboot.  
Note: The user may refer to a relevant issue on RedHat Customer Portal: https://access.redhat.com/solutions/7004165 

## OS License

RHEL is a licensed software and users need to have a valid license key from RedHat to use RHEL.
This install service does nothing to set up an RHEL license key in any way.
Users are expected to manually use RHEL tools to set up an RHEL license on the host.

## Storage Volumes iSCSI and FC

When a Bare Metal host is set up with iSCSI or FC volumes, the storage volume should be automatically available.
