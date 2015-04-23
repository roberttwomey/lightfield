n = NetAddr("localhost", 12345)

// change the xRange of sampled subimages (xsubimages)
// args: numSubImages, constrainByXStart (0/1)
n.sendMsg("/lf/xRange", 15, 1) // 1: constrained by the edge of the frame
n.sendMsg("/lf/xRange", 15, 0) // 0: will move the xstart to achieve the range

n.sendMsg("/lf/yRange", 6, 1)
n.sendMsg("/lf/yRange", 12, 0)

// move the starting index of x/y subimgae (xstart)
// args: start index, constrain by number of subimages (0/1)
n.sendMsg("/lf/xStart", 13, 1) // 1: constrained by xsubimages and the edge of the frame
n.sendMsg("/lf/xStart", 13, 0) // 0: will shrink xsubimages to achieve the xstart

n.sendMsg("/lf/yStart", 5, 1)
n.sendMsg("/lf/yStart", 5, 0)

// change the "focal distance", 0 to 1, as rescaled by the ofApp
n.sendMsg("/lf/focus", 1.0.rand.postln;);

// random walking...

(
r !? {r.stop};
r = Routine.run({
	var hz = 15, foc, focStepMax = 0.1;
	foc = 1.0.rand;
	inf.do{
		foc = foc + rrand(focStepMax.half.neg, focStepMax.half);
		n.sendMsg("/lf/focus", foc.fold(0,1.0).postln;);
		hz.reciprocal.wait;
	}
})
)
r.stop


