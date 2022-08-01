#!/bin/bash
set -e
# The default catkin workspace
export CATKIN_DIR="$HOME/catkin_ws"

# get release of Ubuntu
export UBUNTU_CODENAME=$(lsb_release -s -c)
case $UBUNTU_CODENAME in
bionic)
  export ROS_DISTRO=melodic
  ;;
noetic)
  export ROS_DISTRO=noetic
  echo "noetic (20.04.*) currently not supported. Exiting."
  exit 1 # place holder if beam stack moves to noetic
  ;;
*)
  echo "Unsupported version of Ubuntu detected. Only xenial (16.04.*) and bionic (18.04.*) are supported. Exiting."
  exit 1
  ;;
esac

# get number of processors for high-load installs
if [ $(nproc) -lt 2 ]; then
  export NUM_PROCESSORS=1
else
  export NUM_PROCESSORS=$(($(nproc) / 2))
fi
