#!/bin/bash
set -e  # exit on first error
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# get UBUNTU_CODENAME, ROS_DISTRO, REPO_DIR, CATKIN_DIR
source $SCRIPT_DIR/identify_environment.bash

sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'

case $UBUNTU_CODENAME in
  xenial)
    wget -qO - http://packages.ros.org/ros.key | sudo apt-key add -
    sudo apt-get -qq update
    sudo apt-get -qq install python-rosinstall python-catkin-pkg python-rosdep python-wstool > /dev/null
    sudo apt-get -qq install ros-$ROS_DISTRO-catkin ros-$ROS_DISTRO-desktop > /dev/null ;;
  bionic)
    sudo apt install curl
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
    sudo apt update
    sudo apt install ros-$ROS_DISTRO-desktop
    sudo apt install python-rosdep python-rosinstall python-rosinstall-generator python-wstool build-essential
    sudo apt install python-rosdep ;;
  *)
    echo "Unsupported version of Ubuntu detected. Only xenial (16.04.*) and bionic (18.04.*) are supported. Exiting."
    exit  1
esac

echo "Updating package lists ..."
sudo apt-get -qq update
echo "Installing ROS $ROS_DISTRO ..."
sudo apt-get -qq install ros-$ROS_DISTRO-pcl-ros ros-$ROS_DISTRO-image-transport ros-$ROS_DISTRO-image-transport-plugins ros-$ROS_DISTRO-libg2o > /dev/null
sudo apt-get install ros-$ROS_DISTRO-geographic-msgs
sudo apt-get install ros-$ROS_DISTRO-tf2-geometry-msgs

# ROS environment setup
echo "Setting up ROS environment..."
source /opt/ros/$ROS_DISTRO/setup.bash
echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> ~/.bashrc
echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc
echo "ROS_PACKAGE_PATH=/home/$USER/catkin_ws/src:/opt/ros/$ROS_DISTRO/share:$ROS_PACKAGE_PATH" >> ~/.bashrc

# Prepare rosdep to install dependencies.
echo "Updating rosdep ..."
if [ ! -d /etc/ros/rosdep ]; then
    sudo rosdep init 
fi
rosdep update
