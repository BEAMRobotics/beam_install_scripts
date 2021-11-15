#!/bin/bash
set -e
# This script is called by install.bash in beam_robotics/scripts

# Specify location of installation scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_SCRIPTS=$SCRIPT_DIR

# Set the repo directory as an environment variable
export REPO_DIR=$SCRIPT_DIR

# get UBUNTU_CODENAME, ROS_DISTRO, CATKIN_DIR
source $INSTALL_SCRIPTS/identify_environment.bash

main() 
{
    menu
    install_routine
}

menu()
{
    echo "Running this script will delete your /build /devel and /logs folders in your $CATKIN_DIR directory and re-build them."
    echo "Also, this script assumes the following things:"
    echo "  - Your ROS version is $ROS_DISTRO"
    echo "  - Your catkin workspace is located at: $CATKIN_DIR"
    echo "  - Catkin tools is installed"
    echo "  - Your bashrc sources $CATKIN_DIR/devel/setup.bash"
    echo "If any of the above assumptions are not true, the following script will make them so."
    echo "Do you wish to continue? (y/n):"

    while read ans; do
        case "$ans" in
            y) break;;
            n) exit; break;;
            *) echo "(y/n):";;
        esac
    done
}

install_routine() 
{
    sudo -v
    
    # Ensure wget is available
    sudo apt-get install -qq wget
    
    # get UBUNTU_CODENAME, ROS_DISTRO, REPO_DIR, CATKIN_DIR
    source $INSTALL_SCRIPTS/identify_environment.bash

    # Import functions to install required dependencies
    source $INSTALL_SCRIPTS/beam_dependencies_install.bash
    
    install_gcc7

    # source catkin setup script
    source $INSTALL_SCRIPTS/catkin_setup.bash

    # Install ROS
    bash $INSTALL_SCRIPTS/ros_install.bash
    create_catkin_ws

    bash $INSTALL_SCRIPTS/rosdeps_install.bash

    # Install development machine dependencies
    install_cmake
    install_eigen3
    install_libpcap
    
    source $INSTALL_SCRIPTS/robot_dependencies_install.bash
    install_spinnaker_sdk
    install_rosserial
    install_dt100
    install_husky_packages
    clone_ig2_ros_drivers
    update_udev_ig2

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

    # Compile 
    echo "Beam robotics installation completed. Compiling catkin workspace..."
    cd "$CATKIN_DIR"
    source /opt/ros/$ROS_DISTRO/setup.bash
    catkin build -j$NUM_PROCESSORS

    # Echo success
    echo "Catkin workspace successfully compiled. Please open a new terminal to re-source environment variables."

    echo "INSTALL COMPLETE. YOU WILL NEED TO INSTALL THE MTI SOFTWARE AVAILABLE HERE: "
    echo "https://content.xsens.com/mt-software-suite-download?hsCtaTracking=e7ef7e11-db88-4d9e-b36e-3f937ea4ae15%7Cd6a8454e-6db4-41e7-9f81-f8fc1c4891b3"
    echo "unpack, then run mtsdk_linux-x64_2021.2.sh (without sudo), then follow instructions in install_dir/xsens_ros_mti_driver/README.txt"
}

main $@
