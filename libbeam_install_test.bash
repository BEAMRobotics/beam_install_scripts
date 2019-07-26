#!/bin/bash
set -e

cd $HOME

git clone git@github.com:BEAMRobotics/libbeam.git
cd libbeam
git checkout testing_travis
bash ./scripts/install.bash
