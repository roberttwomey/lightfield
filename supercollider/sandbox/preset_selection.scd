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
~eq = MasterEQ(4);

/* GrainScanner1 with 3 GrainScan1's */
x = GrainScanner1( 3, p )
x = GrainScanner1( 1, p )
x.presetGUI(3)
// see below for loading scmir frames for "moment" frame locations

// reverb
	// reverb control
x.sendToReverb( onsetTime: 25 )
x.sendToReverb( onsetTime: 10 )
x.sendToReverb( onsetTime: 5 )

x.verbOnsetCurve_(3)
(
x.verbSynths.do(_.maxAPDecay_(1.5));
x.verbSynths.do(_.maxDecayTime_(6.3));
x.verbSynths.do(_.minDampFreq_(3500));
x.verbSynths.do(_.amp_(-8.dbamp));
x.verbSynths.do(_.maxSclReflect_(23));
)
x.verbSynths.do(_.verbCutTail_(10))

x.verbSynths[0].maxDecayTime
x.verbSynths[0].maxAPDecay
x.verbSynths[0].minDampFreq

// ---------------
// STORE

x.storePreset(\int_chat1)
x.storePreset(\int_chat2)
x.storePreset(\int_chat3)
x.storePreset(\int_chat4)
x.storePreset(\int_chat5)

x.storePreset(\int_swell1)
x.storePreset(\int_swell2)
x.storePreset(\int_swell3)
x.storePreset(\int_swell4)
x.storePreset(\int_swell5)
x.storePreset(\int_swell6)

x.storePreset(\int_event1)
x.storePreset(\int_event2)
x.storePreset(\int_event3)
x.storePreset(\int_event4)
x.storePreset(\int_event5)
x.storePreset(\int_event6)


x.storePreset(\int_humm)
x.storePreset(\int_cycle)



// ---------------
// RECALL
x.recallPreset(\int_event6, 5)
x.recallPreset(\int_event4, 5)

// ---------------
// UPDATE
x.updatePreset

// ---------------
// BACKUP
x.backupPreset

// ---------------
// INVENTORY
x.listPresets

// careful!
// x.removePreset(\int_sparse)

x.free(freeBufs: true)


x.scanners.do{|scnr| scnr.synths.do(_.fadein_(0.5))}
x.scanners.do{|scnr| scnr.synths.do(_.fadeout_(0.5))}
x.scanners.do{|scnr| scnr.synths.do(_.ctllag_(0.05))}
x.scanners.do{|scnr| scnr.synths.do(_.ctllag_(0.05))}

// send to aux bus
x.scanners.do{|scnr| scnr.synths.do({ |synth, i | synth.outbus_(a.bus+i) }) };

// in order to use the scmir frames, use GrainScanner2's
// clusterFramesByDist method
g = GrainScanner2( 0, p )

(
x.scanners.do{|scnr|
	// function should return a frame pointer and a "moment" window size
	scnr.newMomentFunc = {
		var whichClust = 8.rand;
		postf("cluster: %\n", whichClust);
		// [g.bufDur.rand, rrand(22.5, 1)].postln;
		[g.clusterFramesByDist[whichClust].choose, rrand(3.5, 6.3)].postln
		// [5.0583129, rrand(3.5, 4)].postln
		// [435.30303620114, rrand(3.5, 8)].postln
	}
}
)
g.free




/////////////////////////
/*  EXTERIORS  */
/////////////////////////

p = "/Users/admin/src/rover/data/AUDIO/EDITS/carkeek_seaside_train_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_yellow_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_cliffside_1_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_cliffside_2_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/garden_morning1_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/garden_morning2_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/night_central_dist_clear_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/night_porch_13min_EDIT.WAV";

Archive.read("/Users/admin/src/rover/supercollider/preset_backups/GrainScanner_presets/archive.sctxar_BAK_150527_215832.sctxar")

/* for documentation, gather the 4 output channels to 2 */
~dec = FoaDecoderKernel.newUHJ(2048);
(
d = CtkSynthDef(\Quad2UHJ, { arg outbus = 0, inbus = 0, amp =1, hpf=75;
	var in, enc, dec, enc_mtx;
	in = In.ar(inbus, 4);
	enc_mtx = FoaEncoderMatrix.newDirections([30, -30, -135, 135].degrad, 0.6);
	enc = FoaEncode.ar(in, enc_mtx);
	dec = FoaDecode.ar(enc, ~dec);
	ReplaceOut.ar(outbus, HPF.ar(dec, hpf)*amp)
});
)
x = d.note(addAction: \tail).play
x.inbus_(2)
x.amp_(18.dbamp)
x.free
// initialize a grain scanner
s.boot
g = GrainScanner2(2, p )

3.do{|i|g.addScanner(i)} // add scanners
g.presetGUI(5)

g.scanners.do{|scnr| scnr.synths.do(_.fadein_(0.5))}
g.scanners.do{|scnr| scnr.synths.do(_.fadeout_(0.5))}
g.scanners.do{|scnr| scnr.synths.do(_.ctllag_(0.05))}
g.scanners.do{|scnr| scnr.synths.do(_.ctllag_(0.05))}


p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_cliffside_1_EDIT.WAV";
g.prepareNewDataSet(p)

g.storePreset(\cliff1_surr)
g.storePreset(\cliff1_surr2)
g.storePreset(\cliff1_stutt)
g.storePreset(\cliff1_stutt2)
g.storePreset(\cliff1_stutt3)


p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_yellow_EDIT.WAV";
g.prepareNewDataSet(p)

g.storePreset(\yellow_surr_crow)
g.storePreset(\yellow_surr2)
g.storePreset(\yellow_surr3)
g.storePreset(\yellow_surr4)
g.storePreset(\yellow_surr5)
g.storePreset(\yellow_surr6)

p = "/Users/admin/src/rover/data/AUDIO/EDITS/night_central_dist_clear_EDIT.WAV";
g.prepareNewDataSet(p)

g.storePreset(\night_surr_tone)
g.storePreset(\night_surr)
g.storePreset(\night_surr1)
g.storePreset(\night_surr2)

p = "/Users/admin/src/rover/data/AUDIO/EDITS/carkeek_seaside_train_EDIT.WAV";
g.prepareNewDataSet(p)

g.storePreset(\sea_surr)
g.storePreset(\sea_surr2)
g.storePreset(\sea_surr3)
g.storePreset(\sea_surr4)
g.storePreset(\sea_surr5)
g.storePreset(\sea_surr5)
g.storePreset(\sea_surr6)
g.storePreset(\sea_surr7)
g.storePreset(\sea_surr8)


p = "/Users/admin/src/rover/data/AUDIO/EDITS/garden_morning2_EDIT.WAV";
g.prepareNewDataSet(p)

g.storePreset(\garden_surr1)
g.storePreset(\garden_surr2)
g.storePreset(\garden_surr3)
g.storePreset(\garden_surr4)
g.storePreset(\garden_surr5)


p = "/Users/admin/src/rover/data/AUDIO/EDITS/night_porch_13min_EDIT.WAV";
g.prepareNewDataSet(p)

g.storePreset(\nightCD_surr)
g.storePreset(\nightCD_surr1)
g.storePreset(\nightCD_surr2)
g.storePreset(\nightCD_surr3)
g.storePreset(\nightCD_surr4)


// ---------------
// RECALL
g.recallPreset(\garden_surr3, 4)


g.backupPreset

// ---------------
// INVENTORY
g.listPresets

// careful!
// g.removePreset(\test1)

g.free




// TODO:
// Make preset gui with recall and update functionality

// OTHER:
// for eq control in the container
m = MasterEQ(4)
x = {Out.ar(0, PinkNoise.ar(0.5!4))}.play
x.free

// note global amp control on interiors for balancing with exteriors