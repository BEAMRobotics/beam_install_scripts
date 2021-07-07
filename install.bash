#!/bin/bash
set -e
# This script is for testing the automatic installation process of ros and the creation of a catkin workspace

# Specify location of installation scripts

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_SCRIPTS=$SCRIPT_DIR

# Set the repo directory as an environment variable
export REPO_DIR=$SCRIPT_DIR

# get UBUNTU_CODENAME, ROS_DISTRO, CATKIN_DIR
source $INSTALL_SCRIPTS/identify_environment.bash


main()
{
    install_routine $1
}

install_routine()
{
    sudo -v
    # Import functions to install required dependencies
    source $INSTALL_SCRIPTS/beam_dependencies_install.bash
    install_gcc7

    # source catkin setup script
    source $INSTALL_SCRIPTS/catkin_setup.bash

    # submodule_init

    bash $INSTALL_SCRIPTS/ros_install.bash
    create_catkin_ws

    bash $INSTALL_SCRIPTS/rosdeps_install.bash

    # Ensure wget is available
    sudo apt-get install -qq wget  > /dev/null

    # Install development machine dependencies
    install_cmake
    install_catch2
    install_eigen3
    install_ceres
    install_pcl
    install_geographiclib
    install_libpcap
    install_json
    install_dbow3
    install_opencv4
    install_pytorch

    if [ $UBUNTU_CODENAME = xenial ]; then
        echo "Installing ladybug sdk"
        install_ladybug_sdk
    fi   
    
    # Install robot dependencies if flagged
    getopts r: flag
    if [${flag} = 'ig2']; then
      echo 'Installing drivers for ig2'
      cd $REPO_DIR
      if [ -d 'ig2_ros_drivers' ]; then
        echo 'pulling most recent master'
        cd ig2_ros_drivers
        git pull origin master
        cd ..
      else
        echo "cloning Beam install scripts"
        git clone git@github.com:BEAMRobotics/ig2_ros_drivers.git
      fi
      echo 'TEMP: INSTALL DRIVERS'
      #source $INSTALL_SCRIPTS/robot_dependencies_install.bash
      # install_velodyne
      # install_FLIR
      # install_Spinnaker
      # install_Xsens
      # install_ROS_Serial
    fi

    # check that ros installed correctly
    ROS_CHECK="$(rosversion -d)"
    if [ "$ROS_CHECK" == "$ROS_DISTRO" ]; then
        echo "Ros install okay"
    else
        echo $ROS_CHECK
        echo $ROS_DISTRO
        echo "ROS not installed"
        exit
    fi

    # check that catkin_ws was created
    if [ -d "$CATKIN_DIR" ]; then
        echo "Catkin Directory found"
    else
        echo "Catkin Directory not created"
        exit
    fi

    # Echo success
    echo "Beam robotics installation scripts successfully tested."
}


main $1