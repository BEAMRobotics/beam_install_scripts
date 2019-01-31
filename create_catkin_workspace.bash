#!/bin/bash
set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# get UBUNTU_CODENAME, ROS_DISTRO, REPO_DIR, CATKIN_DIR
source $SCRIPT_DIR/identify_environment.bash

main()
{
    bash $SCRIPT_DIR/catkin_tools_install.bash
    create_catkin_ws
}

create_catkin_ws()
{
    # Check if workspace exists
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

main
