#!/usr/bin/python
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
    for extension in (".png", ".jpg", ".jpeg", '.JPG'):
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
    
    xcents.append(avgxcenter)
    ycents.append(avgycenter)
    scatter(xcents, ycents)
    savefig(os.path.join(datapath, 'cameras.png'))
    # show()

    xcents = np.array(xcents)
    ycents = np.array(ycents)
    
    print "========"
    print "average camera rotation:", avg_R
    print "range", (xcents.max()-xcents.min()), (ycents.max() - ycents.min())
    print "avg center:", avgxcenter, avgycenter, avgzcenter
    print "========"
    
    return camdict, np.array(avg_R).reshape((3,1)), (avgxcenter, avgycenter)

def write_blank(src):
    global warpedpath, undistortpath, thumbpath, acq_grid, max_texture_size, num_textures
    
    src_img_rgb = cv2.imread(src)
    
    img_w = src_img_rgb.shape[1]
    img_h = src_img_rgb.shape[0]
    
    src_img_warp = np.zeros((img_h, img_w, 3))
    fname, ext = os.path.splitext(os.path.basename(src))
    warp_file = os.path.join(warpedpath, fname+"_warp"+ext.lower())
    cv2.imwrite(warp_file, src_img_warp)
    
    # generate thumbnail
    acq_w, acq_h = acq_grid
    thumb_w = max_texture_size / acq_w * num_textures
    thumb_h = thumb_w * img_h / img_w
    
    thumb_img = np.zeros((thumb_h, thumb_w, 3))
    thumb_file = os.path.join(thumbpath, fname+ext.lower())
    cv2.imwrite(thumb_file, thumb_img)
    
    
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
            if src_fname in params.keys():
                outdict[src] = warpAvg(src, params[src_fname], R_avg, C_avg)
            else:
                write_blank(src)
            sys.stdout.write(".")
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
    global warpedpath, undistortpath, thumbpath, acq_grid, max_texture_size, num_textures
    
    # params for src image
    f1, T1, C1, R_mat1, R_quat1, normRadialDistortion1, undistort_fname = params

    # image files
    
    # undistort = os.path.join(undistortpath, undistort_fname)
    # src_img_rgb = cv2.imread(undistort)

    # name, ext = os.path.splitext(os.path.basename(src))
    # eq_img = os.path.join(undistortpath, name + "_eq.jpg")
    #print eq_img
    # src_img_rgb = cv2.imread(eq_img)

    src_img_rgb = cv2.imread(src)
    
    w = src_img_rgb.shape[1]
    h = src_img_rgb.shape[0]

    w_translate = 0#(C1[0] - C_avg[0]) #* f1 #* 200#w/2
    h_translate = 0#(C1[2] - C_avg[1]) #* f1 #* 200# w/2

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

    R_rod_12 = R_rod1 - R_avg
    # R_rod_12 = R_avg - R_rod1
    
    #print "R_rod_12:", R_rod_12 * (180 / pi)
    # print R_rod_12

    # switch order of 2nd and 3rd rotation
    R_rod_12 = np.array([R_rod_12[0], R_rod_12[1], -1 * R_rod_12[2]])
    
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
    T = np.array([[1], [0], [(-w/2)+w_translate],
                       [0], [1], [(-h/2)+h_translate],
                       [0], [0], [1]]).reshape((3,3))
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
    oversize = 0#0.05
    
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
    warp_file = os.path.join(warpedpath, fname+"_warp"+ext.lower())
    cv2.imwrite(warp_file, src_img_warp)
    
    # generate thumbnail
    acq_w, acq_h = acq_grid
    thumb_w = max_texture_size / acq_w * num_textures
    thumb_h = thumb_w * img_h / img_w
    
    thumb_img = cv2.resize(src_img_warp, (thumb_w, thumb_h))
    thumb_file = os.path.join(thumbpath, fname+ext.lower())
    cv2.imwrite(thumb_file, thumb_img)

    # return (warp_file, thumb_file)
               

def generate_contact_sheet(reorder = None):
    global thumbpath, max_texture_size, grid_h, grid_w, num_textures, contactimg_file
    
    # generate tiled image
    thumbstr = "image{0:04d}.jpg"
    thumb_file = os.path.join(thumbpath, thumbstr.format(1))
    thumb_img = cv2.imread(thumb_file)
    thumb_h, thumb_w, thumb_chan = thumb_img.shape

    max_texture_w = max_texture_size
    max_texture_h = thumb_h * grid_h

    print "generating contact sheet...",

    part_w = grid_w/num_textures

    for n in range(num_textures):
        
        contact_img = np.zeros((max_texture_h, max_texture_w, 3), np.uint8)
        print contact_img.shape
        
        for j in range(grid_h):
          for i in range(part_w):
              num = (n * part_w) + i + (j * grid_w)
              if reorder != None:
                  #print num
                  num = reorder[num]
              thumb_file = os.path.join(thumbpath, thumbstr.format(num))
              # print thumb_file,
              if os.path.exists(thumb_file):
                  thumb_img = cv2.imread(thumb_file)
                  thumb_h, thumb_w, thumb_chan = thumb_img.shape
                  x = i * thumb_w
                  y = j * thumb_h
                  # print x,y, thumb_w ,thumb_h
                  # print contact_img.shape
                  contact_img[y:(y+thumb_h), x:(x+thumb_w)] = thumb_img

        print "writing contact image", contact_img.shape, "to",
        fname, ext = os.path.splitext(contactimg_file)
        contactimg_file = fname+str(n)+ext
        print contactimg_file
        cv2.imwrite(contactimg_file, contact_img)
          
                   
def write_camera_positions(camerapos, image_files, camresults, reorder = None):
    # save camera positions
    count = 0
    positions = []
    for src in image_files:
        src_fname = os.path.basename(src)
        if src_fname in camresults.keys():
            C_src = camresults[src_fname][2]
            xpos = C_avg[0]-C_src[0]
            ypos = C_avg[1]-C_src[2]
            positions.append((xpos, ypos))
            count = count + 1

    out_f = file(camerapos, 'w')
    out_f.write("<cameras>\n")
    for i in range(count):
        num = i
        if reorder != None:
            num = reorder[i]
        xpos, ypos = positions[num]
        out_f.write("\t<cam>\n\t\t<x>{0}</x>\n\t\t<y>{1}</y>\n\t</cam>>\n".format(xpos, ypos))
    out_f.write("</cameras>")

if __name__ == '__main__':
    global datapath, featurepath, warpedpath, undistortpath, thumbpath, max_texture_size, acq_grid, num_textures, contactimg_file

    # Define command line argument interface
    parser = argparse.ArgumentParser(description='apply Visual SFM quaternions to a folder of lightfield images')
    parser.add_argument('datapath', help='path to lightfield data')
    parser.add_argument('grid', help='acquisition grid as WxH')
    parser.add_argument('reorder', help='order of acquisition (normal, wrap)')
    parser.add_argument('camerapos', help='output file for list of camera positions')
    parser.add_argument('contactimg', help='output file for contact sheet image')
    
    args = parser.parse_args()

    datapath = args.datapath

    # directory of input images
    imagedir = os.path.join(args.datapath, 'original')  

    gridstr = args.grid     # grid layout
    order = args.reorder    # arugment order

    # directory of undistorted images
    undistortpath = os.path.join(args.datapath, 'undistorted') 

    # results of N-view match from Visual SFM in windows
    camerasfile = os.path.join(args.datapath, "results/results.cmvs/00/cameras_v2.txt") 
    
    # output paths to save the results
    warpedpath = os.path.join(args.datapath, 'warped')    
    thumbpath = os.path.join(args.datapath, 'thumbs')
    camerapos = os.path.join(args.datapath, args.camerapos)
    contactimg_file = os.path.join(args.datapath, args.contactimg)

    # create folders as necessary
    if not os.path.exists(warpedpath):
        os.makedirs(warpedpath)

    if not os.path.exists(thumbpath):
        os.makedirs(thumbpath)
    
    # grid
    grid_w, grid_h = gridstr.split("x")
    grid_w = int(grid_w)
    grid_h = int(grid_h)
    
    print "grid dimensions", grid_w, "x", grid_h
    
    max_texture_size = 16384
    num_textures = 1
    acq_grid = (grid_w, grid_h)

    # read image filenames
    image_files = readImageFilenames(imagedir)

    # read Cameras V2 file (results from VSFM)    
    camresults, R_avg, C_avg = readCamerasV2File(camerasfile)
    
    # rectify images
    results = mp_warp(image_files, camresults, R_avg, C_avg, 8)
    
    if order=='wrap':
        print "wrapping"

        # reorder
        reorder = []
        for i in range(grid_h):
            if i%2==0:
                reorder += range(i*grid_w, (i+1)*grid_w)
            else:
                reorder += range((i+1)*grid_w-1,i*grid_w-1, -1)

        #print reorder
    
        # make contact sheet
        generate_contact_sheet(reorder)

        # export camera center coordinates    
        write_camera_positions(camerapos, image_files, camresults, reorder)

    else:
        
        # make contact sheet
        generate_contact_sheet()#reorder)

        # export camera center coordinates    
        write_camera_positions(camerapos, image_files, camresults)#, reorder)
        
