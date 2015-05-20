(
// x = 500.collect({0.5.gaussian(0.5)})
// x = 500.collect({1.cauchy(0.1)})
// x = 500.collect({0.5.logistic(1)})
// x = 500.collect({0.0.logistic(0.0)});
x = 500.collect({0.0.logistic(0.1)});
// x = 500.collect({0.1.pareto(0.1)})

postf("[%,%]\n", x.minItem, x.maxItem);
postf("% out of bounds\n", x.select({|val| ((val > 1) or: (val < 0)) }).size);
x.plot(discrete: true, minval: -0.5, maxval: 1.5);
)

(
x = [0.1, 0.5, 1.0].collect{ |prob|
	var data = 500.collect({
		// 0.001.weibull(1, prob)
		0.betarand(1, prob)
	});

	postf("prob: %, min: %, max: %, out of bounds: %\n",
		prob, data.minItem, data.maxItem, data.select({|val| ((val > 1) or: (val < 0)) }).size
	);
	data;
}
)

(
var spread = 0.18;
var shift = 0.7;
x = 500.collect({shift.gaussian(spread)});

// x =x.wrap(0,1);
x =x.fold(0,1); // keep in range at cost of slightly altering distro

postf("[%,%]\n", x.minItem, x.maxItem);
postf("% out of bounds\n", x.select({|val| ((val > 1) or: (val < 0)) }).size);
x.plot(discrete: true, minval: 0.0, maxval: 1.0);
)


// BETA
(
// x = [[0.1, 0.1], [0.5,0.5], [1.0, 1.0]].collect{ |prob|
x = [
	[0.01, 1],	// pull hard toward min
	[1, 0.01], 	// pull hard toward max
	[1.0, 1.0]	// uniform random
].collect{ |prob|
	var data = 500.collect({
		0.betarand(1, prob[0], prob[1])
	});

	postf("prob: %, min: %, max: %, oob: %\n",
		prob, data.minItem, data.maxItem, data.select({|val| ((val > 1) or: (val < 0)) }).size
	);
	data;
};
x.plot(discrete: true, minval: -0.5, maxval: 1.5)
)


x.plot(discrete: true, minval: -0.5, maxval: 1.5)

x.do(_.plot(discrete: true, minval: -0.5, maxval: 1.5))


// -----------------------------------------------
// integrated with scmir data
(
~load = { |path,auto_segment=true|
	var name,event=(),buffer,analysis,frames,beatdata,segments;
	var blind_segment_grain_size=0.1;
	name = PathName(path).fileNameWithoutExtension.split($ ).collect({|x|x}).join;
	event.name = name;
	"Loading Buffer".postln;
	buffer = Buffer.readChannel(s,path,channels:[0]);
	event.buf = buffer;
	if ("/sounds/*".pathMatch.find([PathName(path).pathOnly++PathName(path).fileNameWithoutExtension++".scmirZ"]).notNil) {
			"Found Analysis File...loading".postln;
			analysis = SCMIRAudioFile.newFromZ(path);
			analysis.load;
		} {
			"New file...beginning analysis".postln;
			analysis = SCMIRAudioFile(path, [[MFCC,4],[SpecCentroid],[Chromagram]]);
			analysis.extractFeatures();
			analysis.extractBeats();
			analysis.save;
			"File Saved".postln;
	};
	event.analysis = analysis;
	if (auto_segment) {
			//automatic segmentation
			event.beatdata = analysis.beatdata;
			analysis.gatherFeaturesBySegments(event.beatdata, true);
			n = analysis.numfeatures;
			event.frames = analysis.featuredata.clump(n);
			event.segments = nil;
	} {
			//blind segmentation
			event.segments = (0,blind_segment_grain_size..analysis.duration);
			event.analysis.gatherFeaturesBySegments(event.segments, true,1);
			analysis.numsegments;
			n = analysis.numfeatures;
			event.frames = analysis.featuredata.clump(n);
	"Processing Finished...analysis ready for use.".postln;
	event;}
};
)

// 1. auto-segment
~data = ~load.("/Users/admin/src/rover/data/AUDIO/discovery_cliffside_clip.WAV", true)

// clustering
//2. define vectors
(
~vectors = ~data.analysis.featuredata.clump( ~data.analysis.numfeatures );
~numClusters = 4;
k = KMeansMod(~numClusters);
~vectors.do{|vec, i| k.add(vec) };
)
// then... recenter the centroids
// k.update
k.reset.update // make sure centroids aren't too heavily weighted toward first entries

(
// each cluster's frames, ordered from nearest to furthest from centroid
~gatherFramesByDistance = {
	var framesByCluster;
	framesByCluster = ~numClusters.collect{List()};

	k.cenDistances.do{|dist, i|
		// Create an dict for each frame, associating it with its
		// distance from its assigned centroid, for later sorting
		// Put each of these frame dicts into its cluster group.
		framesByCluster[k.assignments[i]].add(
			().f_(~data.beatdata[i]).d_(dist)
		);
	};

	// sort by each frame's distance from the centroid, ordered nearest to furthest
	framesByCluster.collect{ |dataDictsArr|
		dataDictsArr.sortBy(\d).collect{|dict| dict.f }
	};
};

~framesByDistance =  ~gatherFramesByDistance.();

// spread controls the probablitity distribution
//	probability -> 'shift' value as spread -> 0
//	practical vals to still cluster around 'shift' are ~0.5 max
//	beyond that it's pretty much uniform random
//	spread of 0.001 pretty much converges on 'shift'
~chooseClusterFrame = { |clusterID, spread = 0.1, shift = 0|
	var ptr, index, clusterFrames;
	ptr = shift.gaussian(spread);
	ptr = ptr.fold(0,1); // keep in range at cost of slightly altering distro

	clusterFrames = ~framesByDistance[clusterID];

	// translate this normalized pointer position
	// into an index into the clustered frames
	index = (clusterFrames.size * ptr).round;
	clusterFrames[index]
};
)
// test
~chooseClusterFrame.(2, 0.1, 0.5)


// -----------------------------------------------
// testing synth grain request
~bufDur = ~data.analysis.duration;

(
d = CtkSynthDef(\grn_rquest, { arg g_rate = 2, grndur=0.75, start, end, t_reset, clust_spread = 0.01, shift = 0, t_posReset = 0, posRate = 1;
	// spread, shift, grndur
	SendReply.ar(Impulse.ar(g_rate), '/pointer', [clust_spread, shift, grndur]);
})
)
n = d.note.play

(
o = OSCdef(\pntr_response, { |msg, time, addr, recvPort|
	var clust_spread, shift, grndur, frame, start, end;

	#clust_spread, shift, grndur = msg[3..];
	// [clust_spread, shift, grndur].postln;

	frame = ~chooseClusterFrame.(2, clust_spread, shift).postln;
	n.posRate_(0); // pause the pointer (update to only do once)
	// TODO: consider the accuracy of this setting, looping manually throug the grain dur
	n.start = frame - (grndur * 0.5) / ~bufDur;
	n.t_posReset_(1); // reset the pointer to jump to the new startPos

	// end = start + grndur; // not needed with a paused pointer

}, '/pointer')
)
o.free

n.g_rate_(10)
n.clust_spread_(0.01)

n.shift_(0.1)

n.grndur_(0.9)


// multiple note version - benchmark
(
d = CtkSynthDef(\grn_rquest, { arg g_rate = 2, grndur=0.75, start, end, t_reset, clust_spread = 0.01, shift = 0, t_posReset = 0, posRate = 1;
	// spread, shift, grndur
	SendReply.ar(Impulse.ar(g_rate), '/pointer', [clust_spread, shift, grndur]);
});
e = CtkSynthDef(\the_grn, { arg g_rate = 2, grndur=0.75, start, end, t_reset, clust_spread = 0.01, shift = 0, t_posReset = 0, posRate = 1;
	// spread, shift, grndur
	// SendReply.ar(Impulse.ar(g_rate), '/pointer', [clust_spread, shift, grndur]);
});
)
n = d.note.play
z = 10.collect{e.note.play}

(
o = OSCdef(\pntr_response, { |msg, time, addr, recvPort|
	var clust_spread, shift, grndur, frame, start, end;

	#clust_spread, shift, grndur = msg[3..];
	// [clust_spread, shift, grndur].postln;

	frame = ~chooseClusterFrame.(2, clust_spread, shift).postln;

	z.do{|synth| synth.posRate_(0).start_(frame - (grndur * 0.5) / ~bufDur).t_posReset_(1)};

	// n.posRate_(0); // pause the pointer (update to only do once)
	// // TODO: consider the accuracy of this setting, looping manually throug the grain dur
	// n.start = frame - (grndur * 0.5) / ~bufDur;
	// n.t_posReset_(1); // reset the pointer to jump to the new startPos

	// end = start + grndur; // not needed with a paused pointer

}, '/pointer')
)
o.free

n.g_rate_(10)
n.clust_spread_(0.01)

n.free
z.do(_.free)