#!/bin/bash
set -e  # exit on first error

update_rosdep()
{
    # Prepare rosdep to install dependencies.
    if [ ! -d /etc/ros/rosdep ]; then
        echo "Initializing rosdep ..."
        sudo rosdep init > /dev/null
    fi
    echo "Updating rosdep ..."
    rosdep update > /dev/null
    echo "Done updating rosdep."
}

add_to_bashrc()
{
    echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc
    echo "ROS_PACKAGE_PATH=/home/$USER/catkin_ws/src:/opt/ros/$ROS_DISTRO/share:$ROS_PACKAGE_PATH" >> ~/.bashrc
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
            y) add_to_bashrc; break;;
            n) break;;
            *) echo "Invalid input (y/n):";;
        esac
    done

    echo "Done configuring bashrc."
}

sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
sudo apt install curl
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -

echo "Updating package lists ..."
sudo apt update

echo "Installing ROS $ROS_DISTRO ..."
yes | sudo apt install python-rosinstall python-catkin-pkg python-rosdep \python-wstool \
ros-$ROS_DISTRO-catkin ros-$ROS_DISTRO-desktop ros-$ROS_DISTRO-pcl-ros \
ros-$ROS_DISTRO-image-transport ros-$ROS_DISTRO-image-transport-plugins \
ros-$ROS_DISTRO-libg2o ros-$ROS_DISTRO-geographic-msgs \
ros-$ROS_DISTRO-tf2-geometry-msgs > /dev/null

# ROS environment setup
echo "Setting up ROS environment..."
source /opt/ros/$ROS_DISTRO/setup.bash

echo "Would you like to configure your bashrc to automatically source setup files and set ROS_PACKAGE_PATH? (y/n)"
echo "(If you have already added it manually or in previous install, enter n)"

while read ans; do
    case "$ans" in
        y) config_bashrc; update_rosdep; break;;
        n) update_rosdep; break;;
        *) echo "Invalid input (y/n):";;
    esac
done

