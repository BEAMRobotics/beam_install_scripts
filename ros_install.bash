#!/bin/bash
set -e  # exit on first error

update_rosdep()
{
    # Prepare rosdep to install dependencies.
    echo "Updating rosdep ..."
    if [ ! -d /etc/ros/rosdep ]; then
        sudo rosdep init > /dev/null
    fi
    rosdep update > /dev/null
}

config_bashrc()
{
    echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> ~/.bashrc

    echo "Would you like to add the following to your bashrc? "
    echo "(If your code is in a different workspace enter n and add manually)"
    echo "  source ~/catkin_ws/devel/setup.bash"
    echo "  ROS_PACKAGE_PATH=/home/$USER/catkin_ws/src:/opt/ros/$ROS_DISTRO/share:$ROS_PACKAGE_PATH"

    while read ans; do
        case "$ans" in
            y) echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc; echo "ROS_PACKAGE_PATH=/home/$USER/catkin_ws/src:/opt/ros/$ROS_DISTRO/share:$ROS_PACKAGE_PATH" >> ~/.bashrc; break;;
            n) break;;
            *) echo "Invalid input (y/n):";;
        esac
    done
}

sudo sh -c "echo \"deb http://packages.ros.org/ros/ubuntu $UBUNTU_CODENAME main\" > /etc/apt/sources.list.d/ros-latest.list"
wget -qO - http://packages.ros.org/ros.key | sudo apt-key add -

echo "Updating package lists ..."
sudo apt-get -qq update

echo "Installing ROS $ROS_DISTRO ..."
sudo apt-get -qq install python-rosinstall python-catkin-pkg python-rosdep python-wstool ros-$ROS_DISTRO-catkin ros-$ROS_DISTRO-desktop > /dev/null
sudo apt-get -qq install ros-$ROS_DISTRO-pcl-ros ros-$ROS_DISTRO-image-transport ros-$ROS_DISTRO-image-transport-plugins ros-$ROS_DISTRO-libg2o > /dev/null
sudo apt-get install ros-$ROS_DISTRO-geographic-msgs
sudo apt-get install ros-$ROS_DISTRO-tf2-geometry-msgs

# ROS environment setup
echo "Setting up ROS environment..."
source /opt/ros/$ROS_DISTRO/setup.bash

echo "Would you like to configure your bashrc to automatically source setup files and set ROS_PACKAGE_PATH?"
echo "(If you have already added it manually or in previous install, enter n)"

while read ans; do
    case "$ans" in
        y) config_bashrc; update_rosdep; break;;
        n) update_rosdep; break;;
        *) echo "Invalid input (y/n):";;
    esac
done

