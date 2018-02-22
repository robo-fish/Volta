#!/bin/bash
# 
################################################################################
# This file is part of the Volta project.
# Copyright (C) 2007-2013 Kai Berk Oezer
# https://robo.fish/wiki/index.php?title=Volta
# https://github.com/robo-fish/Volta
# 
# Volta is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# 
################################################################################
# Testing this script:
#
# 1) Make sure that /Applications/Volta.app exists.
#
# 2) Issue following commands in Terminal
#
#      pushd /Users/
#      ../Volumes/Volta/work/scripts/CreateDiskImage.sh "" "1.1.2"
#      
# 3) Clean up
#
#      diskutil eject /Volumes/Volta\ 1.1.2
#      rm ~/Desktop/Volta-1.1.2.dmg
#
################################################################################


if [ $# -lt 2 ]; then
  echo "`basename $0`: Expected the build products folder path and the version string.";
  exit 1
fi

if [ ! -d $1 ]; then
  echo "`basename $0`: \"$1\" is not a valid folder path.";
  exit 1
fi

VOLTA_SCRIPT_DIR=`dirname $0`
VOLTA_DISTRO_NAME="Volta "$2
VOLTA_DISK_IMAGE_DIR="$HOME/Desktop"
VOLTA_DISK_IMAGE_FINAL_NAME="Volta-"$2".dmg"
VOLTA_DISK_IMAGE_FINAL_PATH="${VOLTA_DISK_IMAGE_DIR}/${VOLTA_DISK_IMAGE_FINAL_NAME}"
VOLTA_DISK_IMAGE_TEMP_NAME="Volta-"$2"-tmp.dmg"
VOLTA_DISK_IMAGE_TEMP_PATH="${VOLTA_DISK_IMAGE_DIR}/${VOLTA_DISK_IMAGE_TEMP_NAME}"
VOLTA_DISTRO_VOLUME_PATH="/Volumes/${VOLTA_DISTRO_NAME}"
VOLTA_APP_BUNDLE_PATH="$1/Applications/Volta.app"
BACKGROUND_IMAGE_FILE_NAME="background.png"


if [ -e "$VOLTA_DISTRO_VOLUME_PATH" ]; then
  echo "`basename $0`: \"$VOLTA_DISTRO_VOLUME_PATH\" already exists.";
  exit 1
fi

if [ -e "$VOLTA_DISK_IMAGE_TEMP_PATH" ]; then
  echo "`basename $0`: \"$VOLTA_DISK_IMAGE_TEMP_PATH\" already exists.";
  exit 1
fi

echo "`basename $0`: Creating distribution disk image..."

hdiutil create -volname "$VOLTA_DISTRO_NAME" -size 10m -fs HFS+J -nospotlight "$VOLTA_DISK_IMAGE_TEMP_PATH" -attach

if [ ! -d "$VOLTA_DISTRO_VOLUME_PATH" ]; then
  echo "`basename $0`: Could not find mounted disk image at \"$VOLTA_DISTRO_VOLUME_PATH\"";
  exit 1
fi

cp -R "$VOLTA_APP_BUNDLE_PATH" "${VOLTA_DISTRO_VOLUME_PATH}/"
cp -R "${VOLTA_SCRIPT_DIR}/${BACKGROUND_IMAGE_FILE_NAME}" "${VOLTA_DISTRO_VOLUME_PATH}/"

sync

osascript "${VOLTA_SCRIPT_DIR}/SetDiskImageViewProperties.scpt" "$VOLTA_DISTRO_NAME" "$VOLTA_DISTRO_VOLUME_PATH" "$BACKGROUND_IMAGE_FILE_NAME"

setfile -a V "${VOLTA_DISTRO_VOLUME_PATH}/${BACKGROUND_IMAGE_FILE_NAME}"

chmod -Rf go-w "$VOLTA_DISTRO_VOLUME_PATH"

sync

hdiutil detach "$VOLTA_DISTRO_VOLUME_PATH"
hdiutil convert "$VOLTA_DISK_IMAGE_TEMP_PATH" -format UDZO -imagekey zlib-level=9 -o "$VOLTA_DISK_IMAGE_FINAL_PATH"
rm -f "$VOLTA_DISK_IMAGE_TEMP_PATH"

open "$VOLTA_DISK_IMAGE_FINAL_PATH"
osascript -e "tell application \"Finder\" to activate"

echo "`basename $0`: Done."

exit 0
