#!/bin/bash

# ./scripts/bump-version.sh <new version>
# eg ./scripts/bump-version.sh "3.0.0-alpha.1"

set -eux

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

NEW_VERSION="$1"

# Replace `paylisherVersion` with the given version
perl -pi -e "s/paylisherVersion = \".*\"/paylisherVersion = \"$NEW_VERSION\"/" Paylisher/PaylisherVersion.swift

# Replace `s.version` with the given version
perl -pi -e "s/s.version          = \".*\"/s.version          = \"$NEW_VERSION\"/" Paylisher.podspec
