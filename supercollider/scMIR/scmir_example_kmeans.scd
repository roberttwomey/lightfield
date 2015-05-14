(
//-simple granular synth[substitute Impulse for GaussTrig if you don't have GaussTrig]


SynthDef(\grains,{|out,buf,pos,dur=0.5,rate=500,offset=1,gate=1,pch=1,amp=1|
	var son,trig;
	trig = GaussTrig.ar(rate,offset);
	son = TGrains.ar(2,trig,buf,pch,pos,dur)*LagUD.kr(amp,1,3);
	Out.ar(out,son*Env.asr.kr(2,gate))
}).add;

SynthDef(\grains2,{|out,buf,pos,dur=0.5,rate=5,offset=1,gate=1,pch=1,amp=1|
	var son,trig;
	trig = GaussTrig.ar(rate,offset);
	son = TGrains.ar(2,trig,buf,pch,pos,dur
	) * LagUD.kr(amp,1,3);
	Out.ar(out,son*Env.asr.kr(2,gate))
}).add;



~load = {|path,auto_segment=true|
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
}

)




//-run analysis function [path,auto-segment]

// auto-segment
~data = ~load.("/Users/admin/src/rover/data/AUDIO/discovery_cliffside_clip.WAV")
~data = ~load.("/Users/admin/Documents/Rover/recordings/scmir_test_files/STE-010_curbside1.wav", true)
~data = ~load.("/Users/admin/Documents/Rover/recordings/scmir_test_files/STE-010_curbside1.wav", true)
~data = ~load.("/Users/admin/Documents/Rover/recordings/scmir_test_files/STE-015_curbside2.wav", true)
~data = ~load.("/Users/admin/Documents/Rover/recordings/scmir_test_files/STE-023_walkinggull.wav", true)
~data = ~load.("/Users/admin/Documents/Rover/recordings/scmir_test_files/STE-004_44k_underpass.wav", true)

~data.beatdata // time stamps for segment starts
~data.analysis.numframes
~data.beatdata.size
~data.beatdata.differentiate.maxItem
~data.beatdata.differentiate.minItem
~data.beatdata.differentiate.mean
~data.analysis.numfeatures
~data.analysis.featuredata
~data.analysis.featuredata.size

~data.analysis.numfeatures * ~data.analysis.numframes) == ~data.analysis.featuredata.size

~data.analysis.plotSelfSimilarity(1,3,1)
~data.analysis.featureinfo
~data.analysis.analysispath
~data.analysis.sourcepath

// clustering
~vectors = ~data.analysis.featuredata.clump(~data.analysis.numfeatures)
~numClusters = 9;
k = KMeansMod(~numClusters)
~vectors.do{|vec, i| k.add(vec) }
k.update
k.reset.update // make sure centroids aren't too heavily weighted toward first entries
k.data
k.centroids.size
k.assignments
// what do our cluster densities look like?
~numClusters.do{|index| postf("cluster %: %\n", index, k.assignments.occurrencesOf(index)) }

k.assignments.size
~data.beatdata.size




/////////////////////////////////////////////////////
//  PLOTTING

(


var w,but,f,width,isPlaying={false}!x.size,osc,height;
var plot;
var cenDistsNorm, clusterDistMax;
~matchP = 5@5;

clusterDistMax = ~numClusters.collect{|clustNum|
	var max = 0;
	k.assignments.do{|ass, i|
		if(ass==clustNum){
			if(k.cenDistances[i] > max){max = k.cenDistances[i]}
		}
	};
	max
};
// normalize each distance to the centroid
cenDistsNorm = k.cenDistances.collect({|dist, i| dist / clusterDistMax[k.assignments[i]] });

plot = { |w,buf,frames,segments,beatdata|
	var radius={nil}!frames.size,points=List(),check_mouse,draw_tuio=true;
	var kdtree,grains;
	var map_patterns=List(),view;
	// var w_offset = 20;
	var w_offset = 0;
	var h_offset= 0;
	var w_stretch = 1.25,h_stretch = 1.35;
	// var w_stretch = 1,h_stretch = 1;
	var blob_size=8;
	var clusterRows = 2;
	var clusterColors = ~numClusters.collect{Color.rand};
	var clusterCols, xspacing, yspacing;
	var clusterRad; // = 150;

	///standard granular synth
	//grains = Synth(\grains,[\buf,buf,\dur,2,\rate,35,\pos,0,\amp,0,\offset,0.45]);

	//variation
	// grains = Synth(\grains2,[\buf,buf,\dur,0.2,\rate,5,\pos,0,\amp,0.5,\offset,0.9]);
	grains = Synth(\grains2,[\buf,buf,\dur,1.0,\rate,2,\pos,0,\amp,1.0,\offset,0.1]);

	width = w.bounds.width;//*0.75;
	height = w.bounds.height;//*0.75;

	clusterCols = (~numClusters / clusterRows).ceil;
	clusterCols.postln;
	xspacing = width / clusterCols;
	yspacing = height / clusterRows;
	clusterRad = min(xspacing, yspacing) / 2;

	k.data.do{|vector,index|
		var w_scale = w_stretch*width;
		var h_scale = h_stretch*height;
		var cluster, clusterCen, clusterNum, hyp, rot, xoff, yoff;

		radius[index] = blob_size;

		clusterNum = k.assignments[index];
		clusterCen = Point(
			xspacing * (clusterNum % clusterCols) + (xspacing/2),
			yspacing * (clusterNum / clusterCols).floor + (yspacing/2)
		);

		hyp = clusterRad * cenDistsNorm[index];
		rot = index / k.data.size * 2pi;
		xoff = hyp * cos(rot);
		yoff = hyp * sin(rot);


		points.add([

			Rect( clusterCen.x + xoff, clusterCen.y + yoff,
				// ((vector[0]+vector[5])*(vector[0]) * w_scale) + w_offset, // X left
				// ((vector[4]) * h_scale) + h_offset, // Y top
				radius[index], radius[index] // w,h
			).center;
		]);
	};


	view = UserView(w,w.view.bounds)
	.mouseMoveAction_({|v,x,y|check_mouse.(x,y)})
	.mouseDownAction_({|v,x,y|grains.set(\amp,1);check_mouse.(x,y)})
	.mouseUpAction_({grains.set(\amp,0)})
	.background_(Color.clear)
	.drawFunc_({
		var center;
		k.data.do{|vector,index|
			Pen.fillColor = clusterColors[k.assignments[index]]; //Color.new(*vector[0..3]);
			Pen.smoothing_(true);
			// center = Rect(
			// 	((vector[0]+vector[5])*(vector[0])*w_stretch*width)+w_offset,
			// 	((vector[4])*h_stretch*height)+h_offset,
			// radius[index],radius[index]).center;
			center = points[index][0];
			Pen.addArc(center,radius[index]*0.5,pi,2pi);
			Pen.fill;
		};
		// highlight a match
		Pen.fillColor = Color.red;
		Pen.addArc(~matchP,3,0,2pi);
		Pen.fill;

	});

	w.front;

	kdtree = KDTree(points.collect({ |array,i|
		array[0].asArray++i.asSymbol
	}),lastIsLabel:true);

	~kdtree = 	kdtree;

	check_mouse = {|x,y|
		var p = Point(x,y),index,nearest,dist,radiusMatchFactor = 2;

		nearest = kdtree.nearest([x,y])[0];
		index = nearest.label.asInteger;
		nearest = nearest.location.asPoint;
		dist = nearest.dist(p);
		postf("mouse: %  nearest: %\n", p, nearest);
		postf("dist: %  radius: %\n", dist, radius[index]);

		if (dist <= (radius[index]*radiusMatchFactor)) {

			~matchP = nearest;
			view.refresh;

			if (segments==nil) {
				//+/- rand controls 'fuzzy-ness' of grain synth
				// grains.set(\pos,beatdata[index+rrand(-5,5)])
				grains.set(\pos,beatdata[index].postln)
			} {
				// grains.set(\pos,segments[index+rrand(-5,5)])
				grains.set(\pos,segments[index].postln)
			}

		}
	};

	w.onClose_({grains.release});
};

w = Window("Scatter",Rect(250,250,1200,800)).front;
w.view.background_(Color.black);
plot.(w,~data.buf,~data.frames,~data.segments,~data.beatdata);

)




