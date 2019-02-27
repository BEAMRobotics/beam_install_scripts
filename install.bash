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

    cd "$SCRIPTS_DIR"

    # submodule_init

    bash $INSTALL_SCRIPTS/ros_install.bash
    bash $INSTALL_SCRIPTS/create_catkin_workspace.bash

    bash $INSTALL_SCRIPTS/rosdeps_install.bash

    env_setup

    # Import functions to install required dependencies
    source $INSTALL_SCRIPTS/beam_dependencies_install.bash


    # Ensure wget is available
    sudo apt-get install -qq wget  > /dev/null
    # Install dependencies
    #install_ceres
    #install_pcl
    #install_geographiclib
    #install_gtsam
    #install_libwave

    compile

    # check that ros installed correctly
    ROS_CHECK="$(rosversion -d)"
    if [ "$ROS_CHECK" == "$ROS_DISTRO" ]; then
        echo "Ros install okay"
    else
        echo $ROS_CHECK
        echo $ROS_DISTRO
        echo "Ros not installed"
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


compile()
{
    cd "$CATKIN_DIR"
    source /opt/ros/$ROS_DISTRO/setup.bash
    if [ -z "$CONTINUOUS_INTEGRATION" ]; then
        catkin build
    else
        if [ -n "$CIRCLECI" ]; then
            # Build libwave by itself first, since the job is so large
            catkin build --no-status -j2 libwave
            catkin build --no-status --mem-limit 6G
        else
            catkin build --no-status
        fi
    fi
}

env_setup()
{
    # ROS environment setup
    echo "source /opt/ros/kinetic/setup.bash" >> ~/.bashrc
    source /opt/ros/kinetic/setup.bash
    echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc
    echo "ROS_PACKAGE_PATH=/home/$USER/catkin_ws/src:/opt/ros/kinetic/share:/$ROS_PACKAGE_PATH" >> ~/.bashrc
}


main $1
