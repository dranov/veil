#!/bin/sh
# Usage: profile-file.sh [--quiet] file.lean [output.json] [parser options...]
exec python3 "$(dirname "$0")/profile.py" file "$@"
