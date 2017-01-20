#!/usr/bin/env python
"""
Generate a grid of positions for lightfield hbot
rtwomey@uw.edu
"""

import numpy as np
import time
import sys
from math import *
from time import sleep

def main():

	outf = None
	writebuff = []
	
	# check arguments
	if len(sys.argv) == 9:
		outfname = sys.argv[1]
		x0 = float(sys.argv[2])
		y0 = float(sys.argv[3])
		width = float(sys.argv[4])
		height = float(sys.argv[5])
		xsteps = int(sys.argv[6])
		ysteps = int(sys.argv[7])
		pausetime = float(sys.argv[8])
	else:
		print """Usage: generate_grid.py outfile.txt x0 y0 width height xsteps ysteps pausetime"""
		sys.exit()
		
	# begin gcode writing to buffer

	xstep = width / xsteps
	ystep = height / ysteps

	writebuff.append("$H")

	for y in range(0, ysteps+1):
		for x in range(0, xsteps+1):

			if(y%2==0):
				xpos = round(x0 + (x * xstep), 3)
			else:
				xpos = round(x0 + width - (x * xstep), 3)
				
			ypos = y0 + (y * ystep)

			# writebuff.append("G0X{0}Y{1}".format(xpos, ypos))
			# writebuff.append("G4P{0}".format(pausetime))
			writebuff.append("G0X{0}Y{1}".format(xpos, ypos))
			writebuff.append("(SNAP)")



	# dump contents to file
	outf = open(outfname, "w")

	for item in writebuff:
		outf.write(item+"\n")

	outf.close()

if __name__ == "__main__":
	main()
	
