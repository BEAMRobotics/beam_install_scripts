#!/bin/bash
set -e

# helper function for building catkin packages
catkin_build() {
  cd $CATKIN_DIR
  catkin build -j$NUM_PROCESSORS
}

# install functions required to compile and run software for beam robots

# required by ig2
install_husky_packages() {
  echo "installing husky dependencies..."
  sudo apt-get install ros-$ROS_DISTRO-controller-manager* \
    ros-$ROS_DISTRO-teleop-* \
    ros-$ROS_DISTRO-twist-mux* \
    ros-$ROS_DISTRO-lms1xx \
    ros-$ROS_DISTRO-ur-description \
    ros-$ROS_DISTRO-joint-state-publisher \
    ros-$ROS_DISTRO-joint-state-controller \
    ros-$ROS_DISTRO-diff-drive-controller
}

install_ig_handle() {
  cd $CATKIN_DIR/src/
  echo "Installing ig-handle driver and dependencies..."

  IG_HANDLE_DIR="ig_handle"
  if [ ! -d "$IG_HANDLE_DIR" ]; then
    echo "$IG_HANDLE_DIR does not exist, cloning driver..."
    git clone git@github.com:BEAMRobotics/ig_handle.git
  else
    echo "$IG_HANDLE_DIR exists."
  fi

  sudo apt-get install sharutils

  update_udev
  install_spinnaker_sdk
  install_mti_sdk
  install_arduino_teensyduino
}

update_udev() {
  echo "copying udev rules..."
  sudo cp $CATKIN_DIR/src/ig_handle/config/99-ig2_udev.rules /etc/udev/rules.d/
  sudo udevadm control --reload-rules && sudo service udev restart && sudo udevadm trigger
  sudo cp $CATKIN_DIR/src/ig_handle/config/01-ig2_netplan.yaml /etc/netplan/
}

install_spinnaker_sdk() {
  echo "Installing Spinnaker SDK..."
  SP_DIR="spinnaker"
  SP_SDK_DIR="spinnaker-2.4.0.143-amd64"
  mkdir -p $DEPS_DIR && cd $DEPS_DIR
  mkdir -p $SP_DIR && cd $SP_DIR

  sudo apt-get install libusb-1.0-0 libgtkmm-2.4-dev
  sudo apt-get install ros-$ROS_DISTRO-image-common
  sudo apt-get install ros-$ROS_DISTRO-image-exposure-msgs
  sudo apt-get install ros-$ROS_DISTRO-wfov-camera-msgs
  sudo apt-get install ros-$ROS_DISTRO-image-proc

  # download Spinnaker SDK from sri_lab/robotics/software/apis/spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
  if [ ! -d "$SP_SDK_DIR" ]; then
    echo "Spinnaker SDK directory does not exist, downloading SDK..."
    gdown 1_nT47nHHy6ugRxHH4frLV29wgCRhSRGF
    tar fxv spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
  fi

  # see installation wiki for correct input
  cd $SP_SDK_DIR
  sudo sh remove_spinnaker.sh
  sudo sh install_spinnaker.sh

  cd $CATKIN_DIR/src/
  FLIR_CAMERA_DRIVER_DIR="flir_camera_driver"
  if [ ! -d "$FLIR_CAMERA_DRIVER_DIR" ]; then
    echo "$FLIR_CAMERA_DRIVER_DIR does not exist, cloning driver..."
    git clone git@github.com:ros-drivers/flir_camera_driver.git
  else
    echo "$FLIR_CAMERA_DRIVER_DIR exists."
  fi
}

install_mti_sdk() {
  echo "Installing MTI SDK..."
  MT_DIR="mti"
  MT_SDK_DIR="MT_Software_Suite_linux-x64_2021.2"
  mkdir -p $DEPS_DIR && cd $DEPS_DIR
  mkdir -p $MT_DIR && cd $MT_DIR

  # download MTI SDK from sri_lab/robotics/software/apis/MT_Software_Suite_linux-x64_2021.2.tar.gz
  if [ ! -d "$MT_SDK_DIR" ]; then
    echo "MTI SDK directory does not exist, downloading SDK..."
    gdown 1kTxxwwFHyDAJadEMhEjLIAN9_MnDgX-z
    tar xvf MT_Software_Suite_linux-x64_2021.2.tar.gz
    cd $MT_SDK_DIR
    tar xvf mtmanager_linux-x64_2021.2.tar.gz
    tar xvf magfieldmapper_linux-x64_2021.2.tar.gz
  else
    cd $MT_SDK_DIR
  fi

  # require user to enter default 'Xsens MT SDK' installation directory:
  #   [/usr/local/xsens]
  sudo sh mtsdk_linux-x64_2021.2.sh

  # create symbolic link for driver in catkin workspace
  rm -rf $CATKIN_DIR/src/xsens_ros_mti_driver
  ln -s /usr/local/xsens/xsens_ros_mti_driver $CATKIN_DIR/src

  # build core library
  cd /usr/local/xsens/xsens_ros_mti_driver/lib/xspublic
  sudo make -j$NUM_PROCESSORS >/dev/null
}

install_arduino_teensyduino() {
  echo "Installing Arduino and Teensyduino..."

  ARDUINO_DIR="$HOME/Arduino" # default location of <sketchbook>
  ARDUINO_TEENSYDUINO_INSTALL_DIR="$HOME/software/arduino_teensyduino"
  mkdir -p $ARDUINO_TEENSYDUINO_INSTALL_DIR && cd $ARDUINO_TEENSYDUINO_INSTALL_DIR

  # 1. Install Arduino + Teensyduino
  if [ ! -d "arduino-1.8.13" ]; then
    echo "arduino-1.8.13 does not exist, downloading..."
    wget https://downloads.arduino.cc/arduino-1.8.13-linux64.tar.xz
    tar -xf arduino-1.8.13-linux64.tar.xz
    rm -rf arduino-1.8.13-linux64.tar.xz
  fi

  if [ ! -f "TeensyduinoInstall.linux64" ]; then
    echo "TeensyduinoInstall.linux64 does not exist, downloading..."
    wget https://www.pjrc.com/teensy/td_153/TeensyduinoInstall.linux64
  fi

  if [ ! -f "00-teensy.rules" ]; then
    echo "00-teensy.rules does not exist, downloading..."
    wget https://www.pjrc.com/teensy/00-teensy.rules
  fi

  sudo cp 00-teensy.rules /etc/udev/rules.d/
  chmod 755 TeensyduinoInstall.linux64

  # Note: we have elected to install via the gui as specifying --dir leads to errors upon repeat installs.
  # Note: If you receive the following error:
  #   Unable to write file to "hardware/tools/teensy"
  # reboot your system and continue install
  echo "TeensyduinoInstall: When prompted to 'Select Arduino Folder', enter $ARDUINO_TEENSYDUINO_INSTALL_DIR/arduino-1.8.13"
  sudo ./TeensyduinoInstall.linux64

  # build core libraries for teensy3
  cd $ARDUINO_TEENSYDUINO_INSTALL_DIR/arduino-1.8.13/hardware/teensy/avr/cores/teensy3
  sudo make -j$NUM_PROCESSORS >/dev/null

  # build core libraries for teensy4 (ig-handle currently does not support teensy4)
  # cd $ARDUINO_TEENSYDUINO_INSTALL_DIR/arduino-1.8.13/hardware/teensy/avr/cores/teensy4
  # sudo make -j$NUM_PROCESSORS >/dev/null

  # install arduino IDE and setup udev rules
  cd $ARDUINO_TEENSYDUINO_INSTALL_DIR/arduino-1.8.13/
  ./uninstall.sh && ./install.sh && ./arduino-linux-setup.sh $USER

  # 2. Install rosserial
  sudo apt-get install ros-$ROS_DISTRO-rosserial
  sudo apt-get install ros-$ROS_DISTRO-rosserial-arduino

  # 3. Install ros_lib
  # Note: If you receive the following error:
  #   Unable to build service: rviz/SendFilePath
  # you may ignore this warning
  mkdir -p $ARDUINO_DIR/libraries && cd $ARDUINO_DIR/libraries
  rm -rf ros_lib
  rosrun rosserial_arduino make_libraries.py . >/dev/null
}

install_dt100() {
  echo "Installing DT100 driver and dependencies..."
  DT100_DIR="dt100_driver"
  cd $CATKIN_DIR/src/

  if [ ! -d "$DT100_DIR" ]; then
    echo "$DT100_DIR does not exist, cloning driver..."
    git clone git@github.com:BEAMRobotics/dt100_driver.git
  else
    echo "$DT100_DIR exists."
  fi

  install_virtual_box
  VM_DIR="/home/$USER/virtual_machines/"
  mkdir -p $VM_DIR && cd $VM_DIR

  # download Windows XP 32 DT100 virtual machine from sri_lab/robotics/software/vms/Windows_XP_32_DT100.ova
  if [ ! -d "/home/$USER/VirtualBox\ VMs/Windows_XP_32_DT100" ]; then
    if [ ! -f "Windows_XP_32_DT100.ova" ]; then
      echo "Importing virtual machine required by $DT100_DIR..."
      gdown 1_X6_pstzYwIVQBICmkU4EMvxtBkayy_1
      vboxmanage import Windows_XP_32_DT100.ova
    else
      echo "virtual machine required by $DT100_DIR has already been imported."
    fi
  fi
}

install_virtual_box() {
  echo "Installing Virtual Box..."
  wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
  wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
  echo "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
  sudo apt update
  sudo apt-get install virtualbox-6.1
}
