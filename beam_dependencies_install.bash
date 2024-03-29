#!/bin/bash
set -e

# directory for cloning/downloading libraries installed using cmake/make. Upon reboot, this folder is wiped.
DEPS_DIR="/tmp/beam_dependencies"

# helper function for make
make_with_progress() {
  if [ -z "$CONTINUOUS_INTEGRATION" ]; then
    local awk_arg="-W interactive"
  fi
  # Run make, printing a character for every 10 lines
  make "$@" | awk ${awk_arg} 'NR%5==1 { printf ".", $0}'
  echo "done"
}

# install functions required to compile and run beam_robotics on a development machine
install_git_lfs(){
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
  sudo apt-get install git-lfs
}


install_gcc7() {
  sudo apt update
  sudo apt install build-essential

  GCC_PATH="/usr/bin/gcc"
  GPP_PATH="/usr/bin/g++"
  if test -f $GCC_PATH; then
    sudo rm -r $GCC_PATH
  fi

  if test -f $GPP_PATH; then
    sudo rm -r $GPP_PATH
  fi

  sudo ln -s /usr/bin/gcc-7 /usr/bin/gcc
  sudo ln -s /usr/bin/g++-7 /usr/bin/g++
}

install_gcc9() {
  sudo apt update
  sudo apt install build-essential

  GCC_PATH="/usr/bin/gcc"
  GPP_PATH="/usr/bin/g++"
  if test -f $GCC_PATH; then
    sudo rm -r $GCC_PATH
  fi

  if test -f $GPP_PATH; then
    sudo rm -r $GPP_PATH
  fi

  sudo ln -s /usr/bin/gcc-9 /usr/bin/gcc
  sudo ln -s /usr/bin/g++-9 /usr/bin/g++
}

install_ceres() {
  # search for ceres in /usr/local/include
  if [ -d '/usr/local/include/ceres' ]; then
    echo "Found ceres. Not installing"
    return
  else
    echo "ceres not found in /usr/local/include, installing now."
  fi

  CERES_DIR="ceres-solver-1.14.0"
  BUILD_DIR="build"

  sudo apt-get -qq install libgoogle-glog-dev libatlas-base-dev >/dev/null
  # this install script is for local machines.
  if (find /usr/local/lib -name libceres.so | grep -q /usr/local/lib); then
    echo "Ceres is already installed."
  else
    echo "Installing Ceres 1.14.0 ..."
    mkdir -p $DEPS_DIR
    cd $DEPS_DIR

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
      make_with_progress -j$NUM_PROCESSORS
    fi

    cd $DEPS_DIR/$CERES_DIR/$BUILD_DIR
    sudo make -j$NUM_PROCESSORS install >/dev/null
  fi
}

install_protobuf() {
  LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
  # this install script is for local machines.
  if (ldconfig -p | grep -q libprotobuf.so.11); then
    echo "Protobuf is already installed."
  else
    echo "Installing Protobuf 3.1.0"
    # tools needed to build protobuf
    sudo apt-get install -qq libtool unzip >/dev/null
    mkdir -p $DEPS_DIR
    cd $DEPS_DIR
    PROTOBUF_DIR="protobuf-3.1.0"
    if [[ ! -d "$PROTOBUF_DIR" ]]; then
      local zipfile="protobuf-cpp-3.1.0.zip"
      wget "https://github.com/google/protobuf/releases/download/v3.1.0/$zipfile"
      unzip -qq "$zipfile"
      rm -f "$zipfile"
    fi
    cd "$PROTOBUF_DIR"
    ./configure -q --prefix /usr/local
    make_with_progress -j$NUM_PROCESSORS
    # Check commented out because it takes a lot of time to run all the tests
    # but leaving here in case we ever run into problems
    # make check > /dev/null
    sudo make install >/dev/null
    sudo ldconfig # refresh shared library cache.
    echo "Protobuf successfully installed."
  fi
}

install_pcap() {
  echo "Installing velodyne driver dependencies..."
  sudo apt-get install libpcap-dev
}

install_nanoflann()
{
    echo "installing nanoflann..."
    VERSION="v1.4.3"
    DIR="nanoflann"
    BUILD_DIR="build"

    mkdir -p $DEPS_DIR
    cd $DEPS_DIR
    git clone git@github.com:jlblancoc/nanoflann.git
    cd $DIR
    git checkout $VERSION 
    mkdir -p $BUILD_DIR 
    cd $BUILD_DIR 
    cmake ..
    make_with_progress -j$NUM_PROCESSORS
    sudo make -j$NUM_PROCESSORS install  > /dev/null
}

install_parmetis() {
  sudo apt-get install libparmetis-dev
}

install_pcl() {
  PCL_VERSION="1.11.1"
  PCL_DIR="pcl"
  BUILD_DIR="build"

  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  # search for pcl 1.11 in /usr/local/share
  if [ -d '/usr/local/share/pcl-1.11' ]; then
    echo "Found pcl 1.11. Not installing"
    return
  else
    echo "pcl 1.11 not found in /usr/local/share, installing now."
  fi

  if [ ! -d "$PCL_DIR" ]; then
    echo "pcl not found... cloning"
    git clone --depth 1 -b pcl-$PCL_VERSION https://github.com/PointCloudLibrary/pcl.git
  fi

  cd $PCL_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    echo "Existing build of PCL not found.. building from scratch"
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR

    PCL_CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-std=c++14"
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

    cmake .. ${PCL_CMAKE_ARGS} >/dev/null
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $DEPS_DIR/$PCL_DIR/$BUILD_DIR
  sudo make -j$NUM_PROCESSORS install >/dev/null
}

install_geographiclib() {
  GEOGRAPHICLIB_VERSION="1.49"
  GEOGRAPHICLIB_URL="https://sourceforge.net/projects/geographiclib/files/distrib/GeographicLib-$GEOGRAPHICLIB_VERSION.tar.gz"
  GEOGRAPHICLIB_DIR="GeographicLib-$GEOGRAPHICLIB_VERSION"
  BUILD_DIR="build"

  if (ldconfig -p | grep -q libGeographic.so.17); then
    echo "GeographicLib version $GEOGRAPHICLIB_VERSION is already installed."
  else
    echo "Installing GeographicLib version $GEOGRAPHICLIB_VERSION ..."
    mkdir -p $DEPS_DIR
    cd $DEPS_DIR

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
      make_with_progress -j$NUM_PROCESSORS
    fi

    cd $DEPS_DIR/$GEOGRAPHICLIB_DIR/$BUILD_DIR
    sudo make -j$NUM_PROCESSORS install >/dev/null
  fi
}

install_catch2() {
  # search for Catch2 in /usr/local/share
  if [ -d '/usr/local/share/Catch2' ]; then
    echo "Found Catch2. Not installing"
    return
  else
    echo "Catch2 not found in /usr/local/share, installing now."
  fi

  echo "Installing Catch2..."
  CATCH2_DIR="Catch2"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$DEPS_DIR/$CATCH2_DIR" ]; then
    git clone --depth 1 https://github.com/catchorg/Catch2.git --branch v2.13.2 $DEPS_DIR/$CATCH2_DIR
  fi

  cd $CATCH2_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake -DCMAKE_CXX_STANDARD=11 ..
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $DEPS_DIR/$CATCH2_DIR/$BUILD_DIR
  sudo make -j$NUM_PROCESSORS install >/dev/null
}

install_cmake() {
  # get cmake version (first 3 number only, e.g.., 3.14)
  version=$(cmake --version)
  version="${version//'cmake version '/}"
  version=${version:0:4}

  # remove period (e.g., 314)
  version="${version//'.'/}"

  # if version is greater or qual to 3.14, then we return
  if (("$version" >= "314")); then
    echo "Cmake version install is greater or equal to min. 3.14. Not installing."
    return
  else
    echo "Cmake version install is less than min. 3.14. Removing current and installing newer version."
  fi

  #Remove existing cmake
  if [ ! -d "/usr/local/cmake*" ]; then
    echo "CMAKE installation found in /usr/local/, deleting..."
    sudo rm -rf /usr/local/cmake*
  fi

  #Remove CMake symlink if it exists. This is necessary if doing a re-install
  CMAKE_SYMLINK_PATH="/usr/local/bin/cmake"
  if [[ -L "$CMAKE_SYMLINK_PATH" ]]; then
    echo "Removing existing CMAKE symbolic link: $CMAKE_SYMLINK_PATH"
    sudo rm $CMAKE_SYMLINK_PATH
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
  yes | sudo sh cmake-$VERSION.$BUILD-Linux-x86_64.sh --prefix=/opt/cmake >/dev/null
  sudo ln -s "/opt/cmake/cmake-$VERSION.$BUILD-Linux-x86_64/bin/cmake" /usr/local/bin/cmake
  /usr/local/bin/cmake --version
  cmake --version
  cd $DEPS_DIR
  sudo rm -rf $TEMP_DIR
  export PATH="/usr/local/bin:$PATH"
}

install_eigen3() {
  # search for eigen3 in /usr/local/share
  if [ -d '/usr/local/share/eigen3' ]; then
    echo "Found eigen3. Not installing"
    return
  else
    echo "eigen3 not found in /usr/local/share, installing now."
  fi

  EIGEN_DIR="eigen-3.3.7"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$EIGEN_DIR" ]; then
    wget https://gitlab.com/libeigen/eigen/-/archive/3.3.7/eigen-3.3.7.tar.bz2
    tar xjf eigen-3.3.7.tar.bz2
    rm -rf eigen-3.3.7.tar.bz2
  fi

  cd $EIGEN_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake ..
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $DEPS_DIR/$EIGEN_DIR/$BUILD_DIR
  sudo make -j$NUM_PROCESSORS install >/dev/null
}

install_json() {
  # search for nlohmann in /usr/local/include
  if [ -d '/usr/local/include/nlohmann' ]; then
    echo "Found nlohmann. Not installing"
    return
  else
    echo "nlohmann not found in /usr/local/include, installing now."
  fi

  JSON_DIR="json"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$JSON_DIR" ]; then
    git clone --depth 1 -b v3.6.1 https://github.com/nlohmann/json.git
  fi

  cd $JSON_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake ..
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $DEPS_DIR/$JSON_DIR/$BUILD_DIR
  sudo make -j$NUM_PROCESSORS install >/dev/null
}

install_dbow3() {
  # search for DBow3 in /usr/local/include
  if [ -d '/usr/local/include/DBow3' ]; then
    echo "Found DBow3. Not installing"
    return
  else
    echo "DBow3 not found in /usr/local/include, installing now."
  fi

  DBOW_DIR="DBow3"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$DBOW_DIR" ]; then
    git clone --depth 1 git@github.com:BEAMRobotics/DBow3.git
  fi

  cd $DBOW_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake ..
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $DEPS_DIR/$DBOW_DIR/$BUILD_DIR
  sudo make -j$NUM_PROCESSORS install >/dev/null
}

install_opencv4() {
  # search for opencv4 in /usr/local/share
  if [ -d '/usr/local/share/opencv4' ]; then
    echo "Found opencv4. Not installing"
    return
  else
    echo "opencv4 not found in /usr/local/share, installing now."
  fi

  SRC_PATH=$DEPS_DIR

  # check if opencv src path set, if true then we will clone there
  if [ -z "$OPENCV_SRC_PATH" ]; then
    echo "cloning opencv4 to $DEPS_DIR"
  else
    echo "cloning opencv4 to $OPENCV_SRC_PATH"
    SRC_PATH=$OPENCV_SRC_PATH
  fi

  mkdir -p $SRC_PATH
  cd $SRC_PATH

  # first, get opencv_contrib
  OPENCV_CONTRIB_DIR="opencv_contrib"
  BUILD_DIR="build"
  VERSION="4.5.2"

  if [ ! -d "$OPENCV_CONTRIB_DIR" ]; then
    git clone --depth 1 -b $VERSION https://github.com/opencv/opencv_contrib.git
  fi

  cd $OPENCV_CONTRIB_DIR

  # next, install opencv and link to opencv_contrib
  cd $SRC_PATH
  OPENCV_DIR="opencv"
  VERSION="4.5.2"

  if [ ! -d "$OPENCV_DIR" ]; then
    git clone --depth 1 -b $VERSION https://github.com/opencv/opencv.git
  fi

  cd $OPENCV_DIR

  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake -DOPENCV_ENABLE_NONFREE:BOOL=ON -DOPENCV_EXTRA_MODULES_PATH=$SRC_PATH/$OPENCV_CONTRIB_DIR/modules ..
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $SRC_PATH/$OPENCV_DIR/$BUILD_DIR
  make_with_progress -j$NUM_PROCESSORS

  if (($INSTALL_OPENCV4_LOCALLY == 1)); then
    echo "Not installing opencv4 to system"
  else
    echo "Installing opencv4 to system"
    sudo make install >/dev/null
    # echo "removing opencv4 src/build files"
    # rm -rf $SRC_PATH/$OPENCV_DIR
    # rm -rf $SRC_PATH/$OPENCV_CONTRIB_DIR
  fi
}

# install functions that are not required by beam_robotics, though are compatible with the beam robotics stack

# serves a general purpose within the beam robotics stack for parallel computing
install_cuda() {
  echo "Installing cuda..."
  sudo apt-get purge nvidia-cuda*
  wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-ubuntu1604.pin
  sudo mv cuda-ubuntu1604.pin /etc/apt/preferences.d/cuda-repository-pin-600
  wget https://developer.download.nvidia.com/compute/cuda/11.2.0/local_installers/cuda-repo-ubuntu1604-11-2-local_11.2.0-460.27.04-1_amd64.deb
  sudo dpkg -i cuda-repo-ubuntu1604-11-2-local_11.2.0-460.27.04-1_amd64.deb
  sudo apt-key add /var/cuda-repo-ubuntu1604-11-2-local/7fa2af80.pub
  sudo apt-get update
  sudo apt-get -y install cuda
  echo "cuda successfully installed."
}

# serves a general purpose within the beam robotics stack for machine learning
install_pytorch() {
  if test -f "/usr/bin/python3.7"; then
    echo "Python version 3.7 found."
  else
    echo "Installing python3.7..."
    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt-get update
    sudo apt-get install python3.7-dev
  fi

  echo "Installing pytorch..."
  PYTORCH_DIR="pytorch"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$DEPS_DIR/$PYTORCH_DIR" ]; then
    git clone --depth 1 -b v1.7.0 --recurse-submodule https://github.com/pytorch/pytorch.git $DEPS_DIR/$PYTORCH_DIR
  fi

  cd $PYTORCH_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake -DBUILD_SHARED_LIBS:BOOL=ON -DCMAKE_BUILD_TYPE:STRING=Release -DPYTHON_EXECUTABLE:PATH=/usr/bin/python3.7 -DPYTHON_LIBRARY:PATH=/usr/lib/python3.7 -DPYTHON_INCLUDE_DIR:PATH=/usr/include/python3.7 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/ -DUSE_CUDA:BOOL=OFF ..
    sudo cmake --build . --target install
  fi
}

# serves a general purpose within the beam robotics stack for machine learning
install_pytorch_cuda() {
  if test -f "/usr/bin/python3.7"; then
    echo "Python version 3.7 found."
  else
    echo "Installing python3.7..."
    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt-get update
    sudo apt-get install python3.7-dev
  fi

  echo "Installing pytorch..."
  PYTORCH_DIR="pytorch"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$DEPS_DIR/$PYTORCH_DIR" ]; then
    git clone --depth 1 -b v1.7.0 --recurse-submodule https://github.com/pytorch/pytorch.git $DEPS_DIR/$PYTORCH_DIR
  fi

  cd $PYTORCH_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake -DBUILD_SHARED_LIBS:BOOL=ON -DCMAKE_BUILD_TYPE:STRING=Release -DPYTHON_EXECUTABLE:PATH=/usr/bin/python3.7 -DPYTHON_LIBRARY:PATH=/usr/lib/python3.7 -DPYTHON_INCLUDE_DIR:PATH=/usr/include/python3.7 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/ -DUSE_CUDA:BOOL=ON ..
    sudo cmake --build . --target install
  fi
}

# serves a general purpose within the beam robotics stack to pull and create docker containers
install_docker() {
  # installation process follows https://docs.docker.com/engine/install/ubuntu/

  # uninstall old versions
  # sudo apt-get remove docker docker-engine docker.io containerd runc

  # set up the repository
  sudo apt-get update
  sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  # install Docker Engine
  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io

  # version 5:20.10.7~3-0 is stable on bionic
  sudo apt-get install docker-ce=5:20.10.7~3-0~ubuntu-$UBUNTU_CODENAME \
    docker-ce-cli=5:20.10.7~3-0~ubuntu-$UBUNTU_CODENAME containerd.io

  # test install
  sudo docker run hello-world
}

# required by LVI-SAM/LIO-SAM
install_gtsam() {
  GTSAM_VERSION="4.0.2"
  GTSAM_URL="git@github.com:borglab/gtsam.git"
  GTSAM_DIR="gtsam"
  BUILD_DIR="build"

  if (find /usr/local/lib -name libgtsam.so | grep -q /usr/local/lib); then
    #if (ldconfig -p | grep -q libgtsam.so); then
    echo "GTSAM version $GTSAM_VERSION is already installed."
  else
    echo "Installing GTSAM version $GTSAM_VERSION ..."
    mkdir -p $DEPS_DIR
    cd $DEPS_DIR

    if [ ! -d "$GTSAM_DIR" ]; then
      git clone --depth 1 -b $GTSAM_VERSION $GTSAM_URL
    fi

    cd $GTSAM_DIR
    git checkout -b $GTSAM_VERSION
    if [ ! -d "$BUILD_DIR" ]; then
      mkdir -p $BUILD_DIR
      cd $BUILD_DIR
      cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DGTSAM_USE_SYSTEM_EIGEN=ON -DGTSAM_BUILD_UNSTABLE=ON -DGTSAM_BUILD_WRAP=OFF \
        -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF -DGTSAM_BUILD_DOCS=OFF
      make_with_progress -j$NUM_PROCESSORS
    fi

    cd $DEPS_DIR/$GTSAM_DIR/$BUILD_DIR
    sudo make install >/dev/null
    echo "GTSAM installed successfully"
  fi
}

# required by beam_slam
install_qwt() {
  sudo apt-get install libqwt-dev
}

# required by beam_slam
install_sophus() {
  SOPHUS_DIR="Sophus"
  BUILD_DIR="build"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  sudo apt-get install gfortran libc++-dev libgoogle-glog-dev libatlas-base-dev libsuitesparse-dev
  if [ ! -d "$SOPHUS_DIR" ]; then
    git clone git@github.com:strasdat/Sophus.git $DEPS_DIR/$SOPHUS_DIR
  fi

  cd $SOPHUS_DIR
  git checkout 936265f # required by basalt
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake ..
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $DEPS_DIR/$SOPHUS_DIR/$BUILD_DIR
  sudo make install >/dev/null
}

# required by beam_slam
install_teaserpp() {
  TEASERPP_DIR="TEASER-plusplus"
  BUILD_DIR="build"

  mkdir -p $DEPS_DIR
  cd $DEPS_DIR

  if [ ! -d "$TEASERPP_DIR" ]; then
    echo "teaserpp not found... cloning"
    git clone --depth 1 https://github.com/BEAMRobotics/TEASER-plusplus
  fi

  cd $TEASERPP_DIR
  if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    cmake .. >/dev/null
    make_with_progress -j$NUM_PROCESSORS
  fi

  cd $DEPS_DIR/$TEASERPP_DIR/$BUILD_DIR
  sudo make -j$NUM_PROCESSORS install >/dev/null
}

# required by beam_simulation
install_gazebo() {
  # tested with ros melodic
  sudo sh -c 'echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable `lsb_release -cs` main" > /etc/apt/sources.list.d/gazebo-stable.list'
  wget https://packages.osrfoundation.org/gazebo.key -O - | sudo apt-key add -
  sudo apt update
  sudo apt upgrade
  sudo apt install gazebo11-common
  sudo apt install libgazebo11
  sudo apt-get install ros-$ROS_DISTRO-gazebo-ros ros-$ROS_DISTRO-gazebo-plugins
  sudo apt-get install ros-$ROS_DISTRO-gazebo-ros-pkgs ros-$ROS_DISTRO-gazebo-ros-control

  # husky
  sudo apt-get install ros-$ROS_DISTRO-husky-desktop ros-$ROS_DISTRO-husky-description ros-$ROS_DISTRO-husky-viz
  sudo apt-get install ros-$ROS_DISTRO-husky-simulator

  # jackal
  sudo apt-get install ros-$ROS_DISTRO-jackal-desktop ros-$ROS_DISTRO-jackal-description ros-$ROS_DISTRO-jackal-navigation
  sudo apt-get install ros-$ROS_DISTRO-jackal-simulator

  cd $CATKIN_DIR/src
  if [ ! -d "roben_description" ]; then
    echo "cloning roben_description..."
    git clone git@github.com:BEAMRobotics/roben_description.git
  fi
  if [ ! -d "roben_simulation" ]; then
    echo "cloning roben_simulation..."
    git clone git@github.com:BEAMRobotics/roben_simulation.git
  fi

  # sensors
  sudo apt-get install ros-$ROS_DISTRO-velodyne-simulator

  # teleop
  sudo apt-get install ros-$ROS_DISTRO-teleop-twist-joy
  sudo apt-get install ros-$ROS_DISTRO-teleop-twist-keyboard
}
