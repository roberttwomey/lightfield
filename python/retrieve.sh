#!/bin/bash

storagepath="/home/rtwomey/attic/"
workingpath="/home/rtwomey/code/lightfield/data/shoots"
source="$storagepath/shoots/$1/undistorted/*.jpg"
dest="$workingpath/$1/undistorted"

mkdir -p $dest

#doesn't work
# rsync -auzvh --include './' --include='.jpg' --exclude='*' "$sourcedir" "$workingdir"

cp -v $source $dest

dest="$workingpath/$1/results/results.nvm.cmvs/00/"
mkdir -p $dest

source="$storagepath/shoots/$1/results/results.nvm.cmvs/00/cameras_v2.txt"
cp -v $source $dest

