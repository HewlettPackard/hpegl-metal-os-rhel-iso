#!/bin/bash
# (C) Copyright 2018-2022 Hewlett Packard Enterprise Development LP

# This is the top level build script will take a RHEL install ISO and
# generate a RHEL service.yml file the can be imported as a Host OS into
# a GreenLake Metal portal.

# glm-build-image-and-service.sh does the following steps:
# * process command line arguements.
# * Customize the RHEL .ISO so that it works for GLM.  Run: glm-image-build.sh.
# * Generate GLM service file that is specific to $RHEL_VER. Run: glm-service-build.sh.

# glm-build-image-and-service.sh usage:
# glm-build-image-and-service.sh -i <rhel-iso-filename> -o <glm-custom-rhel-iso>
#    -v <rhel-version-number> -p <image-url-prefix> -s <glm-yml-service-file>

# command line options       | Description
# -------------------------- | -----------
# -i <rhel-iso-filename>     | local filename of the standard RHEL .ISO file
#                            | that was already downloaded. Used as input file.
# -------------------------- | -----------
# -v <rhel-version-number>   | a x.y RHEL version number.  Example: -v 7.9
# -------------------------- | -----------
# -o <glm-custom-rhel-iso>   | local filename of the GLM-modified RHEL .ISO file
#                            | that will be output by the script.  This file should
#                            | be uploaded to your web server.
# -------------------------- | -----------
# -p <image-url-prefix>      | the beginning of the image URL (on your web server).
#                            | Example: -p http://192.168.1.131.  The GLM service .YML
#                            | will assume that the image file will be available at
#                            | a URL constructed with <image-url-prefix>/<glm-custom-rhel-iso>.
# -------------------------- | -----------
# -s <glm-yml-service-file>  | local filename of the GLM .YML service file that
#                            | will be output by the script.  This file should
#                            | be uploaded to the GLM portal.
# -------------------------- | -----------

# NOTE: The user's of this script are expected to copy the
# <glm-custom-rhel-iso> .ISO file to your web server such
# that the file is available at this constructed URL:
# <image-url-prefix>/<glm-custom-rhel-iso>

# If the image URL can't not be constructed with this
# simple mechanism then you probably need to customize
# this script for a more complex URL costruction.

# This script calls glm-image-build.sh, which needs the
# following packages to be installed:
#
# on Debian/Ubuntu:
#  sudo apt install genisoimage isomd5sum syslinux-utils

set -euo pipefail

# required parameters
RHEL_ISO_FILENAME=""
GLM_CUSTOM_RHEL_ISO=""
RHEL_VER=""
IMAGE_URL_PREFIX=""
GLM_YML_SERVICE_FILE=""
GLM_YML_SERVICE_TEMPLATE=""

while getopts "i:v:o:p:s:" opt
do
    case $opt in
        # required parameters
        i) RHEL_ISO_FILENAME=$OPTARG ;;
        v) RHEL_VER=$OPTARG ;;
        o) GLM_CUSTOM_RHEL_ISO=$OPTARG ;;
        p) IMAGE_URL_PREFIX=$OPTARG ;;
        s) GLM_YML_SERVICE_FILE=$OPTARG ;;
     esac
done

# Check that required parameters exist.
if [ -z "$RHEL_ISO_FILENAME" -o \
     -z "$GLM_CUSTOM_RHEL_ISO" -o \
     -z "$RHEL_VER" -o \
     -z "$IMAGE_URL_PREFIX" -o \
     -z "$GLM_YML_SERVICE_FILE" ]; then
  echo "script usage: $0 -i rhel-iso -v rhel-version" >&2
  echo "              -o glm-custom-rhel-iso -p http-prefix -s glm-yml-service-file" >&2
  exit 1
fi

if [[ ! -f $RHEL_ISO_FILENAME ]]; then
  echo "ERROR missing ISO image file $RHEL_ISO_FILENAME"
  exit 1
fi

# The clean function cleans up any lingering files
# that might be present when the script exits.
clean() {
  if [ ! -z "$GLM_YML_SERVICE_TEMPLATE" ]; then
    rm -f $GLM_YML_SERVICE_TEMPLATE
  fi
}

trap clean EXIT

# if the GLM customizied RHEL .ISO has not aleady been generated.
if [ ! -f $GLM_CUSTOM_RHEL_ISO ]; then
   # Customize the RHEL .ISO so that it works for GLM.
   GEN_IMAGE="sudo ./glm-image-build.sh \
      -i $RHEL_ISO_FILENAME \
      -o $GLM_CUSTOM_RHEL_ISO"
   echo $GEN_IMAGE
   $GEN_IMAGE
fi

GLM_YML_SERVICE_TEMPLATE=$(mktemp /tmp/glm-service.cfg.XXXXXXXXX)
sed -e "s/RHEL_VERSION/$RHEL_VER/g" glm-service.yml.template > $GLM_YML_SERVICE_TEMPLATE

# Generate HPE GLM service file.
YYYYMMDD=$(date '+%Y%m%d')
GEN_SERVICE="./glm-service-build.sh \
  -s $GLM_YML_SERVICE_TEMPLATE \
  -o $GLM_YML_SERVICE_FILE \
  -c linux \
  -f RHEL \
  -v $RHEL_VER-$YYYYMMDD-BYOI \
  -u $IMAGE_URL_PREFIX/$GLM_CUSTOM_RHEL_ISO
  -d $RHEL_ISO_FILENAME \
  -i $GLM_CUSTOM_RHEL_ISO \
  -t glm-kickstart.cfg.template \
  -t glm-cloud-init.template"
echo $GEN_SERVICE
$GEN_SERVICE

# print out instructions for using this image & service
cat << EOF
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new GreenLake Metal (GLM) RHEL service/image
| | that consists of the following 2 new files:
| |     $GLM_CUSTOM_RHEL_ISO
| |     $GLM_YML_SERVICE_FILE
| |
| | To use this new GLM RHEL service/image in HPE GLM take the following steps:
| | (1) Copy the new .ISO file ($GLM_CUSTOM_RHEL_ISO)
| |     to your web server ($IMAGE_URL_PREFIX)
| |     such that the file can be downloaded from the following URL:
| |     $IMAGE_URL_PREFIX/$GLM_CUSTOM_RHEL_ISO
| | (2) Add the GreenLake Metal Service file to your GLM Portal using this command:
| |     qctl services create -f $GLM_YML_SERVICE_FILE
| | (3) Create a host in GLM using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
EOF

exit 0
