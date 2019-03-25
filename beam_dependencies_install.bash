#!/bin/bash
set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# get UBUNTU_CODENAME, ROS_DISTRO, REPO_DIR, CATKIN_DIR
source $SCRIPT_DIR/identify_environment.bash

DEPS_DIR="/tmp/beam_dependencies"

# This script contains a series of functions to install 'other' dependencies for beam.

install_dataspeed()
{
    # We want all Dataspeed packages if not Travis
    # The required apt repository was already added in ros_install.bash
    # Also, the required dependency `dbw_mkz_msgs` was already installed there.
    if [ -z "$CONTINUOUS_INTEGRATION" ]; then
      echo "Installing or updating Dataspeed packages"
      sudo apt-get -qq install ros-$ROS_DISTRO-dbw-mkz
    fi
}

make_with_progress()
{
    if [ -z "$CONTINUOUS_INTEGRATION" ]; then
        local awk_arg="-W interactive"
    fi
    # Run make, printing a character for every 10 lines
    make "$@" | awk ${awk_arg} 'NR%5==1 { printf ".", $0}'
    echo "done"
}

install_ceres()
{
    # this install script is for local machines.
    if (find /usr/local/lib -name libceres.so | grep -q /usr/local/lib); then
        echo "Ceres is already installed."
    else
        echo "Installing Ceres 1.11.0 ..."
        mkdir -p "$DEPS_DIR"
        cd "$DEPS_DIR"
        sudo apt-get -qq install libgoogle-glog-dev libatlas-base-dev libeigen3-dev > /dev/null
        # not needed for xenial, the PPA does not have a release for xenial
        if [ $UBUNTU_CODENAME == "trusty" ]; then
            sudo add-apt-repository -y ppa:bzindovic/suitesparse-bugfix-1319687
            sudo apt-get -qq update
        fi
        sudo apt-get -qq install libsuitesparse-dev > /dev/null

        if [[ ! -d "gflags" ]]; then
            git clone -q https://github.com/gflags/gflags.git
        fi
        cd gflags
        git checkout -q v2.1.2
        mkdir -p build
        cd build
        cmake -DBUILD_SHARED_LIBS=ON .. > /dev/null
        echo "Building gflags"
        make_with_progress -j$(nproc)
        sudo make install > /dev/null
        cd "$DEPS_DIR"
        if [[ ! -d "ceres-solver" ]]; then
            git clone -q https://ceres-solver.googlesource.com/ceres-solver
        fi
        cd ceres-solver
        git checkout -q 1.11.0
        mkdir -p build
        cd build
        cmake -DBUILD_SHARED_LIBS=ON .. > /dev/null
        echo "Building Ceres"
        make_with_progress -j$(nproc)
        TEST_ARGS="-E 'bundle_adjustment|covariance|rotation'" # Skip the slowest tests
        make test ARGS="$TEST_ARGS" > /dev/null
        sudo make install > /dev/null
        sudo ldconfig # refresh shared library cache.
        echo "Ceres successfully installed."
    fi
}

install_protobuf()
{
    LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
    # this install script is for local machines.
    if (ldconfig -p | grep -q libprotobuf.so.11 ); then
        echo "Protobuf is already installed."
    else
        echo "Installing Protobuf 3.1.0"
        # tools needed to build protobuf
        sudo apt-get install -qq libtool unzip  > /dev/null
        mkdir -p "$DEPS_DIR"
        cd "$DEPS_DIR"
        PROTOBUF_DIR="protobuf-3.1.0"
        if [[ ! -d "$PROTOBUF_DIR" ]]; then
             local zipfile="protobuf-cpp-3.1.0.zip"
             wget "https://github.com/google/protobuf/releases/download/v3.1.0/$zipfile"
             unzip -qq "$zipfile"
             rm -f "$zipfile"
        fi
        cd "$PROTOBUF_DIR"
        ./configure -q --prefix /usr/local
        make_with_progress -j$(nproc)
        # Check commented out because it takes a lot of time to run all the tests
        # but leaving here in case we ever run into problems
        # make check > /dev/null
        sudo make install > /dev/null
        sudo ldconfig # refresh shared library cache.
        echo "Protobuf successfully installed."
    fi
}

install_pcl()
{
    PCL_VERSION='1.8.0'
    PCL_FILE="pcl-$PCL_VERSION"
    PCL_DIR="pcl-$PCL_FILE"
    PCL_URL="https://github.com/PointCloudLibrary/pcl/archive/pcl-$PCL_VERSION.tar.gz"

    # TODO: find a better way to check if already installed from source
    if [ -e "/usr/local/lib/libpcl_2d.so.$PCL_VERSION" ]; then
        echo "PCL version $PCL_VERSION already installed"
    else
        echo "Installing PCL version $PCL_VERSION ..."
        mkdir -p "$DEPS_DIR"
        cd "$DEPS_DIR"
        if [[ ! -d "$PCL_DIR" ]]; then
            wget "$PCL_URL"
            tar -xf "$PCL_FILE.tar.gz"
            rm -rf "$PCL_FILE.tar.gz"
        fi
        cd "$PCL_DIR"
        mkdir -p build
        cd build

        PCL_CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-std=c++11"
        if [ -n "$CONTINUOUS_INTEGRATION" ]; then
            # Disable everything unneeded for a faster build
            PCL_CMAKE_ARGS="${PCL_CMAKE_ARGS} \
            -DWITH_CUDA=OFF -DWITH_DAVIDSDK=OFF -DWITH_DOCS=OFF \
            -DWITH_DSSDK=OFF -DWITH_ENSENSO=OFF -DWITH_FZAPI=OFF \
            -DWITH_LIBUSB=OFF -DWITH_OPENGL=OFF -DWITH_OPENNI=OFF \
            -DWITH_OPENNI2=OFF -DWITH_QT=OFF -DWITH_RSSDK=OFF \
            -DBUILD_CUDA=OFF -DBUILD_GPU=OFF -DBUILD_surface=OFF \
            -DBUILD_tracking=OFF"
        fi

        cmake .. ${PCL_CMAKE_ARGS} > /dev/null

        echo "Building $PCL_FILE"
        make_with_progress -j$(nproc)

        sudo make install > /dev/null
        echo "PCL installed successfully"
    fi
}

install_geographiclib()
{
    GEOGRAPHICLIB_VERSION="1.49"
    GEOGRAPHICLIB_URL="https://sourceforge.net/projects/geographiclib/files/distrib/GeographicLib-$GEOGRAPHICLIB_VERSION.tar.gz"
    GEOGRAPHICLIB_DIR="GeographicLib-$GEOGRAPHICLIB_VERSION"

    if (ldconfig -p | grep -q libGeographic.so.17 ); then
        echo "GeographicLib version $GEOGRAPHICLIB_VERSION is already installed."
    else
        echo "Installing GeographicLib version $GEOGRAPHICLIB_VERSION ..."
        mkdir -p "$DEPS_DIR"
        cd "$DEPS_DIR"
        wget "$GEOGRAPHICLIB_URL"
        tar -xf "GeographicLib-$GEOGRAPHICLIB_VERSION.tar.gz"
        rm -rf "GeographicLib-$GEOGRAPHICLIB_VERSION.tar.gz"

        cd "$GEOGRAPHICLIB_DIR"
        mkdir -p BUILD
        cd BUILD
        cmake ..

        make_with_progress -j$(nproc)
        make test
        sudo make install > /dev/null
    fi
}

install_gtsam()
{
    GTSAM_VERSION="4.0.0-alpha2"
    GTSAM_URL="https://bitbucket.org/gtborg/gtsam.git"
    GTSAM_DIR="gtsam"

    if (find /usr/local/lib -name libgtsam.so | grep -q /usr/local/lib); then
    #if (ldconfig -p | grep -q libgtsam.so); then
        echo "GTSAM version $GTSAM_VERSION is already installed."
    else
        echo "Installing GTSAM version $GTSAM_VERSION ..."
        mkdir -p "$DEPS_DIR"
        cd "$DEPS_DIR"

        git clone $GTSAM_URL
        cd $GTSAM_DIR
        git checkout $GTSAM_VERSION
        mkdir -p build
        cd build
        cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DGTSAM_USE_SYSTEM_EIGEN=ON -DGTSAM_BUILD_UNSTABLE=OFF -DGTSAM_BUILD_WRAP=OFF \
        -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF  -DGTSAM_BUILD_DOCS=OFF

        make -j$(nproc)
        sudo make install > /dev/null
        echo "GTSAM installed successfully"
    fi
}

install_liquid-dsp()
{
    LIQUID_VERSION="1.3.1"
    LIQUID_URL="http://liquidsdr.org/downloads/liquid-dsp-$LIQUID_VERSION.tar.gz"

    if (ldconfig -p | grep -q libliquid.so); then
        echo "Liquid DSP version $LIQUID_VERSION is already installed."
        return
    fi

    echo "Installing Liquid DSP version $LIQUID_VERSION ..."
    sudo apt-get -qq install automake autoconf
    mkdir -p "$DEPS_DIR"
    cd "$DEPS_DIR"
    wget "$LIQUID_URL"
    tar -xf "liquid-dsp-$LIQUID_VERSION.tar.gz"
    rm "liquid-dsp-$LIQUID_VERSION.tar.gz"
    cd "liquid-dsp-$LIQUID_VERSION"
    ./bootstrap.sh
    ./configure
    make_with_progress -j$(nproc)
    sudo make install > /dev/null
    echo "Liquid DSP installed successfully"
}

install_libwave()
{
    if (find /usr/local/lib -name libwave_* | grep -q /usr/local/lib); then
        echo "libwave SLAM library already installed"
    else
        echo "Installing libwave SLAM library"
        cd ~
        # Install dependencies
        sudo apt-get install libboost-dev libyaml-cpp-dev libeigen3-dev \
        build-essential cmake

        # Clone the repository with submodules
        # Ensure that Beam install scripts are installed
        if [ -d libwave ]; then
            echo "Libwave directory already installed"
        else
            echo "Cloning libwave into home directory"
            git clone --recursive https://github.com/wavelab/libwave.git
            echo "Success"
        fi


        cd libwave
        mkdir -p build
        cd build
        cmake -DBUILD_TESTS=OFF ..
        make -j$(nproc)

        # Install libwave
        sudo make install

        cd ~
        sudo rm -rf libwave

    fi
    # wave_spatial_utils not inluded in libwave github repo
    # install dep for wave_spatial_utils
    sudo apt-get install ros-kinetic-tf2-geometry-msgs
}

install_catch2()
{
  if [ ! -d "$HOME/software" ]; then
      mkdir -p "$HOME/software"
  fi

  if [ ! -d "$HOME/software/Catch2" ]; then
    git clone https://github.com/catchorg/Catch2.git $HOME/software/Catch2
  fi
  cd $HOME/software/Catch2
  mkdir build
  cd build
  cmake ..
  sudo make -j8 install
  echo "Success"
}
