#!/bin/bash
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP

# This script will verify that the OS image referred to
# in a corresponding Bare Metal OS service.yml is correct. This script will verify that it can
# download the OS image and check its length (in bytes) and signature. The script simulates what
# On-Premises Controller will do when it tries to download and verify an OS image.
# If this script fails then the service.yml file is most likely broken and will not work
# if loaded into the HPE Bare Metal Portal.

# Ways to use this script:
# * glm-test-service-image.sh RHEL-9.0-BareMetal.yml

set -eou pipefail

# The clean function cleans up any lingering files
# data that might be present when the script exits.
clean() {
  rm -f ${LOCAL_IMAGE_FILENAME}
}

# Set a trap to call the clean function on exit
trap clean EXIT

usage() {
cat << EOF
script usage: $0 <service.yml>
EOF
}

# check command line arguments
if [[ $# -lt 1 ]]; then
  echo "bad command line args"
  usage
  exit 1
fi

# These are the lines that we are interested in from the service.yml file:
# For Example:
#   secure_url: "http://192.168.1.131/Windows_Server2019_custom-hpe-glm-20230123-29234.tar"
#   display_url: "Windows_Server2019_custom.iso"
#   file_size: 5360998400
#   signature: "750db9d2434faefd1cf2ec1b0f219541b594efa1a99202775e2e6431582ab4bf"
#   algorithm: sha256sum
eval "$(grep -E "file_size:|display_url:|secure_url:|signature:|algorithm:" "$*" | sed -e "s/^ *//" -e "s/: */=/")"

# Check that required parameters exist.
# Allow $display_url to be optional.
if [ -z ${file_size} ] || [ -z ${display_url} ] || [ -z ${secure_url} ] || [ -z ${file_size} ] || [ -z ${algorithm} ] || [ -z ${signature} ]; then
  usage
  exit 1
fi

# print the image description that we found
echo -e "\nOS image file to be tested:"
echo "  Secure URL: ${secure_url}"
echo "  Display URL: ${display_url}"
echo "  Image size: ${file_size}"
echo "  Image signature: ${signature}"
echo "  Signature algorithm: ${algorithm}"

# make sure we have the tool for $algorithm
which "$algorithm" > /dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "ERROR $algorithm not found. Please install."
  exit 1
fi

# make temp filename
LOCAL_IMAGE_FILENAME="$(mktemp /tmp/os-image-XXXXXX.img)"

# download the image from the source (Web Server, AWS S3, etc)
# ======================================================================
# Note: You may use "--no-check-certificate" for Self-signed certificate
echo -e "\nDownload the image from the source:"
args=(
  --no-proxy #optional parameter
  --no-check-certificate #optional parameter
)
DOWNLOAD="wget                                   \
${args[*]} `#add parameters from the list above` \
-O ${LOCAL_IMAGE_FILENAME} ${secure_url}"
echo "$DOWNLOAD"
$DOWNLOAD
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR wget failed to download image"
  exit 1
fi

# Verify image file exists
stat ${LOCAL_IMAGE_FILENAME} > /dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR Image file ${LOCAL_IMAGE_FILENAME} not found."
  exit 1
fi

# Get file size
SIZE=$(stat -L -c "%s" "$LOCAL_IMAGE_FILENAME")

# Check file size
if [ "$SIZE" -ne "$file_size" ]; then
  echo "ERROR file size error. expected ${file_size} got ${SIZE}"
  exit 1
fi
echo "Test 1: Image size has been verified ( ${SIZE} bytes )"

# Calculate checksum
SUM=$($algorithm $LOCAL_IMAGE_FILENAME | sed "s/ .*//")

echo
# Check checksum
if [ "$SUM" != "$signature" ]; then
  echo "ERROR file checksum error. expected ${signature} got ${SUM}"
  exit 1
fi
echo "Test 2: Image signature has been verified ( ${SUM} )"

# success
echo "SUCCESS! The OS image size and signature have been verified"

# remove the temp file
clean
