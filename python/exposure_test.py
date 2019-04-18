import matplotlib
import matplotlib.pyplot as plt
import numpy as np

import cv2
# from skimage import data, img_as_float
# from skimage import exposure

img = cv2.imread("/Volumes/Work/Projects/lightfield/data/towers/original/image0200.jpg")

# img_adapteq = #exposure.equalize_adapthist(img, clip_limit=0.03)

# gray = cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)

# equ = cv2.equalizeHist(gray)    # Remember histogram equalization works only for grayscale images

# cv2.imshow('src',gray)

ycrcb = cv2.cvtColor(img,cv2.COLOR_BGR2YCR_CB)

channels = cv2.split(ycrcb)

channels[0] = cv2.equalizeHist(channels[0])

ycrcb = cv2.merge(channels);

equ = cv2.cvtColor(ycrcb, cv2.COLOR_YCR_CB2BGR);
        
cv2.imshow('equ',equ)
cv2.waitKey(0)
cv2.destroyAllWindows()