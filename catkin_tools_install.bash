#!/bin/bash
set -e

# Check if already installed
if type catkin > /dev/null 2>&1; then
    echo "Catkin tools is already installed"
else
    echo "Installing catkin tools ..."
    sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list'
    wget -qO - http://packages.ros.org/ros.key | sudo apt-key add -
    sudo apt-get -qq update
    sudo apt-get -qq install python-catkin-tools > /dev/null
    echo "Catkin tools installed successfully."
fi
