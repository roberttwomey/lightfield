#!/usr/local/bin/python3
"""
    this program creates high-res refocused images from light field data

    takes input from a resampled control signal csv file (generated in supercollider)
    
    generates native-res output image

    
    Robert Twomey 2019
    robert@roberttwomey.com

    example usage: 
    
    osx

    python3 highres_refocus_csv.py /Volumes/SATCHEL/lightfield/bigdata/shoots/ \
        /Volumes/SATCHEL/lightfield/bigdata/shoots/bookcase/bookcase.xml \
        /Volumes/Work/Projects/lightfield/data/highres_stills/ \
        bookcase_1fs.png \
        /Volumes/Work/Projects/lightfield/data/control_signals/rover_scene1_resampled_1fs.csv


    python3 highres_refocus_csv.py /media/rtwomey/linuxdata/lightbox/shoots/ \
        /media/rtwomey/linuxdata/lightbox/shoots/bookcase/bookcase.xml \
        ~/projects/lightfield/data/highres_stills/ \
        bookcase1fps/bookcase.png \
        ~/projects/lightfield/data/control_signals/rover_5_resampled_1fs.csv


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
# from pylab import * 
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
    print(outfile % i)

    return outfile % i

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
    csvfile = args.csvfile


    # refocuser control signals
    # fscale = args.fscale
    # roll = [float(i) for i in args.roll.split(',')]
    # ap_loc = [int(i) for i in args.aploc.split(',')]
    # ap_size = [int(i) for i in args.apsize.split(',')]
    # zoom = args.zoom 

    # filenames
    scenename = os.path.basename(xmlfile).split('.xml')[0]
    lfdatapath = os.path.join(datapath, scenename)
    warped = os.path.join(lfdatapath, 'warped')

    # acquisition grid information for scene
    scenefile = os.path.join(lfdatapath,os.path.basename(xmlfile))            
    grid_w, grid_h, camera_offsets, subimagewidth = readSceneFile(scenefile)
    print(grid_w, grid_h, subimagewidth)


    # calculate image reordering
    reorder = calcReordering(grid_w, grid_h, 'wrap')
    # print(grid_w*grid_h, size(reorder))            
    # print(reorder)

    # read image file names
    imagefiles = readImageFilenames(warped)
    # for i, image in enumerate(imagefiles):
    #     print(image, "->", reorder[i])

    # exit()
    # print(imagefiles)



    with open(csvfile) as signalfile:
        signalreader = csv.reader(signalfile)
        rows = list(signalreader)
        # for i in [0 49 97 145 193]:#range(len(rows)):
        for i in range(0, 1440):
            row = rows[i]

            # get image params for current frame
            fscale = float(row[0])
            zoom = float(row[1])
            roll = np.array([float(row[2]), float(row[3])])
            ap_loc = np.array([int(float(row[4])), int(float(row[5]))])
            ap_size = np.array([int(float(row[6])), int(float(row[7]))])
            print(xmlfile, fscale, zoom, roll, ap_loc, ap_size)

            # create output filename
            fname, ext = os.path.splitext(outfilename)
            output = (fname+'_%05d'+ext) % i
            output = nextFileName(os.path.join(outpath, output))
            # print(ap_loc,ap_size, ap_loc+ap_size)
            ap_max = np.minimum((ap_loc+ap_size), np.array([grid_w, grid_h]))
            # ap_max = ap_loc+ap_size
            ap_center = np.round((ap_loc+ap_max)/2.0).astype(int)
            # ap_center = np.round(np.array(ap_loc) + np.array(ap_size)/2.0).astype(int);
            print(ap_loc, ap_max, ap_center)
            centernum = ap_center[0] + (ap_center[1] * grid_w)
            print(centernum)
            centerpos = np.array(camera_offsets[centernum])
            
            ap_size = ap_max - ap_loc
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
                ypos = ap_loc[1]+y
                print("row"+str(ypos))
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
                    print([xpos, ypos], imagenum, "->", reorderednum)

                    # open image
                    src_img_rgb = cv2.imread(imagefiles[reorderednum])
                    h, w, channels = src_img_rgb.shape
                    halfx = float(w/2)
                    halfy = float(h/2)

                    # offset = np.array([camera_offsets[imagenum][0], -1.0 * camera_offsets[imagenum][1]])
                    offset = np.array([camera_offsets[imagenum][0], camera_offsets[imagenum][1]])
                    
                    # focal shift with zoom
                    fshift = (offset - centerpos) * fscale * neww/zoom

                    # Ho = np.array([[upres/zoom, 0, shift[0]+roll[0]*neww],
                    #     [0, upres/zoom, -1.0 * shift[1]+roll[1]*newh],
                    #     [0, 0,     1]], dtype=float)

                    # worked for view 1
                    # Ho = np.array([[upres/zoom, 0, shift[0]+roll[0]*neww - halfx],
                    #     [0, upres/zoom, -1.0 * shift[1]-roll[1]*neww + halfy*zoom],
                    #     [0, 0,     1]], dtype=float)

                    # 0.3 offsets not working
                    # Ho = np.array([[upres/zoom, 0, fshift[0]-(1-zoom)*halfx+roll[0]*neww],
                    #     [0, upres/zoom, -1.0 * fshift[1]-(1-zoom)*halfx+roll[1]*neww],
                    #     [0, 0,     1]], dtype=float)

                    recenterx = (1.0-zoom)*halfx
                    recentery = (1.0-zoom)*halfx
                    # print(recenterx, recentery)
                    pixelrollx = float(roll[0])*float(w)
                    pixelrolly = float(roll[1])*float(w)
                    # print(pixelrollx, pixelrolly)

                    Ho = np.array([[upres/zoom, 0, fshift[0]-recenterx+pixelrollx],
                        [0, upres/zoom, -1.0 * fshift[1]-recentery+pixelrolly],
                        [0, 0,     1]], dtype=float)

                    im2 = np.zeros((newh, neww, channels))
                    
                    # cubic interpolation, wrapped border
                    im2 = cv2.warpPerspective(src_img_rgb, Ho, (neww, newh),
                    # flags=cv2.INTER_CUBIC,
                    flags=cv2.INTER_LINEAR,
                    borderMode=cv2.BORDER_WRAP)

                    combined_image = combined_image + im2/numimages

            # write results to file
            # cv2.imwrite(output, combined_image.astype(np.float64))
            # cv2.imwrite(output, combined_image, [int(cv2.IMWRITE_PNG_COMPRESSION), png_compression=9])
            if os.path.splitext(output)[1]==".png":
                cv2.imwrite(output, combined_image, [int(cv2.IMWRITE_PNG_COMPRESSION), 9])
            else:
                cv2.imwrite(output, combined_image.astype(np.float64))
            
            