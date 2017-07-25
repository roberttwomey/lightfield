#!/bin/bash

#datasets=( "classroom_s3" "davb" "tivon3" )
#lfdatapath="/home/rtwomey/code/lightfield/data/shoots"

datasets=( "20170725110712" "20170725112717")
lfdatapath="/home/rtwomey/lightfield/data/houseshoots"

export PATH=/usr/local/cuda-8.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64:$LD_LIBRARY_PATH

for ds in "${datasets[@]}"
do
	echo "==== processing $ds ====="
	# mkdir $lfdatapath/$ds/results
	python undistort.py picam_calib.xml $lfdatapath/$ds/undistorted $lfdatapath/$ds/rotated/*.jpg
	~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+sort+pairs+k=2514.80291008,1293.28999298,2519.66791867,928.507686634 $lfdatapath/$ds/undistorted/ $lfdatapath/$ds/results/results.nvm @10	
	# ~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+sort+k=2514.80291008,1293.28999298,2519.66791867,928.507686634 $lfdatapath/$ds/original/ $lfdatapath/$ds/results/results.nvm	
	# ~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+sort+k=2514.80291008,1293.28999298,2519.66791867,928.507686634 $lfdatapath/$ds/rotated/ $lfdatapath/$ds/results/results.nvm @5	
	# ~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+pairs+sort+k=2514.80291008,1293.28999298,2519.66791867,928.507686634 $lfdatapath/$ds/rotated/ $lfdatapath/$ds/results/results.nvm @5	
	# ~/code/vsfm/vsfm/bin/VisualSFM sfm+pmvs+shared+pairs+sort $lfdatapath/$ds/rotated/ $lfdatapath/$ds/results/results.nvm @5	

done



