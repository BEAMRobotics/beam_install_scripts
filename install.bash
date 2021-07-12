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

print_usage() {
  printf "Usage: \n"
  printf "   -p: install pytorch \n"
  printf "   -r: install software on a specific beam robot \n"
  printf "       options: ig2 \n"
}

main()
{
    install_routine $1
}

install_routine()
{
    sudo -v

    # Proccess command line flags
    PYTORCH=false
    ROBOT=""
    
    while getopts "pr" flag; do
      case ${flag} in
        p) PYTORCH=true;;
        r) ROBOT=${OPTARG};;
        *) print_usage
          exit 1 ;;
      esac
    done

    # Import functions to install required dependencies
    source $INSTALL_SCRIPTS/beam_dependencies_install.bash
    install_gcc7

    # source catkin setup script
    source $INSTALL_SCRIPTS/catkin_setup.bash

    # Install ROS
    bash $INSTALL_SCRIPTS/ros_install.bash
    create_catkin_ws

    bash $INSTALL_SCRIPTS/rosdeps_install.bash

    # Ensure wget is available
    sudo apt-get install -qq wget  > /dev/null

    # Install development machine dependencies
    install_cmake
    install_catch2
    install_eigen3
#    install_ceres
#    install_pcl
#    install_geographiclib
#    install_libpcap
#    install_json
#    install_dbow3
#    install_opencv4
    echo $PYTORCH
    if $PYTORCH; then
      echo "Installing pytorch"
      install_pytorch
    fi

    if [ $UBUNTU_CODENAME = xenial ]; then
      echo "Installing ladybug sdk"
      install_ladybug_sdk
    fi   

    # Install robot dependencies if flagged
    echo $ROBOT
    if ["$ROBOT" != ""]; then
      DRIVER_DIR="ros_drivers"
      echo "Downloading drivers required for beam robots..."
      cd "$CATKIN_DIR/src"
      if [ -d $DRIVER_DIR ]; then
        echo "Recursively pull most recent master/main branch for all submodules..."
        cd $DRIVER_DIR
        git pull --recurse-submodules
        cd ..
      else
        git clone --recursive git@github.com:BEAMRobotics/ros_drivers.git
      fi
      source $INSTALL_SCRIPTS/robot_dependencies_install.bash
      echo "install ig2"
      if ["$ROBOT" = "ig2"]; then
        echo "Installing drivers for ig2"
        # install_velodyne (this comes with beam_robotics)
        install_flir_blackfly
        install_spinnaker_sdk
        # install_Xsens
        install_rosserial
      fi
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
