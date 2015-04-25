#!/usr/local/bin/python
"""
    multi-threaded program to apply homographies 
    calculated with Visual SFM on windows to 
    gantry acquired lightfield images
    
    step 1. produces warped images, aligned
    step 2. generate thumbnails
    step 3. create contact sheet at max GL texture size

    http://wiki.roberttwomey.com/Lightfield

    Robert Twomey 2015
    rtwomey@uw.edu

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

        
def readImageFilenames(dir_name):
    # read in image filenames
    dir_list = []
    for extension in (".png", ".jpg", ".jpeg"):
        try:
            temp = os.listdir(dir_name)
            temp = filter(lambda x: x.find(extension) > -1, temp)
            temp = sorted(temp)
            if len(temp) > 0:
                dir_list = temp
        except:
            print >> sys.stderr, ("Unable to open directory: %s" % dir_name)
            sys.exit(-1)

    dir_list = map(lambda x: os.path.join(dir_name,x), dir_list)

    #print len(dir_list), "files in directory"
    #print dir_list
    
    return dir_list
    
    
def readCamerasV2File(camerasfile):
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
        principalpoint = (np.array(results[3].split(' '))).astype(np.int)   

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
    
    # xcents.append(avgxcenter)
    # ycents.append(avgycenter)
    # scatter(xcents, ycents)
    # show()

    xcents = np.array(xcents)
    ycents = np.array(ycents)
    
    print "========"
    print "average camera rotation:", avg_R
    print "range", (xcents.max()-xcents.min()), (ycents.max() - ycents.min())
    print "avg center:", avgxcenter, avgycenter, avgzcenter
    print "========"
    
    return camdict, np.array(avg_R).reshape((3,1)), (avgxcenter, avgycenter)

    
def mp_warp(srcs, params, R_avg, C_avg, nprocs):
    
    def worker(srcs, params, R_avg, C_avg, out_q):
        """ The worker function, invoked in a process. 'srcs' is a
            list of input files, 'params' is a dict of calculated 
            camera parameters by filename. R_avg and C_avg are the
            compute average camera rotation and position to be 
            rectified to.
            Results are placed in a dictionary that's pushed to a queue.
        """
        outdict = {}

        for src in srcs:
            src_fname = os.path.basename(src)
            outdict[src] = warpAvg(src, params[src_fname], R_avg, C_avg)
            print ".",
            sys.stdout.flush()
            
        out_q.put(outdict)
        
    # Each process will get 'chunksize' nums and a queue to put his out
    # dict into
    out_q = Queue()
    chunksize = int(math.ceil(len(srcs) / float(nprocs)))
    procs = []
    
    for i in range(nprocs):
        p = multiprocessing.Process(
                target=worker,
                args=(srcs[chunksize * i:chunksize * (i + 1)],
                      params, R_avg, C_avg, out_q))
        procs.append(p)
        p.start()
    
    # Collect all results into a single result dict. We know how many dicts
    # with results to expect.
    resultdict = {}
    for i in range(nprocs):
        resultdict.update(out_q.get())

    # Wait for all worker processes to finish
    for p in procs:
        p.join()

    print
    return resultdict
            
            
def warpAvg(src, params, R_avg, C_avg):
    global warpedpath, undistortpath, thumbpath, acq_grid, max_texture_size
    
    # params for src image
    f1, T1, C1, R_mat1, R_quat1, normRadialDistortion1, undistort_fname = params

    # image files
    undistort = os.path.join(undistortpath, undistort_fname)
    src_img_rgb = cv2.imread(undistort)

    w = src_img_rgb.shape[1]
    h = src_img_rgb.shape[0]

    # magic number
    w_offset = (C1[0] - C_avg[0]) * 200#w/2
    h_offset = (C1[2] - C_avg[1]) * 200# w/2

       # http://math.stackexchange.com/questions/87338/change-in-rotation-matrix

    #print "R_mat1:", R_mat1
    # print "R_mat1T:", R_mat1.T

    # print "R_mat2:", R_mat2

    # R_mat1 = R_mat1 / R_mat1[2,2]
    # R_mat2 = R_mat2 / R_mat2[2,2]
    #
    R_rod1, jacobian = cv2.Rodrigues(R_mat1)
    #print "R_rod1:", R_rod1

    #print "R_avg:", R_avg
    
    # R_rod2, jacobian = cv2.Rodrigues(R_mat2)
    # print "R_rod2:", R_rod2

    R_rod_12 = R_rod1 - R_avg #R_avg - R_rod1 #
    #print "R_rod_12:", R_rod_12 * (180 / pi)
    # print R_rod_12

    # switch order of 2nd and 3rd rotation
    R_rod_12 = np.array([R_rod_12[0], R_rod_12[1], -1*R_rod_12[2]])
    
    #lprint R_rod_12
    
    R_12, jacobian = cv2.Rodrigues(R_rod_12)
    #print "R_12:", R_12

    # # R_12 = R_12/R_12[2,2]
    # R_12_inv = linalg.inv(R_12)
    #
    # # H = np.identity(3) * T1.reshape((3,1))
    # H = R_mat1#R_12
    #
    # Tdiff = T2 - T1
    # print "Tdiff:", Tdiff

    # Cdiff = C1 - C2
    # print "Cdiff:", Cdiff

    # #Tdiff = Tdiff / Tdiff[2]
    # # print "Tdiff norm:", Tdiff
    #
    # M = np.identity(3)
    #
    # M[0,0] = f2
    # M[1,1] = f2
    #

    # H = np.identity(3)

    # H[0,2] =  Tdiff[0]
    # H[1,2] =  Tdiff[1]
    # H[2,2] =  Tdiff[2]

    # sf = 0.1
    # H[0,2] =  Cdiff[0] * w * sf
    # H[1,2] =  -1 * Cdiff[2] * h * sf
    # H[2,2] =  1

    # print "M:",M, "H:",H
    # H = M * H
    # print "M * H", M * H

    #
    # H[0,2] =  50
    # H[1,2] =  50
    # H[2,2] =  1

    # http://stackoverflow.com/questions/12288473/perspective-warping-in-opencv-based-on-know-camera-orientation

    R = R_12 #R_mat1.T

    #Create trans mat and combine with translation matrix
    T = np.array([[1], [0], [-w/2+w_offset],
                       [0], [1], [-h/2+h_offset],
                       [0], [0], [1]]).reshape((3,3))
    # T[2,2] = 2
    # T = T / T[2,2]

    #print "T:", T

    R[0,2] = 0
    R[1,2] = 0
    R[2,2] = 1

    trans = np.dot(R, T)
    trans[2,2] += w

    # adjustment to focal length
    fscale = 0.8
    K = np.array([[f1*fscale], [0], [w/2],
                  [0], [f1*fscale], [h/2],
                  [0], [0], [1]]).reshape(3,3)
                
    #print "K:", K

    H = np.dot(K, trans)

    # pad and recenter
    oversize = 0.05
    
    move_h = np.matrix(np.identity(3), np.float32)

    img_w = int(src_img_rgb.shape[1] * (1.0 + oversize * 2.0))
    img_h = int(src_img_rgb.shape[0] * (1.0 + oversize * 2.0))
 
    move_h[0,2] = src_img_rgb.shape[1] * (oversize * 2.0) / 2
    move_h[1,2] = src_img_rgb.shape[0] * (oversize * 2.0) / 2

    H = np.dot(move_h, H)

    H = H / H[2,2]
    #print "H", H

    src_img_warp = cv2.warpPerspective(src_img_rgb, H, (img_w, img_h))#w, h))

    fname, ext = os.path.splitext(os.path.basename(src))
    warp_file = os.path.join(warpedpath, fname+"_warp"+ext)
    cv2.imwrite(warp_file, src_img_warp)
    
    # generate thumbnail
    acq_w, acq_h = acq_grid
    thumb_w = max_texture_size / acq_w
    thumb_h = thumb_w * img_h / img_w
    
    thumb_img = cv2.resize(src_img_warp, (thumb_w, thumb_h))
    thumb_file = os.path.join(thumbpath, fname+ext)
    cv2.imwrite(thumb_file, thumb_img)

    # return (warp_file, thumb_file)
               
                         
if __name__ == '__main__':
    global featurepath, warpedpath, undistortpath, thumbpath, max_texture_size, acq_grid

    # Define command line argument interface
    parser = argparse.ArgumentParser(description='apply Visual SFM quaternions to a folder of lightfield images')
    parser.add_argument('inpath', help='path to input images')
    parser.add_argument('undistortpath', help='path to undistorted images')
    parser.add_argument('camerasv2', help='cameras_v2.txt file from VSFM')
    parser.add_argument('warpedpath', help='output path to save the warped image files')
    parser.add_argument('thumbpath', help='output path the save the thumbnail image files')
    parser.add_argument('camerapos', help='output file for list of camera positions')
    parser.add_argument('contactimg', help='output file for contact sheet image')
    
    args = parser.parse_args()

    imagedir = args.inpath  # directory of input images
    undistortpath = args.undistortpath # directory of undistorted images
    camerasfile = args.camerasv2  # results of N-view match from Visual SFM in windows
    warpedpath = args.warpedpath    # out path to save the results
    thumbpath = args.thumbpath
    camerapos = args.camerapos
    contactimg_file = args.contactimg
    
    # create output path if necessary
    if not os.path.exists(warpedpath):
        os.makedirs(warpedpath)
    
    # read image filenames
    image_files = readImageFilenames(imagedir)
    
    # read Cameras V2 file (results from VSFM)    
    camresults, R_avg, C_avg = readCamerasV2File(camerasfile)
    
    # rectify image to average camera center and orientation from VSFM
    # for src in image_files:
    #     print "source:", src
    #     src_fname = os.path.basename(src)
    #     warpAvg(src, camresults[src_fname], R_avg, C_avg)

    max_texture_size = 16384
    grid_w = 29
    grid_h = 20
    acq_grid = (grid_w, grid_h)

    results = mp_warp(image_files, camresults, R_avg, C_avg, 8)
    
    
    # generate tiled image
    
    thumb_file = os.path.join(thumbpath, "test_{0:04d}.jpg".format(0))
    thumb_img = cv2.imread(thumb_file)
    thumb_h, thumb_w, thumb_chan = thumb_img.shape
    
    max_texture_w = max_texture_size
    max_texture_h = thumb_h * grid_h
    
    contact_img = np.zeros((max_texture_h, max_texture_w, 3), np.uint8)
    
    # print contact_img.shape
    
    for j in range(grid_h):
        for i in range(grid_w):
            num = i + (j * grid_w)
            thumb_file = os.path.join(thumbpath, "test_{0:04d}.jpg".format(num))
            # print thumb_file
            if os.path.exists(thumb_file):
                thumb_img = cv2.imread(thumb_file)
                thumb_h, thumb_w, thumb_chan = thumb_img.shape
                x = i * thumb_w
                y = j * thumb_h
                # print x,y, thumb_w ,thumb_h
                contact_img[y:(y+thumb_h), x:(x+thumb_w)] = thumb_img
            
    print "writing contact image", contact_img.shape
    cv2.imwrite(contactimg_file, contact_img)
    

    # save camera positions
    count = 0
    out_f = file(camerapos, 'w')
    for src in image_files:
        src_fname = os.path.basename(src)
        C_src = camresults[src_fname][2]
        out_f.write('{0} {1} {2}\n'.format(count, (C_avg[0]-C_src[0]), (C_avg[1]-C_src[2])))
        count = count + 1
