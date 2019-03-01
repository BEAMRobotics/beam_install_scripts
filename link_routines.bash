#!/bin/bash
set -e

# This script contains functions to add/remove a symlink repo from catkin_ws/src

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
