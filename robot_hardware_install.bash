#!/bin/bash
set -e

# Installation necessary when using hardware on the husky robot

# Specify location of installation scripts
INSTALL_SCRIPTS=$"$HOME/software/beam_install_scripts"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


main()
{
    install_ximea_deps
    update_edev
    install_gps
    install_um7
    install_flir_blackfly
    install_libpcap
    install_husky_packages
    enable_passwordless_sudo
    install_ex_publisher
}


install_ximea_deps()
{
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
    sudo cp ~/catkin_ws/src/beam_robotics/inspector_gadget/udev/* /etc/udev/rules.d/
    sudo udevadm control --reload-rules && sudo service udev restart && sudo udevadm trigger
}

install_gps()
{
    cd ~/
    mkdir -p software
    cd software # cd to a directory where you will download and build libsbp
    git clone https://github.com/swift-nav/libsbp 
    cd libsbp/c
    mkdir build
    cmake ../
    make
    sudo make install # install headers and libraries into /usr/local
    
    echo 'Please enter path to inspector_gadget'
    echo 'Example: ~/projects/inspector_gadget'
    read IG_PATH
    bash $IG_PATH/inspector_gadget/ros_drivers/ethz_piksi_ros/piksi_multi_rtk_ros/install/install/piksi_multi.sh

    cd ~/catkin_ws/src
    git clone https://github.com/nickcharron/swiftnav_ros.git
    cd ..
    catkin_make
}

install_um7()
{
    sudo apt-get install ros-kinetic-um7 #install ros driver
    sudo apt-get install ros-kinetic-geographic-msgs
}

install_flir_blackfly()
{
    echo 'Please enter path to flir_camera_driver'
    echo 'Example: ~/projects/beam_robotics/rps_drivers/flir_camera_driver'
    read FLIR_PATH
    sudo bash $FLIR_PATH/flir_camera_driver/spin-conf.sh
}

install_libpcap()
{
    # for velodyne driver
    sudo apt-get install libpcap-dev
}

install_husky_packages()
{
    sudo apt-get install ros-kinetic-controller-manager*
    ros-kinetic-teleop-*
    ros-kinetic-twist-mux*
    ros-kinetic-lms1xx
    ros-kinetic-ur-description
    ros-kinetic-joint-state-publisher
    ros-kinetic-joint-state-controller
    ros-kinetic-diff-drive-controller   
}

main
enable_passwordless_sudo()
{
    echo 'robot ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers 
}

install_ez_publisher()
{
    sudo apt-get install ros-kinetic-rqt-ez-publisher
}
