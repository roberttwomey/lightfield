GrainScanner2 {
	classvar <grnSynthDef, <>replyIDCnt = 0;

	// copyArgs
	var <outbus, bufferOrPath;
	var server, <sf, <buffers, <group, <synths, <bufDur, <view, <bufferPath;
	var <grnResponder, <replyID;
	var <grnDurSpec, <grnRateSpec, <grnRandSpec, <pntrDispSpec, <distFrmCenSpec, <clusterSpreadSpec;
	var <>postFrames =false, <playing = false;
	// cluster vars
	var <curCluster, <numFramesInClusters, <numFramesInCluster, <numClusters, <clusterFramesByDist, <invalidClusters, setClusterCnt = 0;

	*new { |outbus=0, bufferOrPath|
		^super.newCopyArgs( outbus, bufferOrPath ).init;
	}

	init {
		server = Server.default;

		// for this instance's OSC responder
		replyID = this.class.replyIDCnt;
		this.class.replyIDCnt = replyID + 1;

		this.buildResponder;

		// grain specs
		grnDurSpec = ControlSpec(0.01, 8, warp: 3, default: 1.3);
		grnRateSpec = ControlSpec(4.reciprocal, 70, warp: 3, default:10);
		grnRandSpec = ControlSpec(0, 1, warp: 4, default: 0.0);
		pntrDispSpec = ControlSpec(0, 5, warp: 3, default: 1.5);

		// cluster specs
		clusterSpreadSpec = ControlSpec(0, 0.5, warp: 4, default: 0.01);
		distFrmCenSpec = ControlSpec(0, 1, warp: 0, default: 0.01);

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
			.outbus_(outbus+i).buffer_(buf)
			.grainRate_(grnRateSpec.default)
			.grainDur_(grnDurSpec.default)
			.clusterSpread_(0.1)
			.distFrmCen_(0)
			.pos_(0).replyID_(this.replyID)
			.gate_(1)
		}
	}

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/* cluster controls */
	// see also .chooseClusterFrame, which is called by the responder

	// spread: 0 > ~0.5
	// 0 no random spread from distFrmCen point
	// ~0.5 effectively random distribution across the cluster
	clusterSpread_ { |spread|
		synths.do(_.clusterSpread_(spread)); this.changed(\clusterSpread, spread) }
	// dist: 0 > 1
	// 0 center of the centroid
	// 1 furthest distance from centroid in the cluster
	distFrmCen_ { |dist|
	synths.do(_.distFrmCen_(dist)); this.changed(\distFrmCen, dist) }

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/* grain controls */

	play { |fadeInTime|
		fadeInTime !? {synths.do(_.fadein_(fadeInTime))};
		synths.do({|synth|
			synth.isPlaying.not.if(
				{synth.play},
				{synth.gate_(1); synth.run}
			);
		});
		playing = true;
	}

	release { |fadeOutTime|
		fadeOutTime !? { synths.do(_.fadeout_(fadeOutTime)) };
		synths.do({|synth|
			synth.isPlaying.not.if({
				"synth isn't playing, can't release".warn},{synth.gate_(0)}) });
		playing = false;
		// pause after fadetime
		fork{ synths[0].fadeTime.wait; playing.not.if{synths.do(_.pause)} };
	}

	grnDur_ { |dur| synths.do(_.grainDur_(dur)); this.changed(\grnDur, dur); }

	grnRate_ {|rateHz| synths.do(_.grainRate_(rateHz)); this.changed(\grnRate, rateHz); }

	// gaussian trigger: 0 = regular at grainRate, 1 = random around grainRate
	grnRand_ {|distro| synths.do(_.grainRand_(distro)); this.changed(\grnRand, distro); }

	// position dispersion of the pointer, in seconds
	pntrDisp_ {|dispSecs|
		synths.do(_.posDisp_(dispSecs/bufDur)); this.changed(\pntrDisp, dispSecs); }


	// mirFrames: eg. ~data.beatdata
	initClusterData { |aKMeansMod, mirFrames|
		var framesByCluster;

		numClusters = aKMeansMod.k;
		numFramesInClusters = numClusters.collect{ |i| aKMeansMod.assignments.occurrencesOf(i) };
		invalidClusters = List(); 	// keep track of clusters without frames to catch later
		numFramesInClusters.do{ |frmcnt, i| if(frmcnt == 0, { invalidClusters.add(i) }) };

		framesByCluster = numClusters.collect{List()};

		aKMeansMod.cenDistances.do{|dist, i|
			// Create an dict for each frame, associating it with its
			// distance from its assigned centroid, for later sorting
			// Put each of these frame dicts into its cluster group.
			framesByCluster[aKMeansMod.assignments[i]].add(
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

					frame = this.chooseClusterFrame(this.curCluster, clust_spread, shift);
					postFrames.if{ frame.postln }; // debug

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
			arg outbus=0, grainRate = 2, grainDur=1.25, clusterSpread = 0.1, distFrmCen = 0, buffer, pos = 0, replyID = -1, fadein = 2, fadeout = 2, gate =1, grainRand = 0, posDisp = 0;
			var env, trig, out, grain_dens, amp_scale;

			// envelope for fading output in and out - re-triggerable
			env = EnvGen.kr(Env([1,1,0],[fadein, fadeout], \sin, 1), gate, doneAction: 0);

			// TODO: update with gausstrig, grainRand
			trig = Impulse.ar(grainRate);

			// calculate grain density
			grain_dens = grainRate * grainDur;
			amp_scale = grain_dens.reciprocal.sqrt.clip(0, 1);

			// TODO: add posDisp to pos
			SendReply.ar(trig, '/pointer', [clusterSpread, distFrmCen, grainDur], replyID);
			out = GrainBufJ.ar(1, trig, grainDur, buffer, 1 , pos, 1, interp:1, grainAmp: amp_scale);
			out = out * env;
			Out.ar(outbus, Pan2.ar(out));
		})
	}
}

GrainScanner2View {
	// copyArgs
	var scanner;
	var <win, <controls;

	*new {|aGrainScanner2|
		^super.newCopyArgs( aGrainScanner2 ).init;
	}

	init {
		scanner.addDependant( this );
		controls = IdentityDictionary(know: true);
		this.buildControls;
		this.makeWin;
	}


	// TODO: make a class to handle grouping widgets (like EZ) that works with layouts
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

			\pntrDisp, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.pntrDisp_(bx.value) })
				.value_(scanner.pntrDispSpec.default)
			)
			.knob_(	Knob()
				.action_({|knb|
					scanner.pntrDisp_(scanner.pntrDispSpec.map(knb.value)) })
				.value_(scanner.pntrDispSpec.unmap(scanner.pntrDispSpec.default))
			),

			// cluster controls

			\clusterSpread, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.clusterSpread_(bx.value) })
				.value_(scanner.clusterSpreadSpec.default)
			)
			.knob_(	Knob()
				.action_({|knb|
					scanner.clusterSpread_(scanner.clusterSpreadSpec.map(knb.value)) })
				.value_(scanner.clusterSpreadSpec.unmap(scanner.clusterSpreadSpec.default))
			),

			\distFrmCen, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.distFrmCen_(bx.value) })
				.value_(scanner.distFrmCenSpec.default)
			)
			.knob_(	Knob()
				.action_({|knb|
					scanner.distFrmCen_(scanner.distFrmCenSpec.map(knb.value)) })
				.value_(scanner.distFrmCenSpec.unmap(scanner.distFrmCenSpec.default))
			),

			\newCluster, ()
			.numBox_( NumberBox()
				.action_({ |bx| scanner.setCluster(bx.value.asInt) }) )
			.txt_( StaticText().string_("New cluster") ),

			// play/release
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

		]);
	}

	makeWin {
		win = Window("a GrainScanner", Rect(200,200,100,100)).layout_(
			VLayout(
				HLayout(
					*[\grnDur, \grnRate, \grnRand, \pntrDisp].collect({ |key|
						VLayout( StaticText().string_(key).align_(\center),
							HLayout( controls[key].numBox.fixedWidth_(35), controls[key].knob.mode_(\vert) )
						)
					})
				),
				HLayout(
					VLayout(
						[controls[\newCluster].txt.align_(\left), a: \top ],
						[controls[\newCluster].numBox.fixedWidth_(35), a: \top],
						nil
					),
					nil,
					*[\distFrmCen, \clusterSpread].collect({ |key|
						VLayout( StaticText().string_(key).align_(\center),
							HLayout( controls[key].numBox.fixedWidth_(35), controls[key].knob.mode_(\vert) )
						)
					})
				),
				nil,
				HLayout(
					[controls[\fadeIO].button.fixedWidth_(35), a: \left],
					[controls[\fadeIO].txt.align_(\left), a: \left ],
					nil
				),
			)
		)
		.onClose_({scanner.addDependant( this );})
		.front;
	}

	update {
		| who, what ... args |
		var val = args[0];

		if( who == scanner, {
			switch ( what,

				\grnDur, {  var ctl = controls.grnDur;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.grnDurSpec.unmap( val ));
				},
				\grnRate, { var ctl = controls.grnRate;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.grnRateSpec.unmap( val ));
				},
				\grnRand, {  var ctl = controls.grnRand;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.grnRandSpec.unmap( val ));
				},
				\pntrDisp, {  var ctl = controls.pntrDisp;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.pntrDispSpec.unmap( val ));
				},
				\distFrmCen, {  var ctl = controls.distFrmCen;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.distFrmCenSpec.unmap( val ));
				},
				\clusterSpread, { var ctl = controls.clusterSpread;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.clusterSpreadSpec.unmap( val ));
				},
			)
		});
	}
}

/* Usage
var p;
p = "/Users/admin/src/rover/data/AUDIO/discovery_cliffside_clip.WAV"
g = GrainScanner2(0, p)
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

*/