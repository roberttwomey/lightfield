// Assembling Presets for Rover v.1

/*

Generally, the instruments are divided into 2 categories

	1. Interiors
Interiors use 3 instances of GrainScan1, controlled as a group by GrainScanner1.
These instruments cycle through a window of time, granulating as they loop.  Because the
source files are stereo, and because there is an independent granulator on each buffer channel,
there is drift in the parameters between the files creating an echoic effect.  The pair of
granulators for each channel of the stereo file are positioned roughly opposite of one another
in a quad panning scene.  There are 3 opposing pairs of stereo granulators distributed around
the quad scene, each looping through a different position in the source file (based on the
scmir- clustered frame positions).

	2. Exteriors
Interiors use 3 instances of GrainScan2, controlled as a group by GrainScanner2.
These instruments are each granulating a region of a k-means cluster (which has been
determined by the vectors of scmir analysis). Each granulator (again stereo), pulls
from a region of the clustered frames which is either wide (across the whole cluster)
or narrow (around a specified normalized distance from the cluster's "center").  The
grains are panned in the quad scene with a random distribution within a "spread" region.

*/

/////////////////////////
/*  INTERIORS  */
/////////////////////////

/* source file */
p = "/Users/admin/src/rover/data/AUDIO/EDITS/around_the_dining_room_morning_EDIT.WAV";
// p = "/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_EDIT.WAV";

s.boot
/* GrainScanner1 with 3 GrainScan1's */
x = GrainScanner1( 3, p )

// see below for loading scmir frames for "moment" frame locations


x.storePreset(\int_chat1)
x.storePreset(\int_chat2)
x.storePreset(\int_chat3)
x.storePreset(\int_chat4)

x.storePreset(\int_swell1)
x.storePreset(\int_swell2)
x.storePreset(\int_swell3)
x.storePreset(\int_swell4)

x.storePreset(\int_event1)
x.storePreset(\int_event2)
x.storePreset(\int_event3)
x.storePreset(\int_event4)
x.storePreset(\int_event5)




x.recallPreset(\int_chat1, 5)
x.recallPreset(\int_event4, 5)


x.updatePreset

x.presets.keys


// careful!
// x.removePreset(\int_sparse)

x.free(freeBufs: true)


x.scanners.do{|scnr| scnr.synths.do(_.fadein_(0.5))}
x.scanners.do{|scnr| scnr.synths.do(_.fadeout_(0.5))}
x.scanners.do{|scnr| scnr.synths.do(_.ctllag_(0.05))}
x.scanners.do{|scnr| scnr.synths.do(_.ctllag_(0.05))}

// in order to use the scmir frames, use GrainScanner2's
// clusterFramesByDist method
g = GrainScanner2( 0, p )

(
x.scanners.do{|scnr|
	// function should return a frame pointer and a "moment" window size
	scnr.newMomentFunc = {
		var whichClust = 8.rand;
		postf("cluster: %\n", whichClust);
		// [g.bufDur.rand, rrand(2.5, 1)].postln
		[g.clusterFramesByDist[whichClust].choose, rrand(3.5, 8)].postln
		// [428.90496322703, rrand(3.5, 8)].postln
	}
}
)
g.free

/////////////////////////
/*  EXTERIORS  */
/////////////////////////


// TODO:
// Make preset gui with recall and update functionality

// OTHER:
// for eq control in the container
m = MasterEQ(4)
x = {Out.ar(0, PinkNoise.ar(0.5!4))}.play
x.free

// note global amp control on interiors for balancing with exteriors