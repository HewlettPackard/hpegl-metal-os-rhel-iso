<!-- (C) Copyright 2024 Hewlett Packard Enterprise Development LP -->

RHEL/Oracle Linux Bring Your Own Image (BYOI) for HPE Private Cloud Enterprise - Bare Metal
=============================

* [Overview](#overview)
* [Example of manual build for reference](#example-of-manual-build-for-reference)
* [Building RHEL image](#building-rhel-image)
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
  *   [RHEL License](#rhel-license)
  *   [Known Observations/Issues](#known-observations-and-issues)
  *   [OS License](#os-license)
  *   [Storage Volumes iSCSI and FC](#storage-volumes-iscsi-and-fc)


----------------------------------

# Overview

This GitHub repository contains the script files, template files, and documentation for creating an RHEL service for HPE Bare Metal from an RHEL install .ISO file.  By building a custom image via this process, you can control the exact version of RHEL that is used and modify how RHEL is installed via a kickstart file.  Once the build is done, you can add your new service to the HPE Bare Metal Portal and deploy a host with that new image.

> [!IMPORTANT]  
> **This RHEL recipe has been shown to work with Red Hat Enterprise Linux (RHEL), Oracle Linux (OL), and Rocky Linux.**

# Example of manual build for reference

Workflow for Building Image:

![image](https://github.com/HewlettPackard/hpegl-metal-os-rhel-iso/assets/90067804/e2a198c4-96f1-4c1c-8fa0-4ac8c730857e)


Prerequisites:
```
1. You will need a Web Server with HTTPS support for storage of the HPE Base Metal images.  The Web Server is anything that:
   A. You have the ability to upload large .ISO image to and
   B. The Web Server must be on a network that will be reachable from the HPE On-Premises Controller.  When an OS service/image is used to create an HPE Bare Metal Host the OS images will be downloaded via the secure URL in the service file.
   NOTE: For this manual build example, a local Web Server "https://<web-server-address>" is used for OS image storage.  For this example, we are assuming that the HPE Bare Metal OS images will be kept in: https://<web-server-address>/images/<.iso>.
2. Linux machine for building OS image
   A. Ubuntu 20.04.6 LTS
   B. Install supporting tools (git, xorriso, and isomd5sum)
```

Step 1. Source code readiness

A. Clone the GitHub Repo `hpegl-metal-os-rhel-iso`
```
git clone https://github.com/HewlettPackard/hpegl-metal-os-rhel-iso.git
```
B. Change the directory to `hpegl-metal-os-rhel-iso`

Step 2. Download the RHEL .ISO image to your local build environment via what ever method you prefer (Web Browser, etc)

For example, we will assume that you have downloaded RHEL-9.0.0-20220810.0-x86_64-HPE.iso into the local directory.

Step 3. Run the script `glm-build-image-and-service.sh` to generate an output Bare Metal image .ISO as well as Bare Metal Service .yml:

Example:
```
./glm-build-image-and-service.sh \
  -v 9.0 \
  -p https://10.152.2.125 \
  -r qPassw0rd \
  -i RHEL-9.0.0-20220810.0-x86_64-HPE.iso \
  -o RHEL-9.0-BareMetal.iso \
  -s RHEL-9.0-BareMetal.yml
```

Example test result for reference:
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
| |     to your web server (https://10.152.2.125)
| |     such that the file can be downloaded from the following URL:
| |     https://10.152.2.125/images/RHEL-9.0-BareMetal.iso
| | (2) Use the script "glm-test-service-image.sh" to test that the HPE Bare Metal service
| |     .yml file points to the expected OS image on the web server with the expected OS image
| |     size and signature.
| | (3) Add the Bare Metal Service file (RHEL-9.0-BareMetal.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe-gl-intg.com/). To add the HPE Bare Metal Service file,
| |     sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| | (4) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

Step 4. Copy the output Bare Metal image .ISO to the Web Server.

Step 5. Run the script `glm-test-service-image.sh`, which will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct:
> [!NOTE]  
> This script will verify that it can download the OS image and check its length (in bytes) and signature.
> The script simulates what HPE On-Premises Controller will do when it tries to download and verify an OS image.
> If this script fails then the Bare Metal OS service .yml file is most likely broken and will not work if loaded into Bare Metal.

Example:
```
./glm-test-service-image.sh RHEL-9.0-BareMetal.yml
```

Test result example for reference:

```
$ ./glm-test-service-image.sh RHEL-9.0-BareMetal.yml
OS image file to be tested:
  Secure URL: https://<web-server-address>/images/RHEL-9.0-BareMetal.iso
  Display URL: RHEL-9.0.0-20220810.0-x86_64-HPE.iso
  Image size: 8484028416
  Image signature: ca6235cfb2734bdea71fc3794a32f8b3c71bbc019d15e274e271de668ccc86f1
  Signature algorithm: sha256sum

wget -O /tmp/os-image-M9V0GR.img https://10.152.2.125/images/RHEL-9.0-BareMetal.iso
--2024-03-28 17:26:47--  https://10.152.2.125/images/RHEL-9.0-BareMetal.iso
Connecting to 10.152.2.125:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 8484028416 (7.9G) [application/x-iso9660-image]
Saving to: ‘/tmp/os-image-M9V0GR.img’

/tmp/os-image-M9V0GR.img                            100%[=================================================================================================================>]   7.90G  85.6MB/s    in 89s

2024-03-28 17:28:16 (90.8 MB/s) - ‘/tmp/os-image-M9V0GR.img’ saved [8484028416/8484028416]

Image Size has been verified ( 8484028416 bytes )
Image Signature has been verified ( ca6235cfb2734bdea71fc3794a32f8b3c71bbc019d15e274e271de668ccc86f1 )
The OS image size and signature have been verified
```

Step 6. Add the Bare Metal service .yml file to the appropriate Bare Metal portal.

To add the Bare Metal service .yml file, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
Select the Dashboard tile "Metal Consumption" and click on the "OS/application images" tab.
Click on the button "Add OS/application image" to upload this service .yml file.

Step 7. Create a new Bare Metal host using this OS image service.

To create a new Bare Metal host, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
Select the Dashboard tile "Metal Consumption" and click on the tab "Compute groups". Further, create a host using the following steps:
a. First, create a Compute Group by clicking the "Create compute group" button and fill in the details.
b. Create a Compute Instance by clicking the "Create compute instance" button and fill in the details.


# Building RHEL image

These are the high-level steps required to generate the Bare Metal RHEL service:
* Set up a Linux system with 20-40GB of free file system space for the build
* Set up a local file transfer/storage tool (E.g. Local Web Server with HTTPS support) that Bare Metal can reach over the network.
  * See [Hosting](Hosting.md) file for additional requirements on the web server.
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
* RHEL 9.0
* RHEL 9.1
* RHEL 9.2
* Oracle Linux 8.6
* Oracle Linux 8.9
* Oracle Linux 9.3
* Rocky Linux 8.8

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
-o \<rhel-baremetal-iso\>           | local filename of the Bare Metal modified RHEL .ISO file that will be output by the script.  This file should be uploaded to your web server.
-p \<image-url-prefix\>             | the beginning of the image URL (on your web server). Example: -p https://10.152.2.125.
-s \<rhel-baremetal-service-file\>  | local filename of the Bare Metal .YML service file that will be output by the script.  This file should be uploaded to the Bare Metal portal.

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
    -u https://10.152.2.125/images/RHEL-9.0-BareMetal.iso \
    -d RHEL-9.0.0-20220810.0-x86_64-HPE.iso \
    -i RHEL-9.0-BareMetal.iso \
    -t glm-kickstart.cfg.template \
    -t glm-cloud-init.template
```

### glm-test-service-image.sh - Verify the Bare Metal OS image

This script `glm-test-service-image.sh` will verify that the OS image referred to in a corresponding Bare Metal OS service. yml is correct.

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
README.md                      | This documentation
glm-build-image-and-service.sh | This is the top-level build script that will take an RHEL install ISO and generate an RHEL service .yml file that can be imported as a Host OS into a Bare Metal portal.
glm-image-build.sh             | This script will repack the RHEL .ISO file for a Bare Metal RHEL install service that uses Virtual Media to get the installation started.
glm-service-build.sh           | This script generates a Bare Metal OS service .yml file appropriate for uploading the service to a Bare Metal portal(s).
glm-test-service-image.sh      | This script will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct.
glm-kickstart.cfg.template     | The core RHEL kickstart file (templated with install-env-v1)
glm-service.yml.template       | This is the Bare Metal .YML service file template.

Feel free to modify these files to suit your specific needs.
General changes that you want to contribute back via a pull request are much appreciated.

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
| |     to your web server (https://10.152.2.125)
| |     such that the file can be downloaded from the following URL:
| |     https://10.152.2.125/images/RHEL-9.0-BareMetal.iso
| | (2) Use the script "glm-test-service-image.sh" to test that the HPE Bare Metal service
| |     .yml file points the expected OS image on the web server with the expected OS image
| |     size and signature.
| | (3) Add the Bare Metal Service file (RHEL-9.0-BareMetal.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe-gl-intg.com/). To add the HPE Bare Metal Service file,
| |     sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| | (4) Create a Bare Metal host using this OS image service.
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

## Known Observations and Issues

<1> For Oracle Linux  
**About Issue:** Services (sshd/cloud-init) found inactive. This results into an error `sshd: no hostkeys available -- exiting` and User can not SSH to the host.  
**About Fix:** Reboot the Host once. Reboot will bring up the host with active sshd services and required host keys.  
**Reference file:** '/etc/systemd/system/sshd-keygen@.service.d/disable-sshd-keygen-if-cloud-init-active.conf'  
```
# In some cloud-init enabled images the sshd-keygen template service may race with cloud-init
# during boot causing issues with host key generation.  This drop-in config adds a condition
# to sshd-keygen@.service if it exists and prevents the sshd-keygen units from running
# *if* cloud-init is going to run.
[Unit]
ConditionPathExists=!/run/systemd/generator.early/multi-user.target.wants/cloud-init.target
```

## OS License

RHEL is a licensed software and users need to have a valid license key from RedHat to use RHEL.
This install service does nothing to set up an RHEL license key in any way.
Users are expected to manually use RHEL tools to set up an RHEL license on the host.

## Storage Volumes iSCSI and FC

When a Bare Metal host is set up with iSCSI or FC volumes, the storage volume should be automatically available.
