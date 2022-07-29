#!/bin/bash
set -e

# This script contains a series of functions to install dependencies for beam robots.

catkin_build() {
  cd $CATKIN_DIR
  catkin build
}

install_chrony_deps() {
  echo "installing chrony and its dependencies"
  sudo dpkg --configure -a
  sudo apt-get update
  sudo apt-get install gpsd gpsd-clients chrony
}

install_ximea_deps() {
  echo "installing ximea dependencies..."
  cd ~/
  mkdir tmp
  cd tmp
  wget https://www.ximea.com/support/attachments/download/271/XIMEA_Linux_SP.tgz
  tar -xf XIMEA_Linux_SP.tgz
  cd package
  ./install -cam_usb30
  cd ~
  rm -rf tmp
  sudo gpasswd -a $USER plugdev
  echo '#!/bin/sh -e' | sudo tee /etc/rc.local
  echo "echo 0 > /sys/module/usbcore/parameters/usbfs_memory_mb" | sudo tee -a /etc/rc.local
  echo "exit 0" | sudo tee -a /etc/rc.local
  echo "*               -       rtprio          0" | sudo tee -a /etc/security/limits.conf
  echo "@realtime       -       rtprio          81" | sudo tee -a /etc/security/limits.conf
  echo "*               -       nice            0" | sudo tee -a /etc/security/limits.conf
  echo "@realtime       -       nice            -16" | sudo tee -a /etc/security/limits.conf
  sudo groupadd realtime
  sudo gpasswd -a $USER realtime
}

update_udev() {
  # copy udev rules from ig_handle
  echo "copying udev rules..."
  sudo cp $CATKIN_DIR/src/ig_handle/config/99-ig2_udev.rules /etc/udev/rules.d/
  sudo udevadm control --reload-rules && sudo service udev restart && sudo udevadm trigger
  sudo cp $CATKIN_DIR/src/ig_handle/config/01-ig2_netplan.yaml /etc/netplan/
  echo "udev rules copied."
}

install_ig_handle() {
  IG_HANDLE_DIR="ig_handle"
  cd $CATKIN_DIR/src/
  echo "Installing ig-handle driver and dependencies..."

  if [ ! -d "$IG_HANDLE_DIR" ]; then
    echo "$IG_HANDLE_DIR does not exist, cloning driver..."
    git clone git@github.com:BEAMRobotics/ig_handle.git
  else
    echo "$IG_HANDLE_DIR exists."
  fi

  sudo apt-get install sharutils
  install_spinnaker_sdk
  install_mti_sdk
  install_arduino_teensyduino
  update_udev
}

install_gps() {
  echo "installing GPS piksi deps..."
  yes | source $INSTALL_SCRIPTS/install_piksi_deps.bash
}

install_um7() {
  echo "installing um7 driver..."
  sudo apt-get install ros-$ROS_DISTRO-um7 #install ros driver
  sudo apt-get install ros-$ROS_DISTRO-geographic-msgs
}

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

enable_passwordless_sudo() {
  #sudo echo 'robot ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
  echo "robot ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
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
  # sudo apt-get install libavcodec57 libavformat57 libswscale4 libswresample2 libavutil55

  # download Spinnaker SDK from sri_lab/robotics/software/apis/spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
  if [ ! -d "$SP_SDK_DIR" ]; then
    echo "Spinnaker SDK directory does not exist, downloading SDK..."
    gdown 1_nT47nHHy6ugRxHH4frLV29wgCRhSRGF
    tar fxv spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
    rm -rf spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
  fi

  cd $SP_SDK_DIR
  sudo sh install_spinnaker.sh
  echo "Spinnaker SDK successfully installed."
}

install_arduino_teensyduino() {
  echo "Installing arduino and Teensyduino..."
  sudo apt-get install ros-$ROS_DISTRO-rosserial
  sudo apt-get install ros-$ROS_DISTRO-rosserial-arduino

  wget https://downloads.arduino.cc/arduino-1.8.13-linux64.tar.xz
  wget https://www.pjrc.com/teensy/td_153/TeensyduinoInstall.linux64
  wget https://www.pjrc.com/teensy/00-teensy.rules
  sudo cp 00-teensy.rules /etc/udev/rules.d/
  tar -xf arduino-1.8.13-linux64.tar.xz
  chmod 755 TeensyduinoInstall.linux64
  ./TeensyduinoInstall.linux64 --dir=arduino-1.8.13
  echo "arduino and Teensyduino successfully installed."
}

install_virtual_box() {
  echo "Installing Virtual Box..."
  wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
  wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
  echo "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
  sudo apt update
  sudo apt-get install virtualbox-6.1
  echo "Virtual Box successfully installed."
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
  echo "dt100 driver and dependencies successfully installed."
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
    rm -rf MT_Software_suite_linux-x64_2021.2.tar.gz
  fi

  cd $MT_SDK_DIR
  tar xvf mtmanager_linux-x64_2021.2.tar.gz
  tar xvf magfieldmapper_linux-x64_2021.2.tar.gz
  rm -rf mtmanager_linux-x64_2021.2.tar.gz
  rm -rf magfieldmapper_linux-x64_2021.2.tar.gz

  chmod +x mtsdk_linux-x64_2021.2.sh
  bash mtsdk_linux-x64_2021.2.sh

  echo "MTI SDK sucessfully installed."
}
