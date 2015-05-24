#!/bin/bash

# datasets=( "night2" "carkeek_night")
#
# lfdatapath="/media/rtwomey/Data/lightfield/data/shoots"
#
# export PATH=/usr/local/cuda-7.0/bin:$PATH
# export LD_LIBRARY_PATH=/usr/local/cuda-7.0/lib64:$LD_LIBRARY_PATH

# for ds in "${datasets[@]}"
# do
	# echo "==== processing $ds ====="
# done

# ==== latop versions 
# python mp_vsfm_rectify.py --reorder wrap --laptop 20x30 ~/code/lightfield/data/shoots/yellowcliff/undistorted/*.jpg
# python mp_vsfm_rectify.py --laptop 20x15 ~/code/lightfield/data/shoots/dark_trees/eq_undistorted/*.jpg
python mp_vsfm_rectify.py --reorder verticalwrap --laptop 24x24 ~/code/lightfield/data/shoots/outsidelookingin/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder wrap --laptop --inverty 30x20 ~/code/lightfield/data/shoots/bookcase/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder wrap --laptop 20x30 ~/code/lightfield/data/shoots/diningroom3/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder wrap --laptop 30x20 ~/code/lightfield/data/shoots/cliffside/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder wrap --inverty --laptop 20x30 ~/code/lightfield/data/shoots/mike1/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder wrap --laptop 20x30 ~/code/lightfield/data/shoots/mike3/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder verticalwrap --laptop 20x30 ~/code/lightfield/data/shoots/carkeek_night/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder wrap --laptop 20x30 ~/code/lightfield/data/shoots/carkeek/undistorted/*.jpg
python mp_vsfm_rectify.py --reorder wrap --laptop 20x30 ~/code/lightfield/data/shoots/tunnel/undistorted/*.jpg
python mp_vsfm_rectify.py --laptop 20x10 ~/code/lightfield/data/shoots/ballard_wall/undistorted/*.jpg
python mp_vsfm_rectify.py --laptop 16x14 ~/code/lightfield/data/shoots/precise/undistorted/*.jpg



# ==== max res single texture versions
# python mp_vsfm_rectify.py --nowarp --reorder verticalwrap --single 24x24 ~/code/lightfield/data/shoots/outsidelookingin/undistorted/*.jpg
# python mp_vsfm_rectify.py --reorder wrap --nowarp --single --inverty 30x20 ~/code/lightfield/data/shoots/bookcase/undistorted/*.jpg
# python mp_vsfm_rectify.py --reorder wrap --nowarp --single 20x30 ~/code/lightfield/data/shoots/diningroom3/undistorted/*.jpg
# python mp_vsfm_rectify.py --reorder wrap --nowarp --single 30x20 ~/code/lightfield/data/shoots/cliffside/undistorted/*.jpg
# python mp_vsfm_rectify.py --reorder wrap --nowarp --inverty --single 20x30 ~/code/lightfield/data/shoots/mike1/undistorted/*.jpg
# python mp_vsfm_rectify.py --reorder wrap --nowarp --single 20x30 ~/code/lightfield/data/shoots/mike3/undistorted/*.jpg
# python mp_vsfm_rectify.py --nowarp --reorder verticalwrap --single 20x30 ~/code/lightfield/data/shoots/carkeek_night/undistorted/*.jpg
# python mp_vsfm_rectify.py --reorder wrap --single 20x30 ~/code/lightfield/data/shoots/carkeek/undistorted/*.jpg
# python mp_vsfm_rectify.py  --nowarp --single 20x15 ~/code/lightfield/data/shoots/dark_trees/eq_undistorted/*.jpg
# python mp_vsfm_rectify.py --reorder wrap --single 20x30 ~/code/lightfield/data/shoots/tunnel/undistorted/*.jpg

# python mp_vsfm_rectify.py --single 20x10 ~/code/lightfield/data/shoots/ballard_wall/undistorted/*.jpg
# python mp_vsfm_rectify.py --single 16x14 ~/code/lightfield/data/shoots/precise/undistorted/*.jpg


#missing coordinates
# python mp_vsfm_rectify.py --reorder wrap --single 20x15 ~/code/lightfield/data/shoots/towers/undistorted/*.jpg # need to start at image 1

# vsfm results seem to be missing
#python mp_vsfm_rectify.py --reorder wrap --single 15x20 ~/code/lightfield/data/shoots/tivon1/undistorted/*.jpg

# multiple independent models (12)
# python mp_vsfm_rectify.py --reorder wrap --single 15x20 ~/code/lightfield/data/shoots/tivon2/undistorted/*.jpg

# order? size?
# python mp_vsfm_rectify.py --reorder wrap --single 20x30 ~/code/lightfield/data/shoots/mike2/undistorted/*.jpg

