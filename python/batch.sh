#!/bin/bash
#python apply_undistort.py picam_calib.xml ../data/yellowcliff/undistorted ../data/yellowcliff/original/*.jpg
#python apply_undistort.py picam_calib.xml ../data/dome/undistorted ../data/dome/original/*.jpg

export PATH=/usr/local/cuda-7.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-7.0/lib64:$LD_LIBRARY_PATH

mkdir ~/code/lightfield/data/yellowcliff/results/
mkdir ~/code/lightfield/data/dome/results


~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+sort+k=2514.80291008,1293.28999298,2519.66791867,928.507686634 ~/code/lightfield/data/yellowcliff/undistorted/ ~/code/lightfield/data/yellowcliff/results/results.nvm

~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+sort+k=2514.80291008,1293.28999298,2519.66791867,928.507686634 ~/code/lightfield/data/dome/undistorted/ ~/code/lightfield/data/dome/results/results.nvm
