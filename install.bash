#!/bin/bash
set -e
# This script is called by install.bash in beam_robotics/scripts

# Specify location of installation scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPTS=$SCRIPT_DIR

# Set the repo directory as an environment variable
export REPO_DIR=$SCRIPT_DIR

# get UBUNTU_CODENAME, ROS_DISTRO, CATKIN_DIR
source $INSTALL_SCRIPTS/identify_environment.bash

main() {
  menu
  parse_arguments $@
  install_routine
}

menu() {
  echo "Running this script will delete your /build /devel and /logs folders in your $CATKIN_DIR directory and re-build them."
  echo "Do you wish to continue? (y/n):"

  while read ans; do
    case "$ans" in
    y) break ;;
    n)
      exit
      break
      ;;
    *) echo "(y/n):" ;;
    esac
  done
}

parse_arguments() {
  # defaults
  GTSAM=false
  PYTORCH=false
  ROBOT=""

  echo "Parsing any optional commandline arguments..."
  while getopts ":pr:" arg; do
    case $arg in
    g)
      GTSAM=true
      echo "-g) GTSAM option <$GTSAM> selected..."
      ;;
    p)
      PYTORCH=true
      echo "-p) Pytorch option <$PYTORCH> selected..."
      ;;
    r)
      ROBOT="$OPTARG"
      verify_robot
      ;;
    \?) print_usage ;;
    esac
  done
}

verify_robot() {
  declare -a robot_list=("ig-handle" "ig2" "pierre")
  if printf '%s\n' "${robot_list[@]}" | grep -P "$ROBOT" >/dev/null; then
    echo "-r) Robot option <$ROBOT> selected..."
  else
    echo "-r) Robot option <$ROBOT> not available. Exiting."
    print_usage
  fi
}

print_usage() {
  echo "Usage:"
  echo "  -g: install GTSAM"
  echo "  -p: install pytorch"
  echo "  -r: install software on a specific beam robot"
  printf "    options: "
  for val in ${robot_list[@]}; do
    printf "$val "
  done
  printf "\n"
  exit 1
}

install_routine() {
  sudo -v

  # Ensure wget is available
  sudo apt-get install -qq wget >/dev/null

  # Get UBUNTU_CODENAME, ROS_DISTRO, REPO_DIR, CATKIN_DIR
  source $INSTALL_SCRIPTS/identify_environment.bash

  # Import functions to install required dependencies
  source $INSTALL_SCRIPTS/beam_dependencies_install.bash
  install_gcc7

  # Source catkin setup script
  source $INSTALL_SCRIPTS/catkin_setup.bash

  # Install ROS
  bash $INSTALL_SCRIPTS/ros_install.bash
  create_catkin_ws

  # Install ROS dependencies
  bash $INSTALL_SCRIPTS/rosdeps_install.bash

  # Install required development machine dependencies
  install_cmake # tool box that allows us to make c++ projects in linux
  install_catch2 #unit testing framework for C++  
  install_eigen3 # C++ library for linear algebra
  install_ceres # C++ library for modeling and solving large cmplicated optimization problems
  install_pcl # (point cloud library) software for 2d/3d image and point cloud processing
  install_geographiclib # C++ library for geodesic and rhumb line calculations; conversions between geographic, UTM, UPS, MGRS, geocentric, and local cartesian coordinates; gravity (e.g., EGM2008) and geomagnetic field (e.g., WMM2020) calculations
  install_pcap # portable framework for lowlevel network monitoring
  install_parmetis #library for partitioning unstructure graphs and hypergraphs,computing fill-reducing ordign for sparse materices, parallel AMR computations and large scale numerical simulations
  install_json # allows for text based representiong of javascript object lterals, arrays and scalar data
  install_dbow3 # C++ library for indexing and converting images into a bag of word represnation. Implements a hierarchical tree for approximation nerest neighbours in the mage feature space and creating a visual vocabulary
  install_opencv4 #c++ tool for image processng and performing compute vision tasks, also supports python and java, allows for extraction of useful information and discarding of "background noise"

  # Install optional software for development machines
  install_docker # platfrom for seperating software from yor infrasture to deliver infomation more quickly (allow to rn applications in loosly isolted environment so we can run multiple applications simultaneously)

  if [ "$GTSAM" = true ]; then
    install_gtsam # C++ library that implements smoothing and mapping in robotics and vision using factor graphs and bayes networks as underlying computing paradgm
  fi

  if [ "$PYTORCH" = true ]; then
    install_pytorch # computes data using tensors tha are accelerated by the GPU
  fi

  # Install beam robot drivers and dependencies
  if [ ! -z "$ROBOT" ]; then
    source $INSTALL_SCRIPTS/robot_dependencies_install.bash
    if [ "$ROBOT" = "ig-handle" ]; then
      echo "Installing drivers for $ROBOT..."
      install_ig_handle
    elif [ "$ROBOT" = "ig2" ]; then
      echo "Installing drivers for $ROBOT..."
      install_ig_handle
      install_husky_packages
    elif [ "$ROBOT" = "pierre" ]; then
      echo "Installing drivers for $ROBOT..."
      install_ig_handle
      install_dt100
    fi
  fi

  # Check that ros installed correctly
  ROS_CHECK="$(rosversion -d)"
  if [ "$ROS_CHECK" == "$ROS_DISTRO" ]; then
    echo "Ros install okay"
  else
    echo $ROS_CHECK
    echo $ROS_DISTRO
    echo "ROS not installed"
    exit
  fi

  # Check that catkin_ws was created
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
