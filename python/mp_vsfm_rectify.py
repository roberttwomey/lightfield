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
    
    
def readCamerasV2File(camerasfile, cameraloc_img):
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
    savefig(cameraloc_img)
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
    
    
def mp_warp(srcs, params, R_avg, C_avg, nprocs=8):
    
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
            # src_fname = os.path.basename(src)[:-7]+".jpg"
            # sys.stdout.write(src_fname)
            if src_fname in params.keys():
                outdict[src] = warpAvg(src, params[src_fname], R_avg, C_avg)
                sys.stdout.write(".")
            else:
                write_blank(src)
                sys.stdout.write("*")
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
    fscale = 1.0#0.8
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
    cv2.imwrite(warp_file, src_img_warp, [int(cv2.IMWRITE_JPEG_QUALITY), 100])
    
    # generate thumbnail
    acq_w, acq_h = acq_grid
    
    if acq_w > acq_h:
        thumb_w = max_texture_size / acq_w * num_textures
        thumb_h = thumb_w * img_h / img_w
    else:
        thumb_h = max_texture_size / acq_h * num_textures
        thumb_w = thumb_h * img_w / img_h
    
    # thumb_w = max_texture_size / acq_w * num_textures
    # thumb_h = thumb_w * img_h / img_w

    #print thumb_w, thumb_h
    
    thumb_img = cv2.resize(src_img_warp, (thumb_w, thumb_h))
    thumb_file = os.path.join(thumbpath, fname+ext.lower())
    cv2.imwrite(thumb_file, thumb_img, [int(cv2.IMWRITE_JPEG_QUALITY), 100])

    # return (warp_file, thumb_file)
               

def generate_contact_sheet(files, reorder = None, skip = []):
    global thumbpath, max_texture_size, grid_h, grid_w, num_textures, contactimg_file, thumb_w, thumb_h
    
    # generate tiled image
    # thumbstr = "image{0:04d}_eq.jpg"
    thumbstr = os.path.basename(files[0])
    thumb_file = os.path.join(thumbpath, thumbstr)
    thumb_img = cv2.imread(thumb_file)
    thumb_h, thumb_w, thumb_chan = thumb_img.shape
    print thumb_img.shape
    # print thumbstr
    
    if grid_w > grid_h:
        max_texture_w = max_texture_size
        max_texture_h = thumb_h * grid_h
    else:
        max_texture_h = max_texture_size
        max_texture_w = thumb_w * grid_w
        
    print max_texture_w, max_texture_h
    
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
              if num not in skip:                  
                  thumbstr = "frame_{0:04d}.jpg".format(num)
                  thumb_file = os.path.join(thumbpath, thumbstr)              
                  # print thumb_file
                  if os.path.exists(thumb_file):
                      thumb_img = cv2.imread(thumb_file)
                      thumb_h, thumb_w, thumb_chan = thumb_img.shape
                      x = i * thumb_w
                      y = j * thumb_h
                      # print x,y, thumb_w ,thumb_h
                      # print contact_img.shape
                      contact_img[y:(y+thumb_h), x:(x+thumb_w)] = thumb_img
              else:
                  print "skipping {0} in contact sheet".format(num)

        print "writing contact image", contact_img.shape, "to",
        
        if num_textures > 1:
            fname, ext = os.path.splitext(contactimg_file)
            contactimg_file = fname+str(n)+ext
        print contactimg_file
        cv2.imwrite(contactimg_file, contact_img)


def write_xml_scene(camerapos, contactimg_file, image_files, camresults, reorder = None, skip = []):
    """ write refocuser scene descriptor file for use by oF refocusing app
    """ 
    global thumb_w, thumb_h, grid_w, grid_h
       
    count = 0
    positions = []
    
        
    # for src in image_files:
    #     src_fname = os.path.basename(src)
    for i in range(grid_w * grid_h):
        src_fname = "frame_{0:04d}.jpg".format(i)
        if src_fname in camresults.keys():
            C_src = camresults[src_fname][2]
            xpos = C_avg[0]-C_src[0]
            ypos = C_avg[1]-C_src[2]
            positions.append((xpos, ypos))
            count = count + 1
            # print xpos,ypos
        else:
            positions.append((-1, -1))
            count = count + 1

    out_f = file(camerapos, 'w')
    out_f.write("<!-- lightfield data -->\n")
    out_f.write("<texturefile>./textures/{0}</texturefile>\n".format(os.path.basename(contactimg_file)))
    out_f.write("\n")
    out_f.write("<subimagewidth>{0}</subimagewidth>\n".format(thumb_w))
    out_f.write("<subimageheight>{0}</subimageheight>\n".format(thumb_h))
    out_f.write("\n")
    out_f.write("<numxsubimages>{0}</numxsubimages>\n".format(grid_w))
    out_f.write("<numysubimages>{0}</numysubimages>\n".format(grid_h))
    out_f.write("\n")
    out_f.write("<!-- refocusing parameters -->\n")
    out_f.write("<minscale>-200</minscale>\n")
    out_f.write("<maxscale>10</maxscale>\n")
    out_f.write("\n")    
    out_f.write("<!-- initial state of refocuser -->\n")
    out_f.write("<xstart>0</xstart>\n")
    out_f.write("<ystart>0</ystart>\n")
    out_f.write("<xcount>{0}</xcount>\n".format(grid_w))
    out_f.write("<ycount>{0}</ycount>\n".format(grid_h))
    out_f.write("<scale>0</scale>\n")
    out_f.write("<zoom>1.0</zoom>\n")
    out_f.write("\n")
    out_f.write("<!-- debug information (text, mouse, thumbnail) -->\n")
    out_f.write("<drawthumbnail>1</drawthumbnail>\n")
    out_f.write("<hidecursor>1</hidecursor>\n")
    out_f.write("<debug>1</debug>\n")
    out_f.write("\n")
        
    out_f.write("<!-- camera positions -->\n")
    out_f.write("<cameras>\n")
    for i in range(grid_w * grid_h):
        if i not in skip:
            num = i
            if reorder != None:
                num = reorder[i]
            xpos, ypos = positions[num]
            # print num
            out_f.write("\t<cam>\n\t\t<x>{0}</x>\n\t\t<y>{1}</y>\n\t</cam>\n".format(xpos, ypos))
        else:
            print "skipping {0} in camera positions".format(i)
            num = i-1
            if reorder != None:
                num = reorder[i]
            xpos, ypos = positions[num]
            # print num
            out_f.write("\t<cam>\n\t\t<x>{0}</x>\n\t\t<y>{1}</y>\n\t</cam>\n".format(xpos, ypos))

    out_f.write("</cameras>")
    
    
if __name__ == '__main__':
    global datapath, featurepath, warpedpath, undistortpath, thumbpath, max_texture_size, acq_grid, num_textures, contactimg_file, grid_w, grid_h

    # Define command line argument interface
    parser = argparse.ArgumentParser(description='apply Visual SFM quaternions to a folder of lightfield images', formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('datapath', help='path to lightfield data')
    parser.add_argument('grid', help='acquisition grid as WxH')
    parser.add_argument('--reorder', default=None, help='reorder images to match order of acquisition (wrap, colsfirst)')
    parser.add_argument('--skip', default=[], help='indices of images to skip')
    parser.add_argument('--numtextures', default=1, type=int, help='number of output textures')
    parser.add_argument('--maxtexturesize', default=16384, type=int, help='maximum pixel dimension of output texture')
    parser.add_argument('files', nargs='*', help='glob of input files')
    
    args = parser.parse_args()

    datapath = args.datapath

    # directory of input images
    imagedir = os.path.join(args.datapath, 'original')  

    gridstr = args.grid     # grid layout
    order = args.reorder    # reorder images
    if len(args.skip) > 0:
        skip = [i for i in args.skip.split(',')] #.split(',')        # skip certain images
    else:
        skip = []
        
    num_textures = args.numtextures
    max_texture_size = args.maxtexturesize
    
    # directory of undistorted images
    undistortpath = os.path.join(args.datapath, 'undistorted') 

    # results of N-view match from Visual SFM in windows
    camerasfile = os.path.join(args.datapath, "results/results.nvm.cmvs/00/cameras_v2.txt") 
    
    
    # output paths to save the results
    # if os.path.isdir(args.datapath):
    #     scene_name = args.datapath.split('/')[-2]
    # else:
    #     scene_name = os.path.basename(args.datapath)
    # print scene_name
    scene_name = args.datapath.split('/')[-2]
    
    warpedpath = os.path.join(args.datapath, 'warped')    
    thumbpath = os.path.join(args.datapath, 'thumbs')
    camerapos = os.path.join(args.datapath, scene_name+'.xml')
    contactimg_file = os.path.join(args.datapath, scene_name+'_tex.jpg')

    # create folders as necessary
    if not os.path.exists(warpedpath):
        os.makedirs(warpedpath)

    if not os.path.exists(thumbpath):
        os.makedirs(thumbpath)
    
    # read image filenames
    image_files = args.files
    
    # grid
    grid_w, grid_h = gridstr.split("x")
    grid_w = int(grid_w)
    grid_h = int(grid_h)
    
    print "grid dimensions", grid_w, "x", grid_h
    
    # max_texture_size = 32768
    
    # num_textures = 1
    acq_grid = (grid_w, grid_h)
    
    # read Cameras V2 file (results from VSFM)    
    cameraloc_img = os.path.join(args.datapath, scene_name+'_cameras.png')
    camresults, R_avg, C_avg = readCamerasV2File(camerasfile, cameraloc_img)
    
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
        generate_contact_sheet(image_files, reorder, skip)
        
        # print reorder
        # export camera center coordinates    
        write_xml_scene(camerapos, contactimg_file, image_files, camresults, reorder, skip)

    elif order=='colsfirstwrap':
        print "columns first, wrapped"

        # reorder
        reorder = []
        for i in range(grid_w):
            if i%2==0:
                reorder += range(i, i+grid_h*grid_w, grid_w)
            else:
                reorder += range(i+(grid_h-1)*grid_w, i-1, -grid_w)
                
        print len(reorder)
        
        # print skip
        for i in reorder:
            fname = "frame_{0:04d}.jpg".format(i)
            if fname not in camresults.keys():
                skip = skip + [i]
        
        print skip
        
        # make contact sheet
        generate_contact_sheet(image_files, reorder, skip)
    
        # print reorder
        # export camera center coordinates    
        write_xml_scene(camerapos, contactimg_file, image_files, camresults, reorder, skip)
    
    elif order=='verticalwrap':
        
        print "vertical wrap (top->bottom, bottom->top, etc, col at a time)"
        
        # reorder
        reorder = np.zeros((grid_h, grid_w), dtype=int)
        
        for i in range(grid_w):
            if i%2==0:
                reorder[:,i] = range(i*grid_h, (i+1)*grid_h)
            else:
                reorder[:,i] = range((i+1)*grid_h-1, i*grid_h-1, -1)
                
        reorder = np.reshape(reorder, grid_h * grid_w)
        
        # print skip
        for i in reorder:
            fname = "frame_{0:04d}.jpg".format(i)
            if fname not in camresults.keys():
                skip = skip + [i]
        
        print skip
        
        # make contact sheet
        generate_contact_sheet(image_files, reorder, skip)
    
        # print reorder
        # export camera center coordinates    
        write_xml_scene(camerapos, contactimg_file, image_files, camresults, reorder, skip)
            
    else:
        
        # make contact sheet
        generate_contact_sheet(image_files)#reorder)

        # export camera center coordinates    
        write_xml_scene(camerapos, contactimg_file, image_files, camresults)#, reorder)
        
