#!/bin/bash

datasets=( "tivon1" )

lfdatapath="/media/rtwomey/ATTIC/lightfield/data/shoots"

export PATH=/usr/local/cuda-7.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-7.0/lib64:$LD_LIBRARY_PATH

for ds in "${datasets[@]}"
do
	echo "==== processing $ds ====="
	#python apply_undistort.py picam_calib.xml $lfdatapath/$ds/undistorted $lfdatapath/$ds/original/*.jpg
	#mkdir $lfdatapath/$ds/results
	~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+sort+k=2514.80291008,1293.28999298,2519.66791867,928.507686634 $lfdatapath/$ds/undistorted/ $lfdatapath/$ds/results/results.nvm	
done


