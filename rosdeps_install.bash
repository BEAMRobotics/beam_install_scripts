#!/bin/bash
set -e

ROSPACKAGES_DIR="$REPO_DIR/rospackages"

# Add Dataspeed packages
echo "Setting up Dataspeed apt and rosdep repositories"
bash <(wget -q -O - https://bitbucket.org/DataspeedInc/ros_binaries/raw/default/scripts/setup.bash)

rosdep update >/dev/null

# Install system dependencies listed in ROS packages' package.xml
# Note: dependencies needed on embedded systems must still be included
# separately in the repo or cross-compiled stage.
#if [ -d "$ROSPACKAGES_DIR" ]; then
#    # we have a source stack distro
#    rosdep install -qry --from-paths $CATKIN_DIR/src/ --ignore-src
#else
#    # we have a binary stack distro
#    rosdep install -qry --from-paths $REPO_DIR --ignore-src
#fi
