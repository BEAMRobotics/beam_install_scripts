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
    # Install dependencies
    install_cmake
    install_catch2
    install_eigen3
    install_ceres
    install_pcl
    install_geographiclib
    install_libpcap
    #install_gtsam
    #install_libwave
    install_json
    install_dbow3
    install_opencv4
    
    if [ $UBUNTU_CODENAME = xenial ]; then
        echo "Installing ladybug sdk"
        install_ladybug_sdk
    fi   
    install_pytorch

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
