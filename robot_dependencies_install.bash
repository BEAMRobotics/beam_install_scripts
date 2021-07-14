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

install_gps()
{
    echo "installing GPS piksi deps..."
    yes | source $INSTALL_SCRIPTS/install_piksi_deps.bash
}

install_um7()
{
    echo "installing um7 driver..."
    sudo apt-get install ros-kinetic-um7 #install ros driver
    sudo apt-get install ros-kinetic-geographic-msgs
}

install_flir_blackfly()
{
    echo "configuring spinnaker driver..."
    sudo bash /home/"$USER"/catkin_ws/src/ros_drivers/flir_camera_driver/spin-conf
}

install_husky_packages()
{
    echo "installing husky dependencies..."
    sudo apt-get install ros-kinetic-controller-manager* \
    ros-kinetic-teleop-* \
    ros-kinetic-twist-mux* \
    ros-kinetic-lms1xx \
    ros-kinetic-ur-description \
    ros-kinetic-joint-state-publisher \
    ros-kinetic-joint-state-controller \
    ros-kinetic-diff-drive-controller
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
    # sudo apt-get install libavcodec57 libavformat57 libswscale4 libswresample2 libavutil55 

    if [ ! -d "$LB_DIR" ]; then
        echo "Don't have Spinnaker SDK Directory, creating & downloading SDK..."
        mkdir -p $LB_DIR
        cd $LB_DIR
        wget https://www.dropbox.com/s/4mdyatl3du0fh7w/spinnaker-1.21.0.61-amd64-Ubuntu16.04-pkg.tar.gz?dl=0
        tar -xvf spinnaker-1.21.0.61-amd64-Ubuntu16.04-pkg.tar.gz?dl=0
        rm -rf spinnaker-1.21.0.61-amd64-Ubuntu16.04-pkg.tar.gz?dl=0
        cd spinnaker-1.21.0.61-amd64/
        printf "y\nn\n" | sudo sh install_spinnaker.sh
        echo "Spinnaker SDK successfully installed."
    else
	echo "Already have spinnaker folder..."
        cd $LB_DIR
        cd spinnaker-1.21.0.61-amd64/
        printf "y\nn\n" | sudo sh install_spinnaker.sh
        echo "Spinnaker SDK successfully installed."
    fi
}

install_rosserial()
{
    echo "Installing rosserial..."
    sudo apt-get install ros-kinetic-rosserial-arduino
    sudo apt-get install ros-kinetic-rosserial
    echo "Done."
}
