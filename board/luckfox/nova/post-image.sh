#!/bin/sh
# Assemble the final sdcard.img with genimage.
set -e

BOARD_DIR="$(dirname "$0")"

support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"
