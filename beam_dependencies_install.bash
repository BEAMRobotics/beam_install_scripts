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

install_gcc7()
{
  sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
  sudo apt-get update
  sudo apt-get -y install gcc-7 g++-7
  sudo rm /usr/bin/gcc
  sudo rm /usr/bin/g++
  sudo ln -s /usr/bin/gcc-7 /usr/bin/gcc
  sudo ln -s /usr/bin/g++-7 /usr/bin/g++
}

install_ceres()
{
    CERES_DIR="ceres-solver-1.14.0"
    BUILD_DIR="build"

    sudo apt-get -qq install libgoogle-glog-dev libatlas-base-dev > /dev/null
    # this install script is for local machines.
    if (find /usr/local/lib -name libceres.so | grep -q /usr/local/lib); then
        echo "Ceres is already installed."
    else
        echo "Installing Ceres 1.14.0 ..."
        mkdir -p "$DEPS_DIR"
        cd "$DEPS_DIR"

        if [ ! -d "$CERES_DIR" ]; then
          wget "http://ceres-solver.org/$CERES_DIR.tar.gz"
          tar zxf "$CERES_DIR.tar.gz"
          rm -rf "$CERES_DIR.tar.gz"
        fi

        cd $CERES_DIR
        if [ ! -d "$BUILD_DIR" ]; then
          mkdir -p $BUILD_DIR
          cd $BUILD_DIR
          cmake ..
          make -j$(nproc)
          make test
        fi

        cd $DEPS_DIR/$CERES_DIR/$BUILD_DIR
        sudo make -j$(nproc) install
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
  PCL_VERSION="1.8.1"
  PCL_DIR="pcl"
  BUILD_DIR="build"

  cd $DEPS_DIR

  if [ -d 'pcl-pcl-1.8.0' ]; then
    echo "Removing old version of pcl (pcl-1.8.0) from deps"
    sudo rm -rf pcl-pcl-1.8.0
  fi

  if [ ! -d "$PCL_DIR" ]; then
    echo "pcl not found... cloning"
    git clone git@github.com:BEAMRobotics/pcl.git
  fi

  cd $PCL_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    echo "Existing build of PCL not found.. building from scratch"
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR

    PCL_CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-std=c++11"
    if [ -n "$CONTINUOUS_INTEGRATION" ]; then
              # Disable everything unneeded for a faster build
              echo "Installing light build for CI"
              PCL_CMAKE_ARGS="${PCL_CMAKE_ARGS} \
              -DWITH_CUDA=OFF -DWITH_DAVIDSDK=OFF -DWITH_DOCS=OFF \
              -DWITH_DSSDK=OFF -DWITH_ENSENSO=OFF -DWITH_FZAPI=OFF \
              -DWITH_LIBUSB=OFF -DWITH_OPENGL=OFF -DWITH_OPENNI=OFF \
              -DWITH_OPENNI2=OFF -DWITH_QT=OFF -DWITH_RSSDK=OFF \
              -DBUILD_CUDA=OFF -DBUILD_GPU=OFF \
              -DBUILD_tracking=OFF -DBUILD_people=OFF \
              -DBUILD_stereo=OFF -DBUILD_simulation=OFF -DBUILD_apps=OFF \
              -DBUILD_examples=OFF -DBUILD_tools=OFF -DBUILD_visualization=ON"
    fi

    cmake .. ${PCL_CMAKE_ARGS} > /dev/null
    make -j$(nproc)
  fi

  cd $DEPS_DIR/$PCL_DIR/$BUILD_DIR
  sudo make -j$(nproc) install
}

install_geographiclib()
{
    GEOGRAPHICLIB_VERSION="1.49"
    GEOGRAPHICLIB_URL="https://sourceforge.net/projects/geographiclib/files/distrib/GeographicLib-$GEOGRAPHICLIB_VERSION.tar.gz"
    GEOGRAPHICLIB_DIR="GeographicLib-$GEOGRAPHICLIB_VERSION"
    BUILD_DIR="build"

    if (ldconfig -p | grep -q libGeographic.so.17 ); then
        echo "GeographicLib version $GEOGRAPHICLIB_VERSION is already installed."
    else
        echo "Installing GeographicLib version $GEOGRAPHICLIB_VERSION ..."
        mkdir -p "$DEPS_DIR"
        cd "$DEPS_DIR"

        if [ ! -d "$GEOGRAPHICLIB_DIR" ]; then
          wget "$GEOGRAPHICLIB_URL"
          tar -xf "GeographicLib-$GEOGRAPHICLIB_VERSION.tar.gz"
          rm -rf "GeographicLib-$GEOGRAPHICLIB_VERSION.tar.gz"
        fi

        cd "$GEOGRAPHICLIB_DIR"
        if [ ! -d "$BUILD_DIR" ]; then
          mkdir -p $BUILD_DIR
          cd $BUILD_DIR
          cmake ..
          make_with_progress -j$(nproc)
          make test
        fi

        cd $DEPS_DIR/$GEOGRAPHICLIB_DIR/$BUILD_DIR
        sudo make -j$(nproc) install > /dev/null
    fi
}

install_gtsam()
{
    GTSAM_VERSION="4.0.0-alpha2"
    GTSAM_URL="https://bitbucket.org/gtborg/gtsam.git"
    GTSAM_DIR="gtsam"
    BUILD_DIR="build"

    if (find /usr/local/lib -name libgtsam.so | grep -q /usr/local/lib); then
    #if (ldconfig -p | grep -q libgtsam.so); then
        echo "GTSAM version $GTSAM_VERSION is already installed."
    else
      echo "Installing GTSAM version $GTSAM_VERSION ..."
      mkdir -p "$DEPS_DIR"
      cd "$DEPS_DIR"

      if [ ! -d "$GTSAM_DIR" ]; then
        git clone $GTSAM_URL
      fi

      cd $GTSAM_DIR
      git checkout $GTSAM_VERSION
      if [ ! -d "$BUILD_DIR" ]; then
        mkdir -p $BUILD_DIR
        cd $BUILD_DIR
        cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DGTSAM_USE_SYSTEM_EIGEN=ON -DGTSAM_BUILD_UNSTABLE=OFF -DGTSAM_BUILD_WRAP=OFF \
        -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF  -DGTSAM_BUILD_DOCS=OFF
        make -j$(nproc)
      fi

      cd $DEPS_DIR/$GTSAM_DIR/$BUILD_DIR
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
    LIBWAVE_DIR="libwave"
    BUILD_DIR="build"

    if (find /usr/local/lib -name libwave_* | grep -q /usr/local/lib); then
        echo "libwave SLAM library already installed"
    else
        echo "Installing libwave SLAM library"
        # Install dependencies
        sudo apt-get install libboost-dev libyaml-cpp-dev ros-kinetic-tf2-geometry-msgs\
        build-essential cmake

        cd $DEPS_DIR
        if [ -d "$LIBWAVE_DIR" ]; then
            echo "Libwave directory already cloned"
        else
            echo "Cloning libwave into home directory"
            git clone --recursive https://github.com/wavelab/libwave.git
            echo "Success"
        fi

        cd $LIBWAVE_DIR
        if [ ! -d "$BUILD_DIR" ]; then
          mkdir -p $BUILD_DIR
          cd $BUILD_DIR
          cmake -DBUILD_TESTS=OFF ..
          make -j$(nproc)
        fi

        cd $DEPS_DIR/$LIBWAVE_DIR/$BUILD_DIR
        sudo make -j$(nproc) install
    fi
}

install_catch2()
{
  echo "Installing Catch2..."
  CATCH2_DIR="Catch2"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$DEPS_DIR/$CATCH2_DIR" ]; then
    git clone https://github.com/catchorg/Catch2.git $DEPS_DIR/Catch2
  fi

  cd $CATCH2_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake -DCMAKE_CXX_STANDARD=11 ..
    make -j$(nproc)
  fi

  cd $DEPS_DIR/$CATCH2_DIR/$BUILD_DIR
  sudo make -j$(nproc) install
}

install_cmake()
{
  #Remove existing cmake
  if [ ! -d "/usr/local/cmake*" ]; then
    echo "CMAKE installation found in /usr/local/, deleting..."
    sudo rm -rf /usr/local/cmake*
  fi
  echo $PATH
  TEMP_DIR="tmp"
  VERSION="3.14"
  BUILD="1"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  mkdir -p $TEMP_DIR
  cd $TEMP_DIR

  wget "https://cmake.org/files/v$VERSION/cmake-$VERSION.$BUILD-Linux-x86_64.sh"
  sudo mkdir -p /opt/cmake
  yes | sudo sh cmake-$VERSION.$BUILD-Linux-x86_64.sh --prefix=/opt/cmake > /dev/null
  sudo ln -s "/opt/cmake/cmake-$VERSION.$BUILD-Linux-x86_64/bin/cmake" /usr/local/bin/cmake
  /usr/local/bin/cmake --version
  cmake --version
  cd $DEPS_DIR
  sudo rm -rf $TEMP_DIR
  export PATH="/usr/local/bin:$PATH"
}

install_eigen3()
{
  EIGEN_DIR="eigen-eigen-323c052e1731"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$EIGEN_DIR" ]; then
    wget http://bitbucket.org/eigen/eigen/get/3.3.7.tar.bz2
    tar xjf 3.3.7.tar.bz2
    rm -rf 3.3.7.tar.bz2
  fi

  cd $EIGEN_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake ..
    make
  fi

  cd $DEPS_DIR/$EIGEN_DIR/$BUILD_DIR
  sudo make -j$(nproc) install
}

install_gflags()
{
  GFLAGS_DIR="gflags"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$GFLAGS_DIR" ]; then
    git clone https://github.com/gflags/gflags.git
  fi

  cd $GFLAGS_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake ..
    make
  fi

  cd $DEPS_DIR/$GFLAGS_DIR/$BUILD_DIR
  sudo make -j$(nproc) install
}

install_json()
{
  JSON_DIR="json"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$JSON_DIR" ]; then
    git clone -b v3.6.1 https://github.com/nlohmann/json.git
  fi

  cd $JSON_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake ..
    make -j$(nproc)
  fi

  cd $DEPS_DIR/$JSON_DIR/$BUILD_DIR
  sudo make -j$(nproc) install
}

install_ladybug_sdk()
{
    LB_DIR="ladybug"
    mkdir -p $DEPS_DIR
    cd $DEPS_DIR
    sudo apt-get -y install libraw1394-11 libraw1394-dev libraw1394-tools libgtkmm-2.4-1v5 libglademm-2.4-1v5 libgtkglextmm-x11-1.2-dev libgtkglextmm-x11-1.2 libusb-1.0-0

    if [ ! -d "$LB_DIR" ]; then
        echo "Don't have Ladybug SDK Directory, creating & downloading SDK..."
        mkdir -p $LB_DIR
        cd $LB_DIR
        wget https://www.dropbox.com/s/8d67i2jxmkwa52n/LaydbugSDK_1.16.3.48_amd64.tar?dl=0
        tar -xvf LaydbugSDK_1.16.3.48_amd64.tar?dl=0
        sudo dpkg -x ladybug-1.16.3.48_amd64.deb .
        sudo cp -a usr/. /usr/local/
        echo "Ladybug SDK successfully installed in /usr/local/"
    else
	echo "Already have ladybug folder..."
        cd $LB_DIR
        sudo dpkg -x ladybug-1.16.3.48_amd64.deb .
        sudo cp -a usr/. /usr/local/
        echo "Ladybug SDK successfully installed in /usr/local/"
    fi
}
