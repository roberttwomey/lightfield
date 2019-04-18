import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import argparse
import cv2
import os
import sys
from multiprocessing import Queue
import multiprocessing
import math

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
    
    
def equalize(img):
    """
    Convert BGR image to YCrCb. Equlize based on Intensity. 
    Return equalized BGR image.
    """
    
    ycrcb = cv2.cvtColor(img,cv2.COLOR_BGR2YCR_CB)

    channels = cv2.split(ycrcb)

    channels[0] = cv2.equalizeHist(channels[0])

    ycrcb = cv2.merge(channels);

    eqimg = cv2.cvtColor(ycrcb, cv2.COLOR_YCR_CB2BGR);
        
    # cv2.imshow('equ',equ)
    # cv2.waitKey(0)
    # cv2.destroyAllWindows()
    
    return eqimg


def mp_equalize(srcs, nprocs):
    
    def worker(srcs, out_q):
        """ The worker function, invoked in a process. 'srcs' is a
            list of input files. Every file is intensity equalized.
        """
        outdict = {}

        for src in srcs:
            imgfile = os.path.basename(src)
            # print imgfile
            
            img = cv2.imread(src)
            eqimg = equalize(img)

            fname, ext = os.path.splitext(os.path.basename(imgfile))
            eqfile = os.path.join(outpath, fname+ext.lower())
            cv2.imwrite(eqfile, eqimg)
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
                args=(srcs[chunksize * i:chunksize * (i + 1)], out_q))
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

    # Define command line argument interface
    parser = argparse.ArgumentParser(description='equalize intensity of rover images')
    parser.add_argument('outpath', help='output path to equalized images')
    parser.add_argument('files', nargs='*', help='glob of input files')
    
    args = parser.parse_args()

    outpath = args.outpath    # out path to save the results
    
    # create output paths as necessary
    if not os.path.exists(outpath):
        os.makedirs(outpath)
    
    # read image filenames
    # img_files = readImageFilenames(imagedir)
    img_files = args.files
    
    mp_equalize(img_files, 8)
        
    # for imgfile in img_files:
    #     img = cv2.imread(imgfile)
    #     eqimg = equalize(img)
    #
    #     fname, ext = os.path.splitext(os.path.basename(imgfile))
    #     eqfile = os.path.join(outpath, fname+"_eq"+ext.lower())
    #     cv2.imwrite(eqfile, eqimg)
    #     print ".",
    #     sys.stdout.flush()

    
        



# from skimage import data, img_as_float
# from skimage import exposure

# img = cv2.imread("/Volumes/Work/Projects/lightfield/data/towers/original/image0200.jpg")

# img_adapteq = #exposure.equalize_adapthist(img, clip_limit=0.03)

# gray = cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)

# equ = cv2.equalizeHist(gray)    # Remember histogram equalization works only for grayscale images

# cv2.imshow('src',gray)

