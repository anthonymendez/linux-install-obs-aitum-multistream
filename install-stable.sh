#!/usr/bin/env bash
export RELEASE_TYPE="stable"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DIR/install.sh" ]; then
    exec "$DIR/install.sh" "$@"
else
    exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonymendez/linux-install-obs-aitum-multistream/main/install.sh)" -- "$@"
fi
