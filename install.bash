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
    parse_arguments $@
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
    echo "-r) Robot option <$ROBOT> not available. Exiting."
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

    # Ensure wget is available
    sudo apt-get install -qq wget  > /dev/null

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
    install_qwt
    install_catch2
    install_eigen3
    install_ceres
    install_pcl
    install_geographiclib
    install_gflags_from_source
    install_libpcap
    install_json
    install_dbow3
    install_opencv4
    install_docker

    if [ "$PYTORCH" = true ]; then
      echo "Installing pytorch..."
      install_pytorch
    fi

    if [ $UBUNTU_CODENAME = xenial ]; then
      echo "Installing ladybug sdk..."
      install_ladybug_sdk
    fi   

    if [ ! -z "$ROBOT" ]; then
      source $INSTALL_SCRIPTS/robot_dependencies_install.bash
      clone_ros_drivers   
      if [ "$ROBOT" = "ig2" ]; then
        echo "Installing drivers for $ROBOT..."
        install_spinnaker_sdk
        install_rosserial
        install_dt100
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

    # Compile 
    echo "Beam robotics installation completed. Compiling catkin workspace..."
    compile

    # Echo success
    echo "Catkin workspace successfully compiled. Please open a new terminal to re-source environment variables."
}

main $@
