(
~loadFromFile = { |path,auto_segment=true|
	var scmirZTestFile, data;

	"Loading SCMIR data".postln;

	scmirZTestFile = PathName(path).pathOnly++PathName(path).fileNameWithoutExtension++".scmirZ";

	if ( File.exists(scmirZTestFile))
	{
		"Found scMIR Analysis File...loading".postln;
		data = SCMIRAudioFile.newFromZ(scmirZTestFile);
		"SCMIR data loaded".postln;
		data;
	} {
		Error("No analysis found at this path");
		nil;
	};
}
)


// This method for performing the analysis if none exists already
(
~loadOrProcess = { |path,auto_segment=true|
	var name, event=(), buffer, analysis, frames, beatdata, segments;
	var blind_segment_grain_size=0.1, scmirZTestFile;

	name = PathName(path).fileNameWithoutExtension.split($ ).collect({|x|x}).join;
	event.name = name;
	"Loading Buffer".postln;
	buffer = Buffer.readChannel(s,path,channels:[0]);
	event.buf = buffer;

	scmirZTestFile = PathName(path).pathOnly++PathName(path).fileNameWithoutExtension++".scmirZ";

	if ( File.exists(scmirZTestFile))
	{
		"Found Analysis File...loading".postln;
		analysis = SCMIRAudioFile.newFromZ(scmirZTestFile);
		//analysis.load; // << newFromZ calls this already!!
	} {
		"New file...beginning analysis".postln;
		// analysis = SCMIRAudioFile(path, [[MFCC,4],[SpecCentroid],[Chromagram]]);
		analysis = SCMIRAudioFile(path, [[MFCC,4],[SpecCentroid],[Chromagram, 6], [FFTCrest]]);
		analysis.extractFeatures();
		analysis.extractBeats();
		analysis.save(scmirZTestFile);
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
		event; // return
	}
};

)

p = "/Users/admin/src/rover/data/AUDIO/discovery_cliffside_CLIP.WAV"

~mirPath = PathName(p).pathOnly ++ PathName(p).fileNameWithoutExtension++".scmirZ";
File.exists(~mirPath)


//-run analysis function [path,auto-segment]
// auto-segment
~data = ~loadOrProcess.(p, true)

// clustering
// define vectors
(
~vectors = ~data.analysis.featuredata.clump( ~data.analysis.numfeatures );
~numClusters = 5;
k = KMeansMod(~numClusters);
~vectors.do{|vec, i| k.add(vec) };
)
// then... make sure centroids aren't too heavily weighted
// toward first entriesrecenter the centroids
// k.update
fork{ k.reset.update; "done".postln }


// Pre-computing and saving this data in advance helps all this run in real-time!

~kMeansPath = PathName(p).pathOnly ++ PathName(p).fileNameWithoutExtension++"_KMEANS"++".scmirZ";
// k.save(~kMeansPath)

~recalledK = KMeansMod().load(~kMeansPath)

//--------------------------------------------------------------
// compare the original data with the data recalled from archive
(
(k.k == ~recalledK.k).postln;
[
	\data,
	\centroids,
	\assignments,
	\cenDistances
].do{|param|
	var orig, recld;
	orig = k.perform(param).round(0.0000001);
	recld = ~recalledK.perform(param).round(0.0000001);
	orig.do{|og, i|
		var diff;
		if(og != recld[i])
		{
			diff = (og - recld[i]).abs;
			if(diff.isKindOf(Array)){diff.sort.reverse};
			postf("% % Doesn't match!\ndiff:%\n",
				param, i, /*og, recld[i],*/ diff );
		}{
			// "ok".postln;
		}
	}
}
)
// note differences are very small, rounding errors or something when saving or loading the binary data




// --------------------------------
// GRAIN SCANNER
// --------------------------------
s.boot;
// p = "/Users/admin/src/rover/data/AUDIO/discovery_cliffside_CLIP.WAV"
// p = "/Users/admin/src/rover/data/AUDIO/sandwich_fridge_rover.wav"
// p = "/Users/admin/src/rover/data/AUDIO/EDITS/dark_trees_shoot_EDIT.WAV";
// p = "/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_capture_EDIT.WAV";
// p = "/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_capture2_EDIT.WAV";
// p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_cliffside_CLIP.WAV";

p = "/Users/admin/src/rover/data/AUDIO/EDITS/around_the_dining_room_morning_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/carkeek_seaside_train_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_yellow_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_cliffside_1_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/discovery_cliffside_2_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/garden_morning1_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/garden_morning2_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/night_central_dist_clear_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/night_porch_13min_EDIT.WAV";

p = "/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_capture_EDIT.WAV"

(
~data = ~loadOrProcess.(p, true);
"done".postln;
)
~data.beatdata


// clustering
// define vectors
(
~vectors = ~data.analysis.featuredata.clump( ~data.analysis.numfeatures );
~numClusters = 4;
k = KMeansMod(~numClusters);
~vectors.do{|vec, i| k.add(vec) };
)
// then... make sure centroids aren't too heavily weighted
// toward first entriesrecenter the centroids
// k.update
fork{ k.reset.update; "done".postln }
~numClusters.do{|index| postf("cluster %: %\n", index, k.assignments.occurrencesOf(index)) }


~kMeansPath = PathName(p).pathOnly ++ PathName(p).fileNameWithoutExtension++"_KMEANS"++".scmirZ";
// k.save(~kMeansPath)
~recalledK = KMeansMod().load(~kMeansPath)

// initialize a grain scanner
s.boot

g = GrainScanner2( 0, p )

// add as many scanners as are needed
g.addScanner(2)

g.prepareNewDataSet(p)

g.storePreset(\test1)
g.storePreset(\test2)

g.storePreset(\crow)
g.storePreset(\crow2)
g.presets[\test1]
g.presets[\test2].params.size

g.storePreset(\test3)

g.recallPreset(\test1)
g.recallPreset(\test2)
g.recallPreset(\test3)

g.removePreset()

// give it the cluser and "beat" data
// g.initClusterData( k, ~data.beatdata)
g.initClusterData( ~recalledK, ~data.beatdata )

g.addScanner
g.scanners[0].gui

g.cluster_( 0 )

g.gui
g.play


e = GrainScanner2( 0, g.buffers )
e.initClusterData( ~recalledK, ~data.beatdata )
e.cluster_( 1 )

e.gui


f = GrainScanner2( 0, g.buffers )
f.initClusterData( ~recalledK, ~data.beatdata )
f.cluster_( 2 )

f.gui


[g,e,f].do(_.free)

// INFO: check params
g.curCluster
g.numFramesInCluster	// in the current cluser
g.numClusters
g.numFramesInClusters	// in all of the clusers

g.clusterFramesByDist	// used internally to choose frames
g.clusterFramesByDist.do{|arr|arr.size.postln}
g.invalidClusters		// any clusters with 0 frames?

// g.play
g.gui


g.release
g.free


// GRAINSCANNER1
p = "/Users/admin/src/rover/data/AUDIO/EDITS/around_the_dining_room_morning_EDIT.WAV";
p = "/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_EDIT.WAV";

i = GrainScanner1( 3, p )

i.storePreset(\int_sparse)
i.storePreset(\int_sparse2)

i.presets[\int_sparse].bufName
i.presets[\int_sparse].params.do{|set| set.do(_.postln); "".postln}

i.recallPreset(\int_sparse)
i.recallPreset(\int_sparse2, 5)
i.recallPreset(\int_sparse, 5)

i.updatePreset

i.free(freeBufs: true)

~grns = 3.collect{ GrainScanner1(0, g.buffers) }
~grns.do(_.gui)


// set all params together
~grns.do(_.fluxRate_(0.4))
~grns.do(_.maxDisp_(2.1))

// so all instances can choose a scmir frame
(
~grns.do{|grn|
	grn.newMomentFunc = {
		// g.clusterFramesByDist[0..6].choose.choose.postln
		g.clusterFramesByDist.choose.choose.postln
	}
}
)

// How to note the soundfile used in the preset?

// mamnually grabbing presets from GrainScanner1's
Archive.global.put(\grainScanner1, IdentityDictionary(know: true))

Archive.global[\grainScanner1].put(

IdentityDictionary(know: true).putPairs([
\grainDur, scnr.grainDur
\grainRand, scnr.grainRand
\minDisp, scnr.minDisp
\maxDisp, scnr.maxDisp
\density, scnr.density
\fluxRate, scnr.fluxRate
\start, scnr.start
\end, scnr.end

	t_posReset

PathName(.buffer).filename


i = GrainScanner(0, g.buffers)
i.play
i.gui
// i.scanRange(rand(g.bufDur), 1)
i.scanRange(g.clusterFramesByDist.choose.choose.postln, rrand(1.5, 4))

i.free

j = GrainScanner(0, g.buffers)
j.play
j.gui
j.scanRange(rand(g.bufDur), 1)
j.scanRange(g.clusterFramesByDist.choose.choose.postln, rrand(1.5, 4))
j.free

// both instances from one cluster
(var cl;
cl = g.clusterFramesByDist[0..6].choose;
[i,j].do(_.scanRange(cl.choose.postln, rrand(2.5, 6)))
)

q = 4.collect{GrainScanner(0, g.buffers)}
q.do(_.gui)
q.do(_.free)





[i,j].do{|x|x.synths.do(_.minDisp_(2.5))}
[i,j].do{|x|x.synths.do(_.maxDisp_(2.5))}
[i,j].do{|x|x.synths.do(_.grainDur_(2.5))}
[i,j].do{|x|x.synths.do(_.density_(13))}
[i,j].do{|x|x.synths.do(_.fluxRate_(5.reciprocal))}



/* SCRATCH

// testing grain responder trigger mechanism

s.boot;
x = Synth(\default);
OSCFunc({ 'ended!'.postln }, '/n_end', s.addr, nil, [x.nodeID]).oneShot;
x.release(3);

(
SynthDef("help-SendTrig",{ |id = 343|
	//     SendTrig.kr(Dust.kr(3.0),333,[0.9, 1,2,3,4,5,7.777]);
	    SendReply.kr(Dust.kr(3.0),'/reply',[0.9, 1,2], id);
}).send(s);

// register to receive this message
o = OSCFunc({ arg msg, time;
		"replier1 ".post;    [time, msg].postln;

// },'/tr', s.addr);
},'/reply', s.addr, argTemplate: [nil,343]);

q = OSCFunc({ arg msg, time;
    [time, msg].postln;
	"replier2".postln;
// },'/tr', s.addr);
},'/reply', s.addr);

)

x = Synth("help-SendTrig");
y = Synth("help-SendTrig");

x.set('id', 454)
x.set('id', 343)

[x,y].do(_.free)

o.free;
q.free;

d= CtkSynthDef(\testID, { |test| SinOsc.kr(3) })
x = d.note.play
x.play
x.node
x.free

*/
