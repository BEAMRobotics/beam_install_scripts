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

    mkdir -p /tmp/beam_dependencies
    sudo apt install -y libgeotiff2 libgeotiff-dev libjsoncpp-dev libpcl1.7* libpcl-dev cmake libproj-dev libgdal libqt5svg5-dev qttools5-*
    cd /tmp/beam_dependencies
    git clone https://github.com/LASzip/LASzip.git
    cd LASzip && mkdir build && cd build
    cmake .. && make -j99 && sudo make install
    echo "Finished installing LASZip."
    
    cd /tmp/beam_dependencies
    git clone https://github.com/PDAL/PDAL.git
    cd PDAL && git checkout 1.8.0
    mkdir build && cd build
    cmake .. && make -j99 && sudo make install
    echo "Finished installing PDAL v1.8.0."
    
    cd /tmp/beam_dependencies
    git clone https://github.com/CloudCompare/CloudCompare.git
    sudo ln -s /usr/lib/x86_64-linux-gnu/libvtkCommonCore-6.2.so /usr/lib/libvtkproj4.so
    cd CloudCompare && git checkout v2.10.2
    mkdir build && cd build 
    cmake -DINSTALL_QPCL_PLUGIN=ON -DOPTION_PDAL_LAS=ON -DINSTALL_QANIMATION_PLUGIN=ON -DJSON_ROOT_DIR=/usr/include/jsoncpp ..
    make -j99 && sudo make install
    echo "Finished installing CloudCompare v2.10.2."
    
    echo "Beam robotics installation scripts successfully tested."
}


main $1

