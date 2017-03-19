#!/usr/local/bin/python
"""
    
    short helper script to generate plot of camera positions from vsfm results
    
    http://wiki.roberttwomey.com/Lightfield

    Robert Twomey 2017
    rtwomey@ysu.edu

"""

import os
import sys
import cv2
import math
import numpy as np
from numpy import linalg
from multiprocessing import Queue
import multiprocessing
import argparse
import pickle
from pylab import * 
import re
        
def readCamerasV2File(camerasfile, cameraloc_img, do_inverty):
    global datapath
    
    infile = open(camerasfile, 'r')
    
    lines = infile.readlines()
    print "\n"

    numcams = int(lines[16])
    
    camdict = {}
    
    camcenters = []
    xcents = []
    ycents = []

    sumx = 0
    sumy = 0
    sumz = 0
    
    R_accum = 0.
    
    for n in range(0,numcams):
        results = lines[18+n*14:31+n*14]

        newf = results[0].strip('\r\n')
        filename = results[1].strip('\r\n').split("/")[-1]
        # print filename

        # Focal Length (of the undistorted image)
        focallength = (np.array(results[2].split(' ')))[0].astype(np.float)    

        # 2-vec Principal Point (image center)
        principalpoint = (np.array(results[3].split(' '))).astype(np.float)   

        # 3-vec Translation T (as in P = K[R T])
        T = (np.array(results[4].split(' '))).astype(np.float)
        
        # 3-vec Camera Position C (as in P = K[R -RC])
        C = (np.array(results[5].split(' '))).astype(np.float)  

        # 3-vec Axis Angle format of R
        R_axisangle = (np.array(results[6].split(' '))).astype(np.float)  

        R_accum += R_axisangle
        
        # 4-vec Quaternion format of R
        R_quat = (np.array(results[7].split(' '))).astype(np.float)  

        # 3x3 Matrix format of R
        R_mat = (np.array(" ".join(results[8:11]).split(' '))).astype(np.float)  
        R_mat = R_mat.reshape((3,3))
        
        # [Normalized radial distortion] = [radial distortion] * [focal length]^2
        normRadialDistortion = (np.array(results[11])).astype(np.float) 

        # # debug
        # print focallength, principalpoint
        # print T, C
        # print "R_axisangle: ",R_axisangle
        # print "R_quat:", R_quat
        # print "R_mat:", R_mat
        # print normRadialDistortion
        # print filename
        
        # print n, C[0]*10, C[2]*10
        # return results
        camdict[filename] = (focallength, T, C, R_mat, R_quat, normRadialDistortion, newf)
        
        if do_inverty:
            C[2] = -1 * C[2]

        xcents.append(C[0])
        ycents.append(C[2])
        
        sumx += C[0]
        sumy += C[2]
        sumz += C[1]
    
    # calculate averages over stack of images
    avgxcenter = sumx/numcams
    avgycenter = sumy/numcams
    avgzcenter = sumz/numcams

    avg_R = R_accum / numcams
    
    # plot to screen
    
    xcents.append(avgxcenter)
    ycents.append(avgycenter)
    plt.figure(figsize=(8, 6))
    plt.ylim(-1.70, 0.5)
    plt.scatter(xcents, ycents)
    savefig(cameraloc_img, dpi=300)
    # savefig(cameraloc_img, format='eps', dpi=900)

    # show()

    xcents = np.array(xcents)
    ycents = np.array(ycents)
    
    print "Read {0} cameras".format(numcams)
    print "========"
    print "average camera rotation:", avg_R
    print "range", (xcents.max()-xcents.min()), (ycents.max() - ycents.min())
    print "avg center:", avgxcenter, avgycenter, avgzcenter
    print "========"
    
    return camdict, np.array(avg_R).reshape((3,1)), (avgxcenter, avgycenter)

    
    
if __name__ == '__main__':
    global datapath, featurepath, warpedpath, undistortpath, thumbpath, max_texture_size, acq_grid, num_textures, contactimg_file, grid_w, grid_h, x_tiles, y_tiles, x_imgs_per_tile, y_imgs_per_tile

    # Define command line argument interface
    parser = argparse.ArgumentParser(description='apply Visual SFM quaternions to a folder of lightfield images', formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    # parser.add_argument('datapath', help='path to lightfield data')
    parser.add_argument('grid', help='acquisition grid as WxH')
    parser.add_argument('--reorder', default=None, help='reorder images to match order of acquisition (wrap, colsfirst)')
    parser.add_argument('--skip', default=[], help='indices of images to skip')
    parser.add_argument('--inverty', dest='doinverty', action='store_true', help='invert y coordinates (useful for some mirror shots)?')
    parser.add_argument('--nowarp', dest='dowarp', action='store_false', help='skip warp/thumb generation?')
    parser.add_argument('--fullres', dest='dofullres', action='store_true', help='generate full res textures?')
    parser.add_argument('--single', dest='dosingle', action='store_true', help='generate a single texture at opengl max tex resolution')
    parser.add_argument('--laptop', dest='dolaptop', action='store_true', help='generate a single texture at laptop friendly (sub 512MB texture) size')
    parser.add_argument('--medium', dest='domedium', action='store_true', help='generate a medium size tiled texture (2x2)')
    parser.add_argument('--numtextures', default=1, type=int, help='number of output textures')
    parser.add_argument('--maxtexturesize', default=16384, type=int, help='maximum pixel dimension of output texture')
    parser.add_argument('files', nargs='*', help='glob of input files')
    
    args = parser.parse_args()

    # runtime options
    do_warp = args.dowarp
    do_fullres = args.dofullres
    do_inverty = args.doinverty
    do_laptop = args.dolaptop
    do_single = args.dosingle
    do_medium = args.domedium
    order = args.reorder    # reorder images
    gridstr = args.grid     # grid layout
    # file paths
    # read image filenames
    image_files = args.files
    # root path of scene data
    datapath = os.path.dirname(os.path.dirname(image_files[0]))
    
    print "\n===="
    print "Processing", datapath,"\n"
    print "  options"
    print "do warp?", do_warp
    print "do full res output?", do_fullres
    print "do small, single texture output?", do_single
    print "do laptop compatible (512MB) texture output?", do_laptop
    print "do medium sized textures?", do_medium
    print "invert y coordinates?", do_inverty
    print "reorder images?", order
    
    
    if len(args.skip) > 0:
        skip = [i for i in args.skip.split(',')] #.split(',')        # skip certain images
    else:
        skip = []
    num_textures = args.numtextures
    max_texture_size = args.maxtexturesize

    # results of N-view match from Visual SFM in windows
    camerasfile = os.path.join(datapath, "results/results.nvm.cmvs/00/cameras_v2.txt") 
    
    # name of this scene
    scene_name = os.path.basename(datapath)#datapath.split('/')[-2]
        
    texroot = "/Volumes/Work/Projects/lightfield/data/textures/"
    # texroot = "/home/rtwomey/code/lightfield/data/textures/"
    
    # outputs
    if do_laptop:
        texturepath = os.path.join(texroot, "laptop")
    elif do_single:
        texturepath = os.path.join(texroot, "single")
    elif do_fullres:
        texturepath = os.path.join(texroot, "tiled")
    elif do_medium:
        texturepath = os.path.join(texroot, "medium")        
    else:
        texturepath = texroot
        
    camerapos = os.path.join(texturepath, scene_name+'.xml')
    cameraloc_img = os.path.join(texturepath, scene_name+'_cameras.png')
    
    # read Cameras V2 file (results from VSFM)    
    camresults, R_avg, C_avg = readCamerasV2File(camerasfile, cameraloc_img, do_inverty)        
