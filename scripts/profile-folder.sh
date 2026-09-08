#!/bin/sh
# Usage: profile-folder.sh [folder] [output-directory] [parser options...]
exec python3 "$(dirname "$0")/profile.py" folder "$@"
