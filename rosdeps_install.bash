#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# get UBUNTU_CODENAME, ROS_DISTRO, REPO_DIR, CATKIN_DIR
source $SCRIPT_DIR/identify_environment.bash

ROSPACKAGES_DIR="$REPO_DIR/rospackages"

# Add Dataspeed packages
echo "Setting up Dataspeed apt and rosdep repositories"
bash <(wget -q -O - https://bitbucket.org/DataspeedInc/ros_binaries/raw/default/scripts/setup.bash)

rosdep update > /dev/null

# Install system dependencies listed in ROS packages' package.xml
# Note: dependencies needed on embedded systems must still be included
# separately in the repo or cross-compiled stage.
if [ -d "$ROSPACKAGES_DIR" ]; then
    # we have a source stack distro
    echo One
    echo $CATKIN_DIR
    rosdep install -qry --from-paths $CATKIN_DIR/src/ --ignore-src
else
    # we have a binary stack distro
    echo Two
    echo $REPO_DIR
    rosdep install -qry --from-paths $REPO_DIR --ignore-src
fi
