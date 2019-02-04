#!/bin/bash
set -e
# This script installs and compiles libwave



main()
{
    cd ~ 
    # Install dependencies 
    sudo apt-get install libboost-dev libyaml-cpp-dev libeigen3-dev \
    build-essential cmake

    # Clone the repository with submodules
    git clone --recursive https://github.com/wavelab/libwave.git

    cd libwave
    mkdir -p build
    cd build
    cmake ..
    make -j8

    # Install libwave
    sudo make install
}

main
