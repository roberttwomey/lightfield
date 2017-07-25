#!/usr/bin/env python

"""
need to fix cv.Load methods below

20170606

"""

import numpy as np
import cv2
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

            image_filename = os.path.basename(src).replace("_eq", '')
            undistort_filename = os.path.join(outpath, image_filename)
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
    # fs = cv2.FileStorage(calib_filename, cv2.FILE_STORAGE_READ)
    # # camera_matrix = np.asarray(fs.getNode('camera_matrix'))
    # camera_matrix = np.asarray(fs['camera_matrix'])
    # print camera_matrix
    # exit()

    # dist_coeffs = fs.getNode('distortion_coefficients')

    # !!! TOTAL KLUGE, SHOULD READ FROM FILE !!!
    camera_matrix = np.array([2.5148029100863805e+03, 0.0, 1.2932899929829127e+03, 0.0, 2.5196679186760493e+03, 9.2850768663425754e+02, 0.0, 0.0, 1.0]).reshape((3,3))
    dist_coeffs = np.array([8.9556056301440312e-02, -2.4792541533716420e-01, -3.8170614382947539e-03, 6.4675682790495625e-04, -4.1359741393786997e-01])
    # camera_matrix = np.asarray(cv2.Load(calib_filename, cv2.CreateMemStorage(), 'camera_matrix'))
    # dist_coeffs = np.asarray(cv2.Load(calib_filename, cv2.CreateMemStorage(), 'distortion_coefficients'))
    
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
    mp_undistort(files, K, d, outpath, 8)

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
