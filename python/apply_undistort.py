#!/usr/bin/env python

import numpy as np
import cv2, cv
import os
import multiprocessing
from multiprocessing import Queue
import math

def mp_undistort(srcs, K, d, outpath, nprocs = 4):
    
    def worker(srcs, K, d, outpath, out_q):
        """ The worker function, invoked in a process. 'srcs' is a
            list of input files, 'K' is a calculated camera matrix,
            'd' is a calculated camera distortion.
            Results are saved to disk
        """
        outdict = {}

        for src in srcs:
            img = cv2.imread(src)
            h, w = img.shape[:2]

            newcamera, roi = cv2.getOptimalNewCameraMatrix(K, d, (w,h), 0) 
            newimg = cv2.undistort(img, K, d, None, newcamera)

            undistort_filename = os.path.join(outpath, os.path.basename(src))
            cv2.imwrite(undistort_filename, newimg, [int(cv2.IMWRITE_JPEG_QUALITY), 100])

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
                      K, d, outpath, out_q))
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
    import sys, argparse
    from glob import glob

    parser = argparse.ArgumentParser(description='apply camera calibration to undistort images')
    parser.add_argument('calibfile', help='camera calibration file from opencv chessboard calibration')
    parser.add_argument('outpath', help='path to save undistorted images')
    parser.add_argument('files', nargs='*', help='glob of input files')

    args = parser.parse_args()

    calib_filename = args.calibfile   # yaml calibration file
    outpath = args.outpath  # directory to output images
    files = args.files  # path to input images
    
    # load camera matrix and distortion coefficients
    camera_matrix = np.asarray(cv.Load(calib_filename, cv.CreateMemStorage(), 'camera_matrix'))
    dist_coeffs = np.asarray(cv.Load(calib_filename, cv.CreateMemStorage(), 'distortion_coefficients'))
    
    print "Read camera calibration"
    print camera_matrix
    print dist_coeffs    
    
    # create output path if necessary
    if not os.path.exists(outpath):
        os.makedirs(outpath)

    
    # undistort images
    K = camera_matrix
    d = dist_coeffs
    
    print "Undistorting images...",
    mp_undistort(files, K, d, outpath)
    print "done!"
    
    # print "Undistorting images...",
    # for fn in files:
    #     img = cv2.imread(fn)
    #     h, w = img.shape[:2]
    #
    #     newcamera, roi = cv2.getOptimalNewCameraMatrix(K, d, (w,h), 0)
    #     newimg = cv2.undistort(img, K, d, None, newcamera)
    #
    #     undistort_filename = os.path.join(outpath, os.path.basename(fn))
    #     cv2.imwrite(undistort_filename, newimg)
    #     sys.stdout.write(".")
    #     sys.stdout.flush()
    #
    # print "done!"
