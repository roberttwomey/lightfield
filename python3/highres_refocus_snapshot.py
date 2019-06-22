#!/usr/local/bin/python3
"""
    this program creates high-res refocused images from light field data

    it takes input parameters from a snapshot file (generated in refocuser
    app) and generates output image

    
    Robert Twomey 2018
    robert@roberttwomey.com

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
import xml.etree.ElementTree as ET
import re
        
# helpers

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
            print("Unable to open directory: %s" % dir_name, file=sys.stderr)
            sys.exit(-1)

    dir_list = map(lambda x: os.path.join(dir_name,x), dir_list)

    # print(len(dir_list)+"files in directory")
    # print(dir_list)
    # for thisdir in dir_list:
    #     print(thisdir)
    
    return list(dir_list)


def calcReordering(grid_w, grid_h, order = None):

    if order=='wrap':
        print("wrapping")

        # reorder
        reorder = []
        for i in range(grid_h):
            if i%2==0:
                reorder += range(i*grid_w, (i+1)*grid_w)
            else:
                reorder += range((i+1)*grid_w-1,i*grid_w-1, -1)

    elif order=='colsfirstwrap':
        print("columns first, wrapped")

        # reorder
        reorder = []
        for i in range(grid_w):
            if i%2==0:
                reorder += range(i, i+grid_h*grid_w, grid_w)
            else:
                reorder += range(i+(grid_h-1)*grid_w, i-1, -grid_w)
                
        print(len(reorder))
        
        # print skip
        for i in reorder:
            fname = "frame_{0:04d}.jpg".format(i)
            if fname not in camresults.keys():
                skip = skip + [i]
        
        print(skip)
    
    elif order=='verticalwrap':
        
        print("vertical wrap (top->bottom, bottom->top, etc, col at a time)")
        
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
        
        print(skip)
        
    else:
        
        reorder = None

    return reorder
                   
def readSnapshotParams(snapshotfile):
    """ Reads refocus parameters from snapshot file """
    # texture
    # fscale
    # xoffset, yoffset
    # xstart, ystart
    # xcount, ycount
    # zoom
    
    infile = open(snapshotfile, 'r')
    lines = infile.readlines()
    
    xmlfile = lines[0].strip('\r\n')
    fscale = float(lines[1].strip('\r\n'))
    roll = [float(i) for i in lines[2].strip('\r\n').split(',')]
    ap_loc = [int(i) for i in lines[3].strip('\r\n').split(',')]
    ap_size = [int(i) for i in lines[4].strip('\r\n').split(',')]
    zoom = float(lines[5].strip('\r\n'))
    
    return xmlfile, fscale, roll, ap_loc, ap_size, zoom

def readSceneFile(scenefile):

    tree = ET.parse(scenefile)
    root = tree.getroot()

    gridw = int(root.find("numxsubimages").text)
    gridh = int(root.find("numysubimages").text)
    subimagewidth = int(root.find("subimagewidth").text)
    # print(gridw)
    # print(gridh)

    camera_offsets = []

    for camera in root.iter('cam'):
        xoffset = float(camera.find("x").text)
        yoffset = float(camera.find("y").text)
        # print(xoffset, yoffset)
        camera_offsets.append([xoffset, yoffset])

    # parse cameras
    # for camera in root.iter('camera'):
    return gridw, gridh, camera_offsets, subimagewidth

def getReorderedNum(reorder, x, y, grid_w):
    imagenum = x + y * grid_w
    if reorder == None:
        return imagenum
    else:
        imagenum = reorder[imagenum]
    return imagenum

def nextFileName(filebase):
    fname, ext = filebase.split('.')

    done = False
    i = 0
    # outfile = fname+'_%03d.jpg'
    outfile = fname+'_%03d.'+ext
    while os.path.exists(outfile % i):
        i = i +1
    print(outfile % i)

    return outfile % i

if __name__ == '__main__':
    global featurepath, warpedpath, undistortpath, thumbpath, max_texture_size, acq_grid, num_textures, contactimg_file

    # command line argument interface
    parser = argparse.ArgumentParser(description='render refocused snapshot at full resolution')
    parser.add_argument('datapath', help='path to lightfield data')
    parser.add_argument('infile', help='snapshot text file describing refocus parameters')
    parser.add_argument('--upscale', default=1.0, type=float, help='multiplier for output resolution')

    # parser.add_argument('outfile', help='filename to write')
    args = parser.parse_args()

    # read arguments
    datapath = args.datapath
    snapshotfile = args.infile  # snapshot description text file
    # outfile = args.outfile

    # texture
    # fscale
    # xoffset, yoffset
    # xstart, ystart
    # xcount, ycount
    # zoom
    
    xmlfile, fscale, roll, ap_loc, ap_size, zoom = readSnapshotParams(snapshotfile)

    print(xmlfile, fscale, roll, ap_loc, ap_size, zoom)
    # exit()

    # scenename = os.path.basename(texture).split('_tex')[0]
    scenename = os.path.basename(xmlfile).split('.xml')[0]
    lfdatapath = os.path.join(datapath, scenename)
    warped = os.path.join(lfdatapath, 'warped')
    # output = outfile
    # output = nextFileName(outfile)
    # output = nextFileName(os.path.join("/Volumes/Work/Projects/lightfield/data/highres_stills", os.path.splitext(os.path.basename(snapshotfile))[0]+".tif"))
    output = nextFileName(os.path.join("/Volumes/Work/Projects/lightfield/data/highres_stills", os.path.splitext(os.path.basename(snapshotfile))[0]+".jpg"))

    scenefile = os.path.join(lfdatapath,os.path.basename(xmlfile))
    
    grid_w, grid_h, camera_offsets, subimagewidth = readSceneFile(scenefile)
    
    # fscale = fscale * subimagewidth

    reorder = calcReordering(grid_w, grid_h, None)
    # print(reorder)

    imagefiles = readImageFilenames(warped)
    # print(imagefiles)

    
    ap_center = np.round(np.array(ap_loc) + np.array(ap_size)/2).astype(int);
    centernum = ap_center[0] + ap_center[1] * grid_w
    centerpos = np.array(camera_offsets[centernum])
    # print(ap_center)
    # print(centerpos)

    # average over a large number of images
    # https://stackoverflow.com/questions/17291455/how-to-get-an-average-picture-from-100-pictures-using-pil/17383621#17383621

    src_img_rgb = cv2.imread(imagefiles[0])
    h, w, channels = src_img_rgb.shape

    # upres = 1.0
    upres = args.upscale
    newh = int(h * upres)
    neww = int(w * upres)
    combined_image=np.zeros((newh, neww, channels),np.float64)

    # combined_image=np.zeros((h, w, channels),np.float64)
    # combined_image=np.zeros((h, w, channels),np.float128)
    
    numimages = ap_size[0] * ap_size[1]

    for y in range(ap_size[1]):
        print("row"+str(y))
        for x in range(ap_size[0]):

            # find the file number that corresponds to curent position
            imagenum = ap_loc[0]+x + (ap_loc[1]+y) * grid_w
            # reorderednum = imagenum
            reorderednum = getReorderedNum(reorder, ap_loc[0]+x, ap_loc[1]+y, grid_w)

            # open image
            src_img_rgb = cv2.imread(imagefiles[reorderednum])
            h, w, channels = src_img_rgb.shape
            halfx = float(w/2)
            halfy = float(h/2)

            # offset = np.array([camera_offsets[imagenum][0], -1.0 * camera_offsets[imagenum][1]])
            offset = np.array([camera_offsets[imagenum][0], camera_offsets[imagenum][1]])
            
            print(imagenum, reorderednum, offset)

            # shift = (offset - centerpos) * fscale * w            
            # Ho = np.array([[1, 0, shift[0]],
            #     [0, 1, -1.0 * shift[1]],
            #     [0, 0,     1]], dtype=float)

            # with zoom and roll
            shift = (offset - centerpos) * fscale * neww
            Ho = np.array([[upres/zoom, 0, shift[0]+roll[0]*neww],
                [0, upres/zoom, -1.0 * shift[1]+roll[1]*newh],
                [0, 0,     1]], dtype=float)

            # just focus
            # shift = (offset - centerpos) * fscale * neww
            # Ho = np.array([[upres, 0, shift[0]],
            #     [0, upres, -1.0 * shift[1]],
            #     [0, 0,     1]], dtype=float)

            im2 = np.zeros((newh, neww, channels))
            # im2 = cv2.warpPerspective(src_img_rgb, Ho, (neww, newh),
            #     flags=cv2.INTER_LINEAR,
            #     borderMode=cv2.BORDER_CONSTANT)
            
            # cubic interpolation, wrapped border
            im2 = cv2.warpPerspective(src_img_rgb, Ho, (neww, newh),
            # flags=cv2.INTER_CUBIC,
            flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_WRAP)

            # im2 = np.zeros((h, w, channels))
            # im2 = cv2.warpPerspective(src_img_rgb, Ho, (w, h),
            #     flags=cv2.INTER_LINEAR,
            #     borderMode=cv2.BORDER_CONSTANT)

            # add to image array
            # images.append(src_img_rgb)
            # images.append(im2)
            combined_image = combined_image + im2/numimages

    # print basic image info
    # height, width, channels = images[0].shape
    # print(height, width, channels)
    # print(len(images))


    
    # average images to result
    # images = np.array([np.array(imarray) for imarray in images])
    # combined_image = np.array(np.mean(images, axis=(0)), dtype=np.uint8)
    
    # show results in window
    # cv2.imshow("result", combined_image)
    # cv2.waitKey(0)
    # cv2.destroyAllWindows()

    # write results to file
    cv2.imwrite(output, combined_image.astype(np.float64))
    






# def mp_warp(srcs, params, R_avg, C_avg, nprocs):
    
#     def worker(srcs, params, R_avg, C_avg, out_q):
#         """ The worker function, invoked in a process. 'srcs' is a
#             list of input files, 'params' is a dict of calculated 
#             camera parameters by filename. R_avg and C_avg are the
#             compute average camera rotation and position to be 
#             rectified to.
#             Results are placed in a dictionary that's pushed to a queue.
#         """
#         outdict = {}

#         for src in srcs:
#             src_fname = os.path.basename(src)
#             if src_fname in params.keys():
#                 outdict[src] = warpAvg(src, params[src_fname], R_avg, C_avg)
#             else:
#                 write_blank(src)
#             sys.stdout.write(".")
#             sys.stdout.flush()
            
#         out_q.put(outdict)
        
#     # Each process will get 'chunksize' nums and a queue to put his out
#     # dict into
#     out_q = Queue()
#     chunksize = int(math.ceil(len(srcs) / float(nprocs)))
#     procs = []
    
#     for i in range(nprocs):
#         p = multiprocessing.Process(
#                 target=worker,
#                 args=(srcs[chunksize * i:chunksize * (i + 1)],
#                       params, R_avg, C_avg, out_q))
#         procs.append(p)
#         p.start()
    
#     # Collect all results into a single result dict. We know how many dicts
#     # with results to expect.
#     resultdict = {}
#     for i in range(nprocs):
#         resultdict.update(out_q.get())

#     # Wait for all worker processes to finish
#     for p in procs:
#         p.join()

#     print
#     return resultdict
            
            
# def warpAvg(src, params, R_avg, C_avg):
#     global warpedpath, undistortpath, thumbpath, acq_grid, max_texture_size, num_textures
    
#     # params for src image
#     f1, T1, C1, R_mat1, R_quat1, normRadialDistortion1, undistort_fname = params

#     # image files
    
#     undistort = os.path.join(undistortpath, undistort_fname)
#     src_img_rgb = cv2.imread(undistort)

#     # name, ext = os.path.splitext(os.path.basename(src))
#     # eq_img = os.path.join(undistortpath, name + ".jpg")#"_eq.jpg")

#     #print eq_img

#     # src_img_rgb = cv2.imread(eq_img)

#     #src_img_rgb = cv2.imread(src)
    
#     w = src_img_rgb.shape[1]
#     h = src_img_rgb.shape[0]

#     w_translate = 0#(C1[0] - C_avg[0]) #* f1 #* 200#w/2
#     h_translate = 0#(C1[2] - C_avg[1]) #* f1 #* 200# w/2

#        # http://math.stackexchange.com/questions/87338/change-in-rotation-matrix

#     #print "R_mat1:", R_mat1
#     # print "R_mat1T:", R_mat1.T

#     # print "R_mat2:", R_mat2

#     # R_mat1 = R_mat1 / R_mat1[2,2]
#     # R_mat2 = R_mat2 / R_mat2[2,2]
#     #
#     R_rod1, jacobian = cv2.Rodrigues(R_mat1)
#     #print "R_rod1:", R_rod1

#     #print "R_avg:", R_avg
    
#     # R_rod2, jacobian = cv2.Rodrigues(R_mat2)
#     # print "R_rod2:", R_rod2

#     R_rod_12 = R_rod1 - R_avg
#     # R_rod_12 = R_avg - R_rod1
    
#     #print "R_rod_12:", R_rod_12 * (180 / pi)
#     # print R_rod_12

#     # switch order of 2nd and 3rd rotation
#     R_rod_12 = np.array([R_rod_12[0], R_rod_12[1], -1 * R_rod_12[2]])
    
#     #lprint R_rod_12
    
#     R_12, jacobian = cv2.Rodrigues(R_rod_12)
#     #print "R_12:", R_12

#     # # R_12 = R_12/R_12[2,2]
#     # R_12_inv = linalg.inv(R_12)
#     #
#     # # H = np.identity(3) * T1.reshape((3,1))
#     # H = R_mat1#R_12
#     #
#     # Tdiff = T2 - T1
#     # print "Tdiff:", Tdiff

#     # Cdiff = C1 - C2
#     # print "Cdiff:", Cdiff

#     # #Tdiff = Tdiff / Tdiff[2]
#     # # print "Tdiff norm:", Tdiff
#     #
#     # M = np.identity(3)
#     #
#     # M[0,0] = f2
#     # M[1,1] = f2
#     #

#     # H = np.identity(3)

#     # H[0,2] =  Tdiff[0]
#     # H[1,2] =  Tdiff[1]
#     # H[2,2] =  Tdiff[2]

#     # sf = 0.1
#     # H[0,2] =  Cdiff[0] * w * sf
#     # H[1,2] =  -1 * Cdiff[2] * h * sf
#     # H[2,2] =  1

#     # print "M:",M, "H:",H
#     # H = M * H
#     # print "M * H", M * H

#     #
#     # H[0,2] =  50
#     # H[1,2] =  50
#     # H[2,2] =  1

#     # http://stackoverflow.com/questions/12288473/perspective-warping-in-opencv-based-on-know-camera-orientation

#     R = R_12 #R_mat1.T

#     #Create trans mat and combine with translation matrix
#     T = np.array([[1], [0], [(-w/2)+w_translate],
#                        [0], [1], [(-h/2)+h_translate],
#                        [0], [0], [1]]).reshape((3,3))
#     #print "T:", T

#     R[0,2] = 0
#     R[1,2] = 0
#     R[2,2] = 1

#     trans = np.dot(R, T)
#     trans[2,2] += w

#     # adjustment to focal length
#     fscale = 1.0
#     K = np.array([[f1*fscale], [0], [w/2],
#                   [0], [f1*fscale], [h/2],
#                   [0], [0], [1]]).reshape(3,3)
                
#     #print "K:", K

#     H = np.dot(K, trans)

#     # pad and recenter
#     oversize = 0#0.05
    
#     move_h = np.matrix(np.identity(3), np.float32)

#     img_w = int(src_img_rgb.shape[1] * (1.0 + oversize * 2.0))
#     img_h = int(src_img_rgb.shape[0] * (1.0 + oversize * 2.0))
 
#     move_h[0,2] = src_img_rgb.shape[1] * (oversize * 2.0) / 2
#     move_h[1,2] = src_img_rgb.shape[0] * (oversize * 2.0) / 2

#     H = np.dot(move_h, H)

#     H = H / H[2,2]
#     #print "H", H

#     src_img_warp = cv2.warpPerspective(src_img_rgb, H, (img_w, img_h))#w, h))

#     fname, ext = os.path.splitext(os.path.basename(src))
#     warp_file = os.path.join(warpedpath, fname+"_warp"+ext.lower())
#     cv2.imwrite(warp_file, src_img_warp)
    
#     # generate thumbnail
#     acq_w, acq_h = acq_grid
#     thumb_w = max_texture_size / acq_w * num_textures
#     thumb_h = thumb_w * img_h / img_w
    
#     thumb_img = cv2.resize(src_img_warp, (thumb_w, thumb_h))
#     thumb_file = os.path.join(thumbpath, fname+ext.lower())
#     cv2.imwrite(thumb_file, thumb_img)

#     # return (warp_file, thumb_file)
               

# def generate_contact_sheet(reorder = None):
#     global thumbpath, max_texture_size, grid_h, grid_w, num_textures, contactimg_file
    
#     # generate tiled image
#     thumbstr = "image{0:04d}.jpg"
#     thumb_file = os.path.join(thumbpath, thumbstr.format(1))
#     thumb_img = cv2.imread(thumb_file)
#     thumb_h, thumb_w, thumb_chan = thumb_img.shape

#     max_texture_w = max_texture_size
#     max_texture_h = thumb_h * grid_h

#     print "generating contact sheet...",

#     part_w = grid_w/num_textures

#     for n in range(num_textures):
        
#         contact_img = np.zeros((max_texture_h, max_texture_w, 3), np.uint8)
#         print contact_img.shape
        
#         for j in range(grid_h):
#           for i in range(part_w):
#               num = (n * part_w) + i + (j * grid_w)
#               if reorder != None:
#                   #print num
#                   num = reorder[num]
#               thumb_file = os.path.join(thumbpath, thumbstr.format(num))
#               # print thumb_file,
#               if os.path.exists(thumb_file):
#                   thumb_img = cv2.imread(thumb_file)
#                   thumb_h, thumb_w, thumb_chan = thumb_img.shape
#                   x = i * thumb_w
#                   y = j * thumb_h
#                   # print x,y, thumb_w ,thumb_h
#                   # print contact_img.shape
#                   contact_img[y:(y+thumb_h), x:(x+thumb_w)] = thumb_img

#         print "writing contact image", contact_img.shape, "to",
#         fname, ext = os.path.splitext(contactimg_file)
#         contactimg_file = fname+str(n)+ext
#         print contactimg_file
#         cv2.imwrite(contactimg_file, contact_img)
    # 