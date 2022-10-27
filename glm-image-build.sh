#!/bin/bash
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
#
# This script will repack RHEL .ISO file for a GLM
# RHEL install service that uses Virtual Media
# to get the install started.

# The following changes are being made to the RHEL .ISO:
#   (1) configure to use a kickstart file on the iLO vmedia-cd and to
#       pull the RPM packages (stage2) over vmedia
#   (2) setup for a text based install (versus a GUI install)
#   (3) set up the console to the iLO serial port (/dev/ttyS1)
#   (4) eliminate the 'media check' when installing so that
#       we get faster deployments (and parity with TGZ installs)

# The RHEL .ISO is configured to use a kickstart file on the iLO
# vmedia-cd by adding the 'inst.ks=hd:sr0:/ks.cfg' option in
# GRUB (used in UEFI) and isolinux (used in BIOS) configuration
# files. This option configures RHEL installer to pull the
# kickstart file from the root of the cdrom at /ks.cfg.  This
# kickstart option is setup by modifying the following files
# on the .ISO:
#   isolinux/isolinux.cfg for BIOS
#   EFI/BOOT/grub.cfg for UEFI

# For additional information, see:
# 2. WORKING WITH ISO IMAGES
#  https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/anaconda_customization_guide/sect-iso-images
# Red Hat 7.4: How to inject kickstart file into USB media for UEFI-only system?
#  https://unix.stackexchange.com/questions/418974/red-hat-7-4-how-to-inject-kickstart-file-into-usb-media-for-uefi-only-system
#  https://github.com/Fauxsys/Erratum/blob/master/unattended.sh
# Specify a kickstart file presented by an HP ILO Virtual cdrom
#  https://community.hpe.com/t5/Server-Management-Remote-Server/iLO-can-t-find-the-virtual-floppy-with-kickstart-file/td-p/7079159#.YIIlFuhKjuo
#  https://access.redhat.com/solutions/345053
# How to create a modified Red Hat Enterprise Linux ISO with kickstart file or modified installation media?
#  https://access.redhat.com/solutions/60959
# Chapter 23 Boot Options
#  https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/chap-anaconda-boot-options
# How to create a custom ISO image from RHEL 7 ISO using genisoimage ?
#  https://leadwithoutatitle.wordpress.com/2019/01/17/how-to-create-a-custom-iso-image-from-rhel-7-iso-using-genisoimage/

# Usage:
#  glm-image-customize-rhel-iso.sh -i <rhel.iso> -o <glm-customizied-rhel.iso>

# command line options          | Description
# ----------------------------- | -----------
# -i <rhel.iso>                 | Input RHEL .ISO filename
# -o <glm-customizied-rhel.iso> | Output GLM RHEL .ISO file

set -exuo pipefail

# make sure we have enough permissions to mount .iso, etc
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit -1
fi

# check to make sure we have the required tools called within this script
for i in xorriso implantisomd5
do
  which $i > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo "$i not found. Please install."
    exit -1
  fi
done

UEFI_ORIG_CFG_FILE=""
INPUT_ISO_FILENAME=""
CUSTOM_ISO_FILENAME=""
# parse command line parameters
while getopts "i:o:" opt
do
    case $opt in
        i) INPUT_ISO_FILENAME=$OPTARG
            if [[ ! -f $INPUT_ISO_FILENAME ]]
            then
                echo "ERROR missing image file $INPUT_ISO_FILENAME"
                exit -1
            fi
            ;;
        o) CUSTOM_ISO_FILENAME=$OPTARG ;;
    esac
done

if [ -z "$INPUT_ISO_FILENAME" -o -z "$CUSTOM_ISO_FILENAME" ]; then
   echo "Usage: $0 -i <rhel.iso> -v <version> -o <glm-customizied-rhel.iso>"
   exit 1
fi

# Generate unique ID for use as the uploaded file name.
ID=$RANDOM
YYYYMMDD=$(date '+%Y%m%d')

UEFI_CFG_FILE=EFI/BOOT/grub.cfg

xorriso -osirrox on -indev $INPUT_ISO_FILENAME -extract ${UEFI_CFG_FILE} ${UEFI_CFG_FILE}

if [ ! -f "${UEFI_CFG_FILE}" ]; then
  echo "did not find ${UEFI_CFG_FILE} on <sles-iso-filename>"
  exit -1
fi

# Make the extracted file writable (xorriso makes it read-only when extracted)
chmod -R u+w EFI

# The clean function cleans up any lingering files
# that might be present when the script exits.
clean() {
  # remove entire $UEFI_CFG_FILE directory & files
  if [ -d "EFI" ]; then
     rm -rf EFI
  fi
}

trap clean EXIT

if [ ! -f "${UEFI_CFG_FILE}" ]; then
  echo "did not find ${UEFI_CFG_FILE} on <rhel-iso-filename>"
  exit -1
fi

# save the original grub.cfg files
UEFI_ORIG_CFG_FILE=$(mktemp /tmp/grub.cfg.XXXXXXXXX)
cp ${UEFI_CFG_FILE} $UEFI_ORIG_CFG_FILE

###################################################
# start the UEFI_CFG_FILE file modifications

# change the default timeout to 5 seconds (instead of 60 seconds)
sed -i "s/^set timeout=.*$/set timeout=5/" ${UEFI_CFG_FILE}

# change the default menu selection to the 1st entry (no media check)
sed -i "s/^set default=.*$/set default=\"0\"/" ${UEFI_CFG_FILE}

# add the 'init.ks=hd:sr0:/ks.cfg' option to the various lines in the file
# also setup the serial console to ttyS1 (iLO serial port) with 115200 baud
sed -i -E "s/(.*)(hd:LABEL=\S+)(.*)/\1\2 inst.ks=hd:sr0:\/ks.cfg console=ttyS1,115200 inst.text \3/" ${UEFI_CFG_FILE}

# remove the 'quiet' option so the user can watch kernel loading
# and use to triage any problems
sed -i "s/quiet//" ${UEFI_CFG_FILE}

# report on the changes to isolinux.org
echo "===================================================="
echo diff -u $UEFI_ORIG_CFG_FILE ${UEFI_CFG_FILE}
set +e
diff -u $UEFI_ORIG_CFG_FILE ${UEFI_CFG_FILE}
set -e
echo "===================================================="

# end the UEFI_CFG_FILE file modifications
###################################################

# Create the RHEL .ISO file

echo
echo Creating ${CUSTOM_ISO_FILENAME}

# Create new ISO file with modified CFG
xorriso -indev $INPUT_ISO_FILENAME -outdev ${CUSTOM_ISO_FILENAME} -boot_image isohybrid keep -update ${UEFI_CFG_FILE} ${UEFI_CFG_FILE}

# Implant an MD5 checksum into the image. Without performing this step,
# image verification check (the rd.live.check option in the boot
# loader configuration) will fail and you will not be able to continue
# with the installation.
MD5_ISO="implantisomd5 ${CUSTOM_ISO_FILENAME}"
echo $MD5_ISO
$MD5_ISO
