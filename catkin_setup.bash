#!/bin/bash
set -e

# This script contains functions to add/remove a symlink repo from catkin_ws/src

create_catkin_ws()
{
    # Check if workspace exists
    install_catkin_tools
    if [ -e "$CATKIN_DIR/.catkin_workspace" ] || [ -d "$CATKIN_DIR/.catkin_tools" ]; then
        echo "Catkin workspace detected at $CATKIN_DIR"
    else
        echo "Creating catkin workspace in $CATKIN_DIR ..."
        source /opt/ros/$ROS_DISTRO/setup.bash
        mkdir -p "$CATKIN_DIR/src"
        cd "$CATKIN_DIR"
        catkin init > /dev/null
        echo "Catkin workspace created successfully."
    fi
}

install_catkin_tools()
{
    # Check if already installed
    if type catkin > /dev/null 2>&1; then
        echo "Catkin tools is already installed"
    else
        echo "Installing catkin tools ..."
        sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list'
        wget -qO - http://packages.ros.org/ros.key | sudo apt-key add -
        sudo apt-get -qq update
        sudo apt-get -qq install python-catkin-tools > /dev/null
        echo "Catkin tools installed successfully."
    fi
}

link_routine()
{
    # link repo being installed to catkin_ws
    ln -sfn "$SYMLINKS_REPO_DIR" "$CATKIN_DIR/src"
    echo "Symlink to $SYMLINKS_REPO_DIR created successfully"
}

unlink_routine()
{
    # Need to remove just the symlink for the linked repo
    REPO_BASE_NAME=$(basename "$SYMLINKS_REPO_DIR")
    rm -f "$CATKIN_DIR/src/$REPO_BASE_NAME"
    echo "Symlink $CATKIN_DIR/src/$REPO_BASE_NAME removed successfully"
}

catkin_clean()
{
    rm -rf "$CATKIN_DIR/devel"
    rm -rf "$CATKIN_DIR/build"
    rm -rf "$CATKIN_DIR/install"
    rm -rf "$CATKIN_DIR/logs"
    rm -f "$CATKIN_DIR/.catkin_workspace"
    echo "Catkin workspace cleaned"
}

compile()
{
    cd "$CATKIN_DIR"
    source /opt/ros/$ROS_DISTRO/setup.bash
    if [ -z "$CONTINUOUS_INTEGRATION" ]; then
        catkin build
    else
        if [ -n "$CIRCLECI" ]; then
            # Build libwave by itself first, since the job is so large
            catkin build --no-status -j2 libwave
            catkin build --no-status --mem-limit 6G
        else
            catkin build --no-status
        fi
    fi
}


