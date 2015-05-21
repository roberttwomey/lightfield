GrainScanner2 {
	classvar <grnSynthDef, <>replyIDCnt = 0;

	// copyArgs
	var <outbus, bufferOrPath;
	var server, <sf, <buffers, <group, <synths, <bufDur, <view, <bufferPath;
	var <replyID;
	var <grnDurSpec, <grnRateSpec, <grnRandSpec, <pntrRateSpec, <pntrDispSpec;
	// cluster vars
	var setClusterCnt = 0, <curCluster, <numFramesInCluster;

	*new { |outbus=0, bufferOrPath|
		^super.newCopyArgs( outbus, bufferOrPath ).init;
	}

	init {
		server = Server.default;

		// for this instance's OSC responder
		replyID = this.class.replyIDCnt;
		this.class.replyIDCnt = replyID + 1;

		this.buildResponder;

		grnDurSpec = ControlSpec(0.01, 8, warp: 3, step: 0.01, default: 1.3);
		grnRateSpec = ControlSpec(4.reciprocal, 70, warp: 3, step:0.01, default:10);
		grnRandSpec = ControlSpec(0, 1, warp: 4, step: 0.01, default: 0.0);
		pntrRateSpec = ControlSpec(0.05, 3, warp: 0, step: 0.01, default: 1);
		pntrDispSpec = ControlSpec(0, 5, warp: 3, step: 0.01, default: 1.5);

		fork{
			var cond = Condition();

			this.class.grnSynthDef ?? { this.loadSynthLib; 0.2.wait; };
			server.sync;

			case
			{ bufferOrPath.isKindOf(String) }{
				bufferPath = bufferOrPath;
				this.prepareBuffers(cond);
				cond.wait;
			}
			// this assumes mutiple channels of mono buffers from the same file path
			{ bufferOrPath.isKindOf(Array) }{
				var test;
				test = bufferOrPath.collect({|elem| elem.isKindOf(Buffer)}).includes(false);
				test.if{ "one or more elements in the array provided is not a buffer".error };
				buffers = bufferOrPath;
				bufferPath = buffers[0].path;
			}
			{ bufferOrPath.isKindOf(Buffer) }{
				case
				// use the mono buffer
				{ bufferOrPath.numChannels == 1 }{
					"using mono buffer provided".postln;
					bufferPath = bufferOrPath.path;
					buffers = [bufferOrPath];
				}
				// split into mono buffers
				{ bufferOrPath.numChannels > 1 }{
					"loading buffer anew as single channel buffers".postln;
					bufferPath = bufferOrPath.path;
					this.prepareBuffers(cond);
					cond.wait;
				}
			};

			bufDur = buffers[0].duration;

			group = CtkGroup.play;
			server.sync;

			this.initSynths;
		}
	}

	prepareBuffers { |finishCond|

		block { |break|
			// check the soundfile is valid and get it's metadata
			sf = SoundFile.new;
			{sf.openRead(bufferPath)}.try({
				"Soundfile could not be opened".warn;
				finishCond.test_(true).signal;
				break.()
			});
			sf.close;

			// load the buffers
			fork {
				// one condition for each channel loaded into a Buffer
				var bufLoadConds = [];
				buffers = sf.numChannels.collect{|i|
					var myCond = Condition();
					bufLoadConds = bufLoadConds.add(myCond);
					Buffer.readChannel(
						server, bufferPath,
						channels: i, action: {myCond.test_(true).signal} );
				};
				bufLoadConds.do(_.wait); // wait for each channel to load
				"grain scanner buffer(s) loaded".postln;
				finishCond.test_(true).signal;
			}
		}
	}

	initSynths {
		synths = buffers.collect{ |buf, i|
			grnSynthDef.note(target: group)
			.buffer_(buf).bufnum_(buf.bufnum).out_bus_(outbus+i)
			.grainRate_(2).grainDur_(1.3)
			.clusterSpread_(0.1), distFrmCen = 0, buffer, pos = 0, replyID = -1
		}
	}

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/* cluster controls */
	// see also .chooseClusterFrame, which is called by the responder

	// spread: 0 > ~0.5
	// 0 no random spread from distFrmCen point
	// ~0.5 effectively random distribution across the cluster
	clusterSpread_ { |spread| synths.do(_.clusterSpread_(spread)) }
	// dist: 0 > 1
	// 0 center of the centroid
	// 1 furthest distance from centroid in the cluster
	distFrmCen_ { |dist| synths.do(_.distFrmCen_(spread)) }

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/* grain controls */

	play { |fadeInTime|
		fadeInTime !? {synths.do(_.fadein_(fadeInTime))};
		"playing".postln;
		synths.do({|synth| synth.isPlaying.not.if({synth.play},{synth.gate_(1)}) });
	}

	release { |fadeOutTime|
		fadeOutTime !? { synths.do(_.fadeout_(fadeOutTime)) };
		synths.do({|synth|
			synth.isPlaying.not.if({"synth isn't playing".warn},{synth.gate_(0)}) });
	}

	grnDur_ {|dur| synths.do(_.grainDur_(dur)); this.changed(\grnDur, dur); }

	grnRate_ {|rateHz| synths.do(_.grainRate_(rateHz)); this.changed(\grnRate, rateHz); }

	// gaussian trigger: 0 = regular at grainRate, 1 = random around grainRate
	grnRand_ {|distro| synths.do(_.grainRand_(distro)); this.changed(\grnRand, distro); }

	// position dispersion of the pointer, in seconds
	pntrDisp_ {|dispSecs| synths.do(_.posDisp_(dispSecs/bufDur)); this.changed(\pntrDisp, dispSecs); }
	// speed of the grain position pointer in the buffer, 1 is realtime, 0.5 half-speed, etc
	pntrRate_ {|rateScale| synths.do(_.posRate_(rateScale)); this.changed(\pntrRate, rateScale); }




	// mirFrames: eg. ~data.beatdata
	initClusterData { |kMeansData, mirFrames|
		var framesByCluster;

		numClusters = kMeansData.k;
		numFramesInClusters = numClusters.collect{ |i| kMeansData.assignments.occurrencesOf(i) };
		// keep track of clusters without frames to catch later
		invalidClusters = List();
		numFramesInClusters.do{ |frmcnt, i| if(frmcnt == 0, { invalidClusters.add(i) }) };

		framesByCluster = numClusters.collect{List()};

		kMeansData.cenDistances.do{|dist, i|
			// Create an dict for each frame, associating it with its
			// distance from its assigned centroid, for later sorting
			// Put each of these frame dicts into its cluster group.
			framesByCluster[k.assignments[i]].add(
				().f_(mirFrames[i]).d_(dist)
			);
		};

		// sort by each frame's distance from the centroid, ordered nearest to furthest
		clusterFramesByDist = framesByCluster.collect{ |dataDictsArr|
			dataDictsArr.sortBy(\d).collect{|dict| dict.f }
		};
	}

	// spread controls the probablitity distribution
	//	probability -> 'shift' value as spread -> 0
	//	practical vals to still cluster around 'shift' are ~0.5 max
	//	beyond that it's pretty much uniform random
	//	spread of 0.001 pretty much converges on 'shift'
	chooseClusterFrame { |clusterID, spread = 0.1, shift = 0|
		var ptr, index;
		// choose random (gausian) index into the frames
		ptr = shift.gaussian(spread);
		ptr = ptr.fold(0,1); // keep in range at cost of slightly altering distro

		// translate this normalized pointer position
		// into an index into the clustered frames
		index = (numFramesInCluster - 1 * ptr).round;
		^clusterFramesByDist[clusterID][index]
	}

	setCluster { |clusterIndex|

		// make sure the cluster has frames in it
		if( invalidClusters.includes(clusterIndex) and: (setClusterCnt < 20),
			{
				warn("chose a cluster with no frames, choosing another randomly");
				this.setCluster(numClusters.rand);
				setClusterCnt = setClusterCnt + 1;
			},{
				curCluster = clusterIndex;
				numFramesInCluster = numFramesInClusters[curCluster];
				setClusterCnt = 0;
			}
		);
	}


	gui { view = GrainScanner2View(this); }


	free {
		group.freeAll;
		buffers.do(_.free);
		grnResponder.free;
	}

	buildResponder {

		grnResponder !? {grnResponder.free};

		grnResponder = OSCFunc({ |msg, time, addr, recvPort|
			var clust_spread, shift, grndur, frame, start, end;

			var node;
			node = msg[1];
			synths.do{ |synth|
				// make sure to respond only to the synth that sent the message
				if( synth.node == node, {

					#clust_spread, shift, grndur = msg[3..];

					frame = this.chooseClusterFrame(this.curCluster, clust_spread, shift).postln;

					// center the grain around the frame location
					synth.pos_(frame - (grndur * 0.5) / bufDur);
				})
			};
		},
		'/pointer',
		Server.default.addr,
		argTemplate: [nil, this.replyID] // respond only to this instance's synths by replyID
		);

	}

	loadSynthLib {
		grnSynthDef = CtkSynthDef(\grainScanner2, {
			arg grainRate = 2, grainDur=1.25, clusterSpread = 0.1, distFrmCen = 0, buffer, pos = 0, replyID = -1;
			var trig, out, grain_dens, amp_scale;

			// TODO: update with gausstrig
			trig = Impulse.ar(grainRate);

			// calculate grain density
			grain_dens = grainRate * grainDur;
			amp_scale = grain_dens.reciprocal.sqrt.clip(0, 1);

			// spread, distFrmCen, grainDur
			SendReply.ar(trig, '/pointer', [clusterSpread, distFrmCen, grainDur], replyID);
			out = GrainBufJ.ar(1, trig, grainDur, buffer, 1 , pos, 1, interp:1, grainAmp: amp_scale);
			Out.ar(0, Pan2.ar(out));
		})
	}
}

GrainScanner2View {
	// copyArgs
	var scanner;
	var <win, <controls;

	*new {|aGrainScanner|
		^super.newCopyArgs( aGrainScanner ).init;
	}

	init {
		scanner.addDependant( this );
		controls = IdentityDictionary(know: true);
		this.buildControls;
		this.makeWin;
	}

	buildControls {

		controls.putPairs([
			\grnDur, ()
			.numBox_( NumberBox()
				.action_({ |bx|scanner.grnDur_(bx.value) })
				.value_(scanner.grnDurSpec.default)
			)
			.knob_(	Knob()
				.action_({|knb|
					scanner.grnDur_(scanner.grnDurSpec.map(knb.value)) })
				.value_(scanner.grnDurSpec.unmap(scanner.grnDurSpec.default))
			),

			\grnRate, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.grnRate_(bx.value) })
				.value_(scanner.grnRateSpec.default)
			)
			.knob_(	Knob()
				.action_({|knb|
					scanner.grnRate_(scanner.grnRateSpec.map(knb.value)) })
				.value_(scanner.grnRateSpec.unmap(scanner.grnRateSpec.default))
			),

			\grnRand, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.grnRand_(bx.value) })
				.value_(scanner.grnRandSpec.default)
			)
			.knob_(	Knob()
				.action_({|knb|
					scanner.grnRand_(scanner.grnRandSpec.map(knb.value)) })
				.value_(scanner.grnRandSpec.unmap(scanner.grnRandSpec.default))
			),

			\pntrRate, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.pntrRate_(bx.value) })
				.value_(scanner.pntrRateSpec.default)
			)
			.knob_(	Knob()
				.action_({|knb|
					scanner.pntrRate_(scanner.pntrRateSpec.map(knb.value)) })
				.value_(scanner.pntrRateSpec.unmap(scanner.pntrRateSpec.default))
			),

			\pntrDisp, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.pntrDisp_(bx.value) })
				.value_(scanner.pntrDispSpec.default)
			)
			.slider_(	Slider()
				.action_({|sldr|
					scanner.pntrDisp_(scanner.pntrDispSpec.map(sldr.value)) })
				.value_(scanner.pntrDispSpec.unmap(scanner.pntrDispSpec.default))
			),

			\fadeIO, ()
			.button_(
				Button()
				.states_([["*", Color.black, Color.red], ["*", Color.black, Color.green]])
				.action_({
					|but| switch( but.value,
						0, {scanner.release},
						1, {scanner.play}
					);
				}).value_(0)
			)
			.txt_( StaticText().string_("Fade in/out") ),

			// reset the pointer moment loop
			\syncPntr, ()
			.button_( Button().states_([[""]]).action_({ |but|
				scanner.syncLoop }) )
			.txt_( StaticText().string_("Sync pointer") ),

			\newPos, ()
			.button_( Button().states_([[""]]).action_({ |but|
				scanner.scanRange(scanner.bufDur.rand, rrand(2.0, 6.0)) }) )
			.txt_( StaticText().string_("New moment") ),

		]);
	}

	makeWin {
		win = Window("a GrainScanner", Rect(200,200,100,100)).layout_(
			VLayout(
				HLayout(
					*[\grnDur, \grnRate, \grnRand, \pntrRate].collect({ |key|
						VLayout( StaticText().string_(key).align_(\center),
							HLayout( controls[key].numBox.fixedWidth_(35), controls[key].knob.mode_(\vert) )
						)
					})
				),

				HLayout(
					VLayout(
						[controls[\pntrDisp].slider.orientation_(\vertical).minHeight_(150), a: \left],
						[controls[\pntrDisp].numBox.fixedWidth_(35), a: \left],
					),
					VLayout( *[\newPos, \syncPntr, \fadeIO].collect({ |key|
						HLayout(
							[controls[key].button.fixedWidth_(35), a: \left],
							[controls[key].txt.align_(\left), a: \left ]
						)
					}) ++ [nil, [StaticText().string_("pntr Dispersion").align_(\left), a: \bottom]]
					), nil
				),
			)
		)
		.onClose_({scanner.addDependant( this );})
		.front;
	}

	update {
		| who, what ... args |

		if( who == scanner, {
			switch ( what,

				\grnDur, {
					controls.grnDur.numBox.value_(args[0]);
					controls.grnDur.knob.value_(scanner.grnDurSpec.unmap(args[0])); },
				\grnRate, {
					controls.grnRate.numBox.value_(args[0]);
					controls.grnRate.knob.value_(scanner.grnRateSpec.unmap(args[0])); },
				\grnRand, {
					controls.grnRand.numBox.value_(args[0]);
					controls.grnRand.knob.value_(scanner.grnRandSpec.unmap(args[0])); },
				\pntrRate, {
					controls.pntrRate.numBox.value_(args[0]);
					controls.pntrRate.knob.value_(scanner.pntrRateSpec.unmap(args[0])); },
				\pntrDisp, {
					controls.pntrDisp.numBox.value_(args[0]);
					controls.pntrDisp.slider.value_(scanner.pntrDispSpec.unmap(args[0])); },
			)
		});
	}
}

/* Usage
var p;
p = "/Users/admin/src/rover/data/AUDIO/discovery_cliffside_clip.WAV"
g = GrainScanner(0, p)
g.play
g.gui
g.scanRange(rand(g.bufDur), 1)
g.free

i = GrainScanner(0, g.buffers)
i.play
i.gui
i.scanRange(rand(g.bufDur), 1)

q = 4.collect{GrainScanner(0, g.buffers)}
q.do(_.gui)
q.do(_.free)

Need to incorporate multiple pointer locations based on clustered frames in stochastic granulation, with distance from centroid controlled by GuasTrig or something similar.

*/