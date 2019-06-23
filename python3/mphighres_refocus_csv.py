#!/usr/local/bin/python3
"""

    MULTIPROCESS / MULTITHREADED 

    this program creates high-res refocused images from light field data

    takes input from a resampled control signal csv file (generated in supercollider)
    
    generates native-res output image
    
    Robert Twomey 2019
    robert@roberttwomey.com

    example usage: 
    
OSX native res:

python3 mphighres_refocus_csv.py /Volumes/SATCHEL/lightfield/bigdata/shoots/ \
    /Volumes/SATCHEL/lightfield/bigdata/shoots/bookcase/bookcase.xml \
    /Volumes/Work/Projects/lightfield/data/highres_stills/ mpbookcase.jpg \
    /Volumes/Work/Projects/lightfield/data/control_signals/rover_5_resampled_1fs.csv \
    49 61 4

OSX 4k upscale: 

python3 highres_refocus_csv.py /Volumes/SATCHEL/lightfield/bigdata/shoots/ \
    /Volumes/SATCHEL/lightfield/bigdata/shoots/bookcase/bookcase.xml \
    /Volumes/Work/Projects/lightfield/data/highres_stills/ \
    bookcase4k.jpg --upscale 1.1112 \
    /Volumes/Work/Projects/lightfield/data/control_signals/rover_5_resampled_1fs.csv 

Linux:

python3 mphighres_refocus_csv.py /media/rtwomey/linuxdata/lightbox/shoots/ \
    /media/rtwomey/linuxdata/lightbox/shoots/bookcase/bookcase.xml \
    ~/projects/lightfield/data/highres_stills/ \
    bookcase1fps/mpbookcase.png \
    ~/projects/lightfield/data/control_signals/rover_5_resampled_1fs.csv \
    49 67 8
    
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
import xml.etree.ElementTree as ET
import re
import csv

        
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
                # reorder += range((i+1)*grid_w+1,i*grid_w+1, -1)
                # reorder += range((i+1)*grid_w-1,i*grid_w-1, -1)

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
    try: 
        if reorder == None:
            return imagenum
        else:
            return reorder[imagenum]
    except:
        print(imagenum, size(reorder), x, y)
        exit()

def nextFileName(filebase):
    fname, ext = filebase.split('.')

    done = False
    i = 0
    # outfile = fname+'_%03d.jpg'
    outfile = fname+'_%03d.'+ext
    while os.path.exists(outfile % i):
        i = i +1
    # print(outfile % i)

    return outfile % i


def calcFrame(row, i, paths, params, upres=1.0):

    datapath, imagefiles, xmlfile, csvfile, outpath, outfilename = paths
    grid_w, grid_h, camera_offsets, subimagewidth, reorder = params

    # get image params for current frame
    fscale = float(row[0])
    zoom = float(row[1])
    roll = np.array([float(row[2]), float(row[3])])
    ap_loc = np.array([int(float(row[4])), int(float(row[5]))])
    ap_size = np.array([int(float(row[6])), int(float(row[7]))])
    # print("file: {}".format(xmlfile))
    # print("focus: {}".format(fscale))
    # print("zoom: {}".format(zoom))
    # print("roll: {}".format(roll))
    # print("ap_loc: {}\tap_size: {}".format(ap_loc, ap_size))

    # create output filename
    fname, ext = os.path.splitext(outfilename)
    output = (fname+'_%05d'+ext) % i
    output = nextFileName(os.path.join(outpath, output))
    
    ap_max = np.minimum((ap_loc+ap_size), np.array([grid_w, grid_h]))
    # ap_max = ap_loc+ap_size
    ap_center = np.round((ap_loc+ap_max)/2.0).astype(int)
    # ap_center = np.round(np.array(ap_loc) + np.array(ap_size)/2.0).astype(int);
    # print("aperture loc: {}\taperture_size{}\taperture_max{}\taperture_center{}".format(ap_loc, ap_size, ap_max, ap_center))
    centernum = ap_center[0] + (ap_center[1] * grid_w)
    centerpos = np.array(camera_offsets[centernum])
    
    ap_size = ap_max - ap_loc
    
    # average over a large number of images
    # https://stackoverflow.com/questions/17291455/how-to-get-an-average-picture-from-100-pictures-using-pil/17383621#17383621
    src_img_rgb = cv2.imread(imagefiles[0])
    h, w, channels = src_img_rgb.shape

    # upres = 1.0
    newh = int(h * upres)
    neww = int(w * upres)
    combined_image=np.zeros((newh, neww, channels), np.float64)

    # combined_image=np.zeros((h, w, channels),np.float64)
    # combined_image=np.zeros((h, w, channels),np.float128)

    halfw = neww/2.0#float(w/2.0)
    halfh = newh/2.0#float(h/2.0)

    # input res: (w,h)
    # output res: (w,h)/(zoom)
    # difference: ((w,h) - (w,h)/zoom)/2 = (zoom(w,h)/zoom-(w,h)/zoom)/2)
    #               ((w,h)/2zoom)*(zoom-1)
    recenterx = (halfw/zoom)*(1-zoom)
    recentery = (halfh/zoom)*(1-zoom)

    rollx = roll[0]*neww/zoom#roll[0]*w/zoom
    rolly = roll[1]*newh/zoom#roll[1]*h/zoom

    # print("recenter: {}".format((recenterx, recentery)))
    # print("roll: {}".format((rollx, rolly)))
    numimages = ap_size[0] * ap_size[1]

    im2 = np.zeros((newh, neww, channels))
            
    # print("Cameras", end="")
    print("Frame %05d" % i)
    sys.stdout.flush()

    for y in range(ap_size[1]):
        ypos = ap_loc[1]+y
        # print("\n{}:".format(ypos), end="")
        if ypos >= grid_h or ypos < 0:
            break
        for x in range(ap_size[0]):
            xpos = ap_loc[0]+x
            if xpos >= grid_w or xpos < 0:
                break

            # find the file number that corresponds to curent position
            imagenum = xpos + ypos * grid_w

            # reorder
            reorderednum = getReorderedNum(reorder, xpos, ypos, grid_w)
            # print([xpos, ypos], imagenum, "->", reorderednum)
            # print(" {}".format(xpos), end="")
            sys.stdout.flush()

            # open image
            src_img_rgb = cv2.imread(imagefiles[reorderednum])

            # offset = np.array([camera_offsets[imagenum][0], -1.0 * camera_offsets[imagenum][1]])
            camerapos = np.array([camera_offsets[imagenum][0], camera_offsets[imagenum][1]])
            
            # focal shift with zoom
            focalshift = (camerapos - centerpos) * fscale * neww/zoom

            # transform matrix
            Ho = np.array([[upres/zoom, 0, focalshift[0]-recenterx+rollx],
                [0, upres/zoom, -1.0 * focalshift[1]-recentery+rolly],
                [0, 0,     1]], dtype=float)

            # cubic interpolation, wrapped border
            im2 = cv2.warpPerspective(src_img_rgb, Ho, (neww, newh),
            # flags=cv2.INTER_CUBIC,
            flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_WRAP)

            combined_image = combined_image + im2/numimages
    
    # print()
    # write results to file
    # cv2.imwrite(output, combined_image.astype(np.float64))
    # cv2.imwrite(output, combined_image, [int(cv2.IMWRITE_PNG_COMPRESSION), png_compression=9])
    if os.path.splitext(output)[1]==".png":
        cv2.imwrite(output, combined_image, [int(cv2.IMWRITE_PNG_COMPRESSION), 9])
    else:
        cv2.imwrite(output, combined_image.astype(np.float64))
                

def mp_refocus(frames, start, paths, params, upres=1.0, nprocs=8):
    
    def worker(frames, start, paths, params, upres, out_q):
        """ The worker function, invoked in a process. 'srcs' is a
            list of input files, 'params' is a dict of calculated 
            camera parameters by filename. R_avg and C_avg are the
            compute average camera rotation and position to be 
            rectified to.
            Results are placed in a dictionary that's pushed to a queue.
        """
        outdict = {}

        for i, frame in enumerate(frames):
            # src_fname = os.path.basename(src)[:-7]+".jpg"
            # sys.stdout.write(src_fname)
            outdict[i] = calcFrame(frame, start+i, paths, params, upres)
            # sys.stdout.write(".")
            # sys.stdout.flush()
            
        out_q.put(outdict)
 
    out_q = Queue()
    chunksize = int(math.ceil(len(frames) / float(nprocs)))
    procs = []

    # call multithreaded refocuser
    for i in range(nprocs):
        p = multiprocessing.Process(
                target=worker,
                args=(frames[chunksize * i:chunksize * (i + 1)],
                      start+chunksize*i, paths, params, upres, out_q))
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

if __name__ == '__main__':
    global featurepath, warpedpath, undistortpath, thumbpath, max_texture_size, acq_grid, num_textures, contactimg_file

    # command line argument interface
    parser = argparse.ArgumentParser(description='render refocused snapshot at full resolution')
    parser.add_argument('datapath', help='path to lightfield data')
    # parser.add_argument('infile', help='snapshot text file describing refocus parameters')
    parser.add_argument('xmlfile', help='.xml scene descriptor file')
    parser.add_argument('outpath', default='/Volumes/Work/Projects/lightfield/data/highres_stills', help='output directory to save result')
    parser.add_argument('outfilename', default='bookcase.jpg')
    parser.add_argument('--upscale', default=1.0, type=float, help='multiplier for output resolution')
    parser.add_argument('csvfile', help='control signals in csv file')
    parser.add_argument('start', default=0, type=int, help='starting frame number')
    parser.add_argument('end', default=-1, type=int, help='ending frame number')
    parser.add_argument('numcores', default=4, type=int, help='number of cores to use')
    # parser.add_argument('fscale', default=1.0, type=float, help='focus')
    # parser.add_argument('roll', default="0.0,0.0", type=str, help='pixel roll')
    # parser.add_argument('aploc', default="0,0", type=str, help='aperture locaton')
    # parser.add_argument('apsize', default='5,5', type=str, help='aperture size')
    # parser.add_argument('zoom', default=1.0, type=float, help='zoom factor')

    # parser.add_argument('outfile', help='filename to write')
    args = parser.parse_args()

    # read arguments
    datapath = args.datapath # input full res dir
    xmlfile = args.xmlfile  # snapshot description text file
    outpath = args.outpath # directory to save results
    outfilename = args.outfilename
    upres = args.upscale # scaling up output
    csvfile = args.csvfile # image parameters per frame saved from supercollider
    start = args.start
    end = args.end
    numcores = args.numcores

    # do refocusing in parallel

   # 1. Read in scene information from input files

    # filenames and paths
    scenename = os.path.basename(xmlfile).split('.xml')[0]
    lfdatapath = os.path.join(datapath, scenename)
    warped = os.path.join(lfdatapath, 'warped')

    # acquisition grid information for scene
    scenefile = os.path.join(lfdatapath,os.path.basename(xmlfile))            
    grid_w, grid_h, camera_offsets, subimagewidth = readSceneFile(scenefile)
    print(grid_w, grid_h, subimagewidth)

    # calculate image reordering
    reorder = calcReordering(grid_w, grid_h, 'wrap')
    # print(reorder)

    # read image file names for scene
    imagefiles = readImageFilenames(warped)
    # for i, image in enumerate(imagefiles):
    #     print(image, "->", reorder[i])

    paths = (datapath, imagefiles, xmlfile, csvfile, outpath, outfilename)
    params = (grid_w, grid_h, camera_offsets, subimagewidth, reorder)

    # 2. Read in refocusing parameters from csv file
    with open(csvfile) as signalfile:
        signalreader = csv.reader(signalfile)
        frames = list(signalreader)
        # start = 49
        # end = 96
        results = mp_refocus(frames[start:end], start, paths, params, upres, numcores)

    print(results)
            
            