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
    parse_arguments $@
    install_routine
}

parse_arguments()
{
  # defaults
  PYTORCH=false
  ROBOT=""

  echo "Parsing any optional commandline arguments..."
  while getopts ":pr:" arg; do
    case $arg in
      p) PYTORCH=true; echo "-p) Pytorch option <$PYTORCH> selected...";;
      r) ROBOT="$OPTARG"; verify_robot;;
      \?) print_usage;;
    esac
  done
}

verify_robot() 
{
  declare -a robot_list=("ig2")
  if printf '%s\n' "${robot_list[@]}" | grep -P "$ROBOT" > /dev/null; then
    echo "-r) Robot option <$ROBOT> selected..."
  else
    echo "-r) Robot option <$ROBOT> not available..."
    print_usage
  fi
}

print_usage() 
{
  echo "Usage:"
  echo "   -p: install pytorch"
  echo "   -r: install software on a specific beam robot"
  printf "       options: "
  for val in ${robot_list[@]}; do
    printf "$val "
  done
  printf "\n"
  exit 1
}

install_routine() 
{
    sudo -v

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

    if [ "$PYTORCH" = true ]; then
      echo "Installing pytorch..."
      install_pytorch
    fi

    if [ $UBUNTU_CODENAME = xenial ]; then
      echo "Installing ladybug sdk..."
      install_ladybug_sdk
    fi   

    echo $ROBOT
    if [ ! -z "$ROBOT" ]; then
      echo "HERE"
      source $INSTALL_SCRIPTS/robot_dependencies_install.bash
      echo "now here 1"
      clone_ros_drivers   
      echo "now here 2"
      if [ "$ROBOT" = "ig2" ]; then
        echo "Installing drivers for $ROBOT..."
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

main $@
