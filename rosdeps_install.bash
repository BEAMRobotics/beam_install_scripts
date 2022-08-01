#!/bin/bash
set -e

ROSPACKAGES_DIR="$REPO_DIR/rospackages"

# Add Dataspeed packages
echo "Setting up Dataspeed apt and rosdep repositories"
bash <(wget -q -O - https://bitbucket.org/DataspeedInc/ros_binaries/raw/default/scripts/setup.bash)

rosdep update >/dev/null
