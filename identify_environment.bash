#!/bin/bash
set -e
# The default catkin workspace
: ${CATKIN_DIR:="$HOME/catkin_ws"}

export UBUNTU_CODENAME=$(lsb_release -s -c)
case $UBUNTU_CODENAME in
  trusty)
    export ROS_DISTRO=indigo;;
  xenial)
    export ROS_DISTRO=kinetic;;
  *)
    echo "Unsupported version of Ubuntu detected. Only trusty (14.04.*) and xenial (16.04.*) are currently supported."
    exit 1
esac
