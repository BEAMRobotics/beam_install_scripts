#!/bin/bash
set -e

## Install scripts directory
#INSTALL_SCRIPTS=$"$HOME/software/beam_install_scripts"

## get UBUNTU_CODENAME, ROS_DISTRO, CATKIN_DIR
#source $INSTALL_SCRIPTS/identify_environment.bash

## set up symlink
#: ${SYMLINKS_REPO_DIR:=$REPO_DIR}

## link repo being installed to catkin_ws
link_routine()
{
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
