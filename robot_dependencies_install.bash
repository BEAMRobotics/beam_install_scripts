#!/bin/bash
set -e

# This script contains a series of functions to install dependencies for beam robots.

catkin_build()
{
  cd /home/"$USER"/catkin_ws
  catkin build
}



install_chrony_deps()
{
  echo "installing chrony and its dependencies"
  sudo dpkg --configure -a
  sudo apt-get update
  sudo apt-get install gpsd gpsd-clients chrony
}

clone_ros_drivers()
{
  PROJECTS_DIR="/home/$USER/projects"

  if [ ! -d "$PROJECTS_DIR" ]; then
    mkdir $PROJECTS_DIR
  fi

  if [ -d $PROJECTS_DIR/ros_drivers ]; then
    echo "ros_drivers already installed in $PROJECTS_DIR"
    echo "ensure there is a symlink in catkin_ws"
  else
    cd $PROJECTS_DIR
    echo "cloning ros_drivers to $PROJECTS_DIR..."
    git clone --recursive git@github.com:BEAMRobotics/ros_drivers.git
    echo "creating link in /home/"$USER"/catkin_ws/src/ to $PROJECTS_DIR"
    ln -s $PROJECTS_DIR/ros_drivers /home/"$USER"/catkin_ws/src/
  fi
}

install_ximea_deps()
{
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

update_udev()
{
  # copy udev rules from inspector_gadget
  echo "copying udev rules..."
  sudo cp ~/catkin_ws/src/ros_drivers/udev/* /etc/udev/rules.d/
  sudo udevadm control --reload-rules && sudo service udev restart && sudo udevadm trigger
}

update_udev_ig2()
{
  # copy udev rules from inspector_gadget
  echo "copying udev rules..."
  sudo cp ~/catkin_ws/src/ig_hangle/config/99-ig2_udev.rules /etc/udev/rules.d/
  sudo udevadm control --reload-rules && sudo service udev restart && sudo udevadm trigger
  sudo cp ~/catkin_ws/src/ig_hangle/config/01-ig2_netplan.yaml /etc/netplan/
}

install_ig_handle()
{
  
  cd /home/"$USER"/catkin_ws/src/
  echo "Installing Ig Handle files"
  git clone git@github.com:BEAMRobotics/ig_handle.git 
  pip install gdown
  pip install --upgrade gdown
  sudo apt-get install sharutils
  # we only want these to be called if we use install_ig_handle
  install_spinnaker_sdk  
  install_mti_sdk
  install_arduino_teensyduino
}

install_gps()
{
  echo "installing GPS piksi deps..."
  yes | source $INSTALL_SCRIPTS/install_piksi_deps.bash
}

install_um7()
{
  echo "installing um7 driver..."
  sudo apt-get install ros-$ROS_DISTRO-um7 #install ros driver
  sudo apt-get install ros-$ROS_DISTRO-geographic-msgs
}

install_husky_packages()
{
  echo "installing husky dependencies..."
  sudo apt-get install ros-$ROS_DISTRO-controller-manager* \
  ros-$ROS_DISTRO-teleop-* \
  ros-$ROS_DISTRO-twist-mux* \
  ros-$ROS_DISTRO-lms1xx \
  ros-$ROS_DISTRO-ur-description \
  # ros-$ROS_DISTRO-joint-state-publisher \
  # ros-$ROS_DISTRO-joint-state-controller \
  ros-$ROS_DISTRO-diff-drive-controller
}

enable_passwordless_sudo()
{
  #sudo echo 'robot ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
  echo "robot ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
}


install_spinnaker_sdk()
{
  
  echo "Installing spinnaker SDK..."
  LB_DIR="spinnaker"
  mkdir -p $DEPS_DIR
  cd $DEPS_DIR
  sudo apt-get install libusb-1.0-0 libgtkmm-2.4-dev
  sudo apt-get install ros-$ROS_DISTRO-image-common
  sudo apt-get install ros-$ROS_DISTRO-image-exposure-msgs
  sudo apt-get install ros-$ROS_DISTRO-wfov-camera-msgs
  sudo apt-get install ros-$ROS_DISTRO-image-proc
  
  # sudo apt-get install libavcodec57 libavformat57 libswscale4 libswresample2 libavutil55 

  if [ ! -d "$LB_DIR" ]; then
    echo "Don't have Spinnaker SDK Directory, creating & downloading SDK..."
    mkdir -p $LB_DIR
    cd $LB_DIR
    
    # Eventually replace with better links. Currently in adthoms Dropbox
    if [ "$ROS_DISTRO" = "kinetic" ]; then
      # gets the file for spinnekar from the google drive folder we have
      gdown --id 1se0fe_gu2IOxQHwVEdKLcOANbWdqoAAi 
      # extracts the files we have retrieved and places them in a directory with the given file names       
      tar fxv spinnaker-2.0.0.146-Ubuntu16.04-amd64-pkg.tar.gz
      rm -rf spinnaker-2.0.0.146-Ubuntu16.04-amd64-pkg.tar.gz?dl=0      
      cd spinnaker-2.0.0.146-amd64
    elif [ "$ROS_DISTRO" = "melodic" ]; then
      gdown --id 1_nT47nHHy6ugRxHH4frLV29wgCRhSRGF      
      tar fxv spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
      rm -rf spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz      
      cd spinnaker-2.4.0.143-amd64
    fi
    sudo sh install_spinnaker.sh
    echo "Spinnaker SDK successfully installed."
  else
    echo "Already have spinnaker folder..."
    cd $LB_DIR
    if [ "$ROS_DISTRO" = "kinetic" ]; then      
      gdown --id 1se0fe_gu2IOxQHwVEdKLcOANbWdqoAAi          
      tar fxv spinnaker-2.0.0.146-Ubuntu16.04-amd64-pkg.tar.gz
      rm -rf spinnaker-2.0.0.146-Ubuntu16.04-amd64-pkg.tar.gz
      cd spinnaker-2.0.0.146-amd64
    elif [ "$ROS_DISTRO" = "melodic" ]; then
      gdown --id 1_nT47nHHy6ugRxHH4frLV29wgCRhSRGF
      tar fxv spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
      rm -rf spinnaker-2.4.0.143-Ubuntu18.04-amd64-pkg.tar.gz
      cd spinnaker-2.4.0.143-amd64
    fi
    sudo sh install_spinnaker.sh
    echo "Spinnaker SDK successfully installed."
  fi
}

install_arduino_teensyduino()
{
  echo "Installing rosserial..."
  sudo apt-get install ros-$ROS_DISTRO-rosserial-arduino
  sudo apt-get install ros-$ROS_DISTRO-rosserial
  echo "rosserial successfully installed."

  echo "Installing arduino and Teensyduino"
  wget https://downloads.arduino.cc/arduino-1.8.13-linux64.tar.xz  
  wget https://www.pjrc.com/teensy/td_153/TeensyduinoInstall.linux64  
  wget https://www.pjrc.com/teensy/00-teensy.rules  
  sudo cp 00-teensy.rules /etc/udev/rules.d/  
  tar -xf arduino-1.8.13-linux64.tar.xz  
  chmod 755 TeensyduinoInstall.linux64  
  ./TeensyduinoInstall.linux64 --dir=arduino-1.8.13 
   
}

install_virtual_box()
{
  echo "Installing Virtual Box..."
  wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
  wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
  echo "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
  sudo apt update
  sudo apt-get install virtualbox-6.1
  echo "Virtual Box successfully installed."
}


install_dt100()
{
  echo "Installing dt100 dependencies..."
  install_virtual_box
  
  VM_DIR="/home/$USER/virtual_machines/"
  mkdir -p $VM_DIR

  cd $VM_DIR
  if [ ! -d "/home/$USER/VirtualBox\ VMs/Windows_XP_32_DT100" ]; then
    if [ ! -f "Windows_XP_32_DT100.ova" ]; then
      echo "Importing virtual machine..."
      gdown --id 1_X6_pstzYwIVQBICmkU4EMvxtBkayy_1
      mv Windows_XP_32_DT100.ova Windows_XP_32_DT100.ova
      vboxmanage import Windows_XP_32_DT100.ova
    else 
      echo "virtual machine has already been imported."
    fi
  fi
  echo "dt100 dependencies successfully installed."
}


install_mti_sdk()
{
  # creates a directory to store the MTI software
  MT_DIR="MTIsoftware"  
  mkdir -p $MT_DIR
  cd $MT_DIR  
  gdown --id 1kTxxwwFHyDAJadEMhEjLIAN9_MnDgX-z     
  tar xvf MT_Software_Suite_linux-x64_2021.2.tar.gz  
  cd MT_Software_Suite_linux-x64_2021.2 
  tar xvf mtmanager_linux-x64_2021.2.tar.gz
  tar xvf magfieldmapper_linux-x64_2021.2.tar.gz
  rm -rf MT_Software_suite_linux-x64_2021.2.tar.gz
  rm -rf mtmanager_linux-x64_2021.2.tar.gz
  rm -rf magfieldmapper_linux-x64_2021.2.tar.gz 
   
  chmod +x mtsdk_linux-x64_2021.2.sh
  bash mtsdk_linux-x64_2021.2.sh
    
}
