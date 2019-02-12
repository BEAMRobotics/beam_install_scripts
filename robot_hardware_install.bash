#!/bin/bash
set -e

# Installation necessary when using hardware on the husky robot

# Specify location of installation scripts
INSTALL_SCRIPTS=$"$HOME/software/beam_install_scripts"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


main()
{
    clone_ros_drivers
    install_ximea_deps
    update_udev
    install_gps
    install_um7
    install_flir_blackfly
    install_libpcap
    install_husky_packages
    enable_passwordless_sudo
    install_chrony_deps
    catkin_build
}

catkin_build()
{
    cd /home/"$USER"/catkin_ws
    catkin build
}

install_chony_deps()
{
    echo "installing chrony and its dependencies"
    sudo apt-get install gpsd gpsd-clients chrony
}

clone_ros_drivers()
{
    if [ ! -d /home/"$USER"/projects ]; then
    	mkdir /home/"$USER"/projects
    fi
    if [ -d /home/"$USER"/projects/ros_drivers ]; then
        echo "ros_drivers already installed in /home/"$USER"/projects/"
        echo "make sure there is a symlink in catkin_ws"
    fi
    if [ ! -d /home/"$USER"/projects/ros_drivers ]; then
        cd /home/"$USER"/projects
        echo "installing ros_drivers to /home/"$USER"/projects"
        git clone --recursive https://github.com/BEAMRobotics/ros_drivers.git
        echo "creating link in /home/"$USER"/catkin_ws/src/ to /home/"$USER"/projects"
        ln -s /home/"$USER"/projects/ros_drivers /home/"$USER"/catkin_ws/src/
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
    echo "installing piksi gps dependencies.."
    cd ~/
    mkdir -p software
    cd software # cd to a directory where you will download and build libsbp
    git clone https://github.com/swift-nav/libsbp 
    cd libsbp/c
    mkdir build
    cd build
    cmake ..
    make
    sudo make install # install headers and libraries into /usr/local
    
    bash /home/"$USER"/catkin_ws/src/ros_drivers/ethz_piksi_ros/piksi_multi_rtk_ros/install/install_piksi_multi.sh
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

install_libpcap()
{
    # for velodyne driver
    echo "installing velodyne driver dependencies..."
    sudo apt-get install libpcap-dev
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

main
