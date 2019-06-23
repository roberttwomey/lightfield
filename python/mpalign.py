#!/usr/local/bin/python
"""
    multi-threaded RANSAC image aligner for gantry acquired lightfield

    http://wiki.roberttwomey.com/Lightfield

    Robert Twomey 2013
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

positions = []
sizes = []

def filter_matches(matches, ratio = 0.75):
    filtered_matches = []
    for m in matches:
        if len(m) == 2 and m[0].distance < m[1].distance * ratio:
            filtered_matches.append(m[0])
    
    return filtered_matches

def imageDistance(matches):

    sumDistance = 0.0

    for match in matches:

        sumDistance += match.distance

    return sumDistance

def findDimensions(image, homography):
    base_p1 = np.ones(3, np.float32)
    base_p2 = np.ones(3, np.float32)
    base_p3 = np.ones(3, np.float32)
    base_p4 = np.ones(3, np.float32)

    (y, x) = image.shape[:2]

    base_p1[:2] = [0,0]
    base_p2[:2] = [x,0]
    base_p3[:2] = [0,y]
    base_p4[:2] = [x,y]

    max_x = None
    max_y = None
    min_x = None
    min_y = None

    for pt in [base_p1, base_p2, base_p3, base_p4]:

        hp = np.matrix(homography, np.float32) * np.matrix(pt, np.float32).T

        hp_arr = np.array(hp, np.float32)

        normal_pt = np.array([hp_arr[0]/hp_arr[2], hp_arr[1]/hp_arr[2]], np.float32)

        if ( max_x == None or normal_pt[0,0] > max_x ):
            max_x = normal_pt[0,0]

        if ( max_y == None or normal_pt[1,0] > max_y ):
            max_y = normal_pt[1,0]

        if ( min_x == None or normal_pt[0,0] < min_x ):
            min_x = normal_pt[0,0]

        if ( min_y == None or normal_pt[1,0] < min_y ):
            min_y = normal_pt[1,0]

    min_x = min(0, min_x)
    min_y = min(0, min_y)

    return (min_x, min_y, max_x, max_y)


def calc_features(img_file):
    global featurepath
    
    """ Feature detector. Take image 'img', calc SIFT features.
        Returns list of points.
    """
    # Use the SIFT feature detector
    detector = cv2.SIFT()

    img = cv2.imread(img_file)
        #next_img_rgb = cv2.imread(next_img_path)
    img = cv2.GaussianBlur(cv2.cvtColor(img,cv2.COLOR_BGR2GRAY), (5,5), 0)

    print img_file,
    # Find key points in base image for motion estimation
    base_features, base_descs = detector.detectAndCompute(img, None)
    #print img_file, base_descs[0]
    print base_descs.shape
    detected = zip(base_features, base_descs)
    results = []
    for point, desc in detected:
        #print type(point) # cv2.KeyPoint
        temp = (point.pt, point.size, point.angle, point.response, point.octave, 
            point.class_id, desc)
        results.append(temp)

    print "writing features for", os.path.basename(img_file), len(results)
    outf = os.path.join(featurepath, os.path.basename(img_file)+".pkl")
    output = open(outf, 'wb')
    pickle.dump(results, output)

    return results

def mp_features(files, nprocs):
    
    def worker(files, out_q):
        """ The worker function, invoked in a process. 'files' is a
            list of files to detect SIFT features. The results are
            placed in a dictionary that's pushed to a queue.
        """
        outdict = {}
        for f in files:
            outdict[f] = calc_features(f)
        out_q.put(outdict)

    # Each process will get 'chunksize' nums and a queue to put his out
    # dict into
    out_q = Queue()
    chunksize = int(math.ceil(len(files) / float(nprocs)))
    procs = []

    for i in range(nprocs):
        p = multiprocessing.Process(
                target=worker,
                args=(files[chunksize * i:chunksize * (i + 1)],
                      out_q))
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

    return resultdict


def saveWarpedImage(base_img, next_img, h):
    global warpedpath
    
    base_img_rgb = cv2.imread(base_img)
    next_img_rgb = cv2.imread(next_img)

    H = h
    H = H / H[2,2]
    H_inv = linalg.inv(H)

#    (min_x, min_y, max_x, max_y) = findDimensions(next_img_rgb, H_inv)

##    move_h = np.matrix(np.identity(3), np.float32)
##   # Adjust max_x and max_y by base img size
##    max_x = max(max_x, base_img_rgb.shape[1])
##    max_y = max(max_y, base_img_rgb.shape[0])
##
##    move_h = np.matrix(np.identity(3), np.float32)
##
##    if ( min_x < 0 ):
##        move_h[0,2] += -min_x
##        max_x += -min_x
##
##    if ( min_y < 0 ):
##        move_h[1,2] += -min_y
##        max_y += -min_y

    move_h = np.matrix(np.identity(3), np.float32)

    img_w = int(base_img_rgb.shape[1] * 1.5)
    img_h = int(base_img_rgb.shape[0] * 1.5)

    move_h[0,2] = base_img_rgb.shape[1] * 0.25
    move_h[1,2] = base_img_rgb.shape[0] * 0.25
    
    mod_inv_h = move_h * H_inv

##    img_w = int(math.ceil(max_x))
##    img_h = int(math.ceil(max_y))

    #print "New Dimensions: ", (img_w, img_h)
    
    next_img_warp = cv2.warpPerspective(next_img_rgb, mod_inv_h, (img_w, img_h))
##    if base_img == next_img:
##        next_img_warp = next_img_rgb
##    else:
##        next_img_warp = cv2.warpPerspective(next_img_rgb, H_inv, (base_img_rgb.shape[1],base_img_rgb.shape[0]))

##    next_img_warp = cv2.warpPerspective(next_img_rgb, H_inv, (base_img_rgb.shape[1],base_img_rgb.shape[0]))

    fname, ext = os.path.splitext(os.path.basename(next_img))
    warp_file = os.path.join(warpedpath, fname+"_warp"+ext)
    cv2.imwrite(warp_file, next_img_warp)


def calc_matches(base_img, featuredict):


    base_descs = np.zeros(shape = (0, 128), dtype=np.float32)
    base_features = []

    for temp in featuredict[base_img]:
        #print point
        #base_descs = np.vstack((base_descs, point_desc))
        point = cv2.KeyPoint(temp[0][0], temp[0][1], temp[1], temp[2], temp[3],
                             temp[4], temp[5])
        desc = temp[6]
        base_descs = np.vstack((base_descs, desc))
        base_features.append(point)

    #print "base",base_img, base_descs.shape

    # Parameters for nearest-neighbor matching
    FLANN_INDEX_KDTREE = 1  # bug: flann enums are missing
    flann_params = dict(algorithm = FLANN_INDEX_KDTREE, 
        trees = 5)
    matcher = cv2.FlannBasedMatcher(flann_params, {})

    closestImage = None

    for next_img, next_feats in featuredict.iteritems():

        if next_img != base_img:

            next_descs = np.zeros(shape = (0, 128), dtype=np.float32)
            next_features = []

            for temp in featuredict[next_img]:
                point = cv2.KeyPoint(temp[0][0], temp[0][1], temp[1], temp[2], temp[3],
                                     temp[4], temp[5])
                desc = temp[6]
                next_descs = np.vstack((next_descs, desc))
                next_features.append(point)

##            print "testing",os.path.basename(next_img), next_descs.shape,
##            print "against",os.path.basename(base_img), base_descs.shape

##            print next_descs, type(next_descs), next_descs.shape, type(next_descs[0][0])
##            print base_descs, type(base_descs), base_descs.shape, type(base_descs[0][0])

            matches = matcher.knnMatch(next_descs, trainDescriptors=base_descs, k=2)

            #print "\t Match Count: ", len(matches)

            matches_subset = filter_matches(matches)

            #print "\t Filtered Match Count: ", len(matches_subset)

            distance = imageDistance(matches_subset)

            #print "\t Distance from Key Image: ", distance

            averagePointDistance = distance/float(len(matches_subset))

            #print "\t Average Distance: ", averagePointDistance

            kp1 = []
            kp2 = []

            for match in matches_subset:
                kp1.append(base_features[match.trainIdx])
                kp2.append(next_features[match.queryIdx])

            # Rigid Transform
##            p1 = np.array([k.pt for k in kp1]).astype(np.int)
##            p2 = np.array([k.pt for k in kp2]).astype(np.int)
##            #print len(p1), len(p2)
##            p1.shape = (1, len(p1), 2)
##            p2.shape = (1, len(p2), 2)
##            
##            H2d = cv2.estimateRigidTransform(p1, p2, False)
##            #print H2d
##            H = None
##            if H2d != None:
##                H = np.concatenate((H2d, [[0, 0, 1]]))
##
##            inlierRatio = 1.0

            p1 = np.array([k.pt for k in kp1])
            p2 = np.array([k.pt for k in kp2])

            H, status = cv2.findHomography(p1, p2, cv2.RANSAC, 5.0)

            inlierRatio = float(np.sum(status)) / float(len(status))

            # if ( closestImage == None or averagePointDistance < closestImage['dist'] ):
            if ( closestImage == None or inlierRatio > closestImage['inliers'] ):
                closestImage = {}
                closestImage['h'] = H
                closestImage['inliers'] = inlierRatio
                closestImage['dist'] = averagePointDistance
                closestImage['path'] = next_img
##                closestImage['rgb'] = next_img_rgb
##                closestImage['img'] = next_img
                closestImage['feat'] = next_features
                closestImage['desc'] = next_descs
                closestImage['match'] = matches_subset

##    print "Closest Image for", os.path.basename(base_img)+":",os.path.basename(closestImage['path'])
##    print "Closest Image Ratio: ", closestImage['inliers']

    sys.stdout.write(".")
    sys.stdout.flush()


    if closestImage != None:
        #print base_img, closestImage['path']
        saveWarpedImage(base_img, closestImage['path'], closestImage['h'])
        
        return (base_img, closestImage['h'], closestImage['inliers'])
    else:
        return None

def mp_match(files, featuredict, keyframe, nprocs):
    
    def worker(files, featuredict, keyframe, out_q):
        """ The worker function, invoked in a process. 'files' is a
            list of input files, 'featuredict' is a dict of
            calculated SIFT features by filename. The results are
            placed in a dictionary that's pushed to a queue.
        """
        outdict = {}

        for f in files:
            if f != keyframe:
                outdict[f] = calc_matches(keyframe, {keyframe:featuredict[keyframe], f:featuredict[f]})
            #outdict[f] = calc_matches(f, featuredict)
        out_q.put(outdict)

    # Each process will get 'chunksize' nums and a queue to put his out
    # dict into
    out_q = Queue()
    chunksize = int(math.ceil(len(files) / float(nprocs)))
    procs = []

    for i in range(nprocs):
        p = multiprocessing.Process(
                target=worker,
                args=(files[chunksize * i:chunksize * (i + 1)],
                      featuredict, keyframe, out_q))
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
    global featurepath, warpedpath

    # Define command line argument interface
    parser = argparse.ArgumentParser(description='align a folder full of gantry-acquired lightfield images')
    parser.add_argument('inpath', help='path to input images')
    parser.add_argument('featurepath', help='path to output feature files')
    parser.add_argument('warpedpath', help='path to warped output image files')
    parser.add_argument('keyframe', help='central image to align others with')
    
    args = parser.parse_args()

    dir_name = args.inpath
    featurepath = args.featurepath
    warpedpath = args.warpedpath
    keyframe = args.keyframe
    
    if not os.path.exists(featurepath):
        os.makedirs(featurepath)
    if not os.path.exists(warpedpath):
        os.makedirs(warpedpath)
    
    #dir_name = sys.argv[1]
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

    ##    dir_list = filter(lambda x: x != key_frame, dir_list)

    #print dir_list
    #features = mp_features(dir_list, 8)

    print len(dir_list), "files"

    to_process = []
    to_load =[]
    for next_img in dir_list:
        outf = os.path.join(featurepath, os.path.basename(next_img)+".pkl")
        if not os.path.exists(outf):
            to_process.append(next_img)
        else:
            to_load.append((outf, next_img))
            

    feat_descs = {}
    base_descs = np.zeros(shape = (0, 128))


    print len(to_process), "files without feature data"            

    if to_process > 0:
        # calculate image features
        features = mp_features(to_process, 2) #8)

        for next_img, next_feats in sorted(features.iteritems()):
            feat_descs[next_img] = next_feats
        
    if to_load > 0:
        # read features from disk
        for feat_file, img_file in to_load:
            print "loading features for", os.path.basename(img_file),
            infile = open(feat_file, 'rb') 
            base_descs = pickle.load(infile)
            feat_descs[img_file] = base_descs
            print len(base_descs)

    print "Matching closest images:"
    matches = mp_match(dir_list, feat_descs, keyframe, 8)

    for match_file, (in_file, homography, inliers) in sorted(matches.iteritems()):
        print "Closest Image for", os.path.basename(in_file)+":",os.path.basename(match_file ), inliers#homography

        print "Writing enlarged keyframe"
        print "homography:", homography
        
        key_frame_rgb = cv2.imread(keyframe)

        pad_lr = int(key_frame_rgb.shape[1] * 0.25)
        pad_tb = int(key_frame_rgb.shape[0] * 0.25)
    
        enlarged = cv2.copyMakeBorder(key_frame_rgb, pad_tb, pad_tb, pad_lr, pad_lr,
                                      cv2.BORDER_CONSTANT, value=(0,0,0,0))

        fname, ext = os.path.splitext(os.path.basename(keyframe))
        warp_file = os.path.join(warpedpath, fname+"_warp"+ext)
        cv2.imwrite(warp_file, enlarged)
