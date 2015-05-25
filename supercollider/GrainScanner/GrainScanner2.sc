GrainScanner2 {
	classvar <grnSynthDef, <>replyIDCnt = 0;

	// copyArgs
	var <outbus, bufferOrPath;
	var server, <scanners, <sf, <buffers, <grnGroup, <synths, <bufDur, <view, <bufferPath;
	var <grnDurSpec, <grnRateSpec, <grnRandSpec, <grnDispSpec, <distFrmCenSpec, <clusterSpreadSpec, <azSpec, <xformAmtSpec, <ampSpec;
	var <>dataDir;
	var <spreadSpec, <panSpec;
	var <curCluster, <numFramesInClusters, <numClusters, <clusterFramesByDist, <invalidClusters, setClusterCnt = 0;

	*new { |outbus=0, bufferOrPath|
		^super.newCopyArgs( outbus, bufferOrPath ).init;
	}

	init {
		block { |break|
			server = Server.default;
			server.serverRunning.not.if{warn("Server isn't running, won't start grain scanner"); break.()};

			// init presets
			Archive.global[\grainScanner2] ?? { this.prInitArchive };

			// grain specs
			grnDurSpec = ControlSpec(0.01, 8, warp: 3, default: 1.3);
			grnRateSpec = ControlSpec(4.reciprocal, 70, warp: 3, default:10);
			grnRandSpec = ControlSpec(0, 1, warp: 4, default: 0.0);
			grnDispSpec = ControlSpec(0, 5, warp: 3, default: 0.03);
			ampSpec = ControlSpec(-90, 16, warp: 'db', default: 0.0);

			// cluster specs
			clusterSpreadSpec = ControlSpec(0, 0.5, warp: 3, default: 0.05);
			distFrmCenSpec = ControlSpec(0, 1, warp: 0, default: 0.1);

			// space specs
			panSpec = ControlSpec(-1, 1, warp: 0, default: 0.0);
			spreadSpec = ControlSpec(0, 1, warp: 'db', default: 0.25);

			fork{
				var cond = Condition();

				this.class.grnSynthDef ?? { this.loadGlobalSynthLib; 0.2.wait; };
				server.sync;

				this.setBuffer(bufferOrPath, cond);
				cond.wait;

				grnGroup = CtkGroup.play;
			}
		}
	}

	setBuffer{ |path, finishCond|
		fork{
			var cond = Condition();
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

			scanners.do(_.updateBuffer(buffers));

			finishCond !? {finishCond.test_(true).signal};
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

	addScanner {
		scanners = scanners.add( GrainScan2(this) );
	}

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

	getReplyID {
		// for requesting instance's OSC responder
		var id = this.class.replyIDCnt;
		this.class.replyIDCnt = id + 1;
		^id
	}

	gui { scanners.do(_.gui) }

	free {
		scanners.do(_.free);
		grnGroup.freeAll;
		buffers.do(_.free);
	}



	// --------------------------------------------------
	/* PRESETS */
	// --------------------------------------------------

	prInitArchive {
		^Archive.global.put(\grainScanner2, IdentityDictionary(know: true));
	}

	presets { ^Archive.global[\grainScanner2] }

	storePreset { |name, overwrite=false|
		block{ |break|
			(this.presets[name.asSymbol].notNil and: overwrite.not).if {
				warn("NOT CREATING PRESET. Preset already exists! Choose another name or explicitly overwrite with flag");
				break.()
			};

			this.presets.put( name.asSymbol,
				IdentityDictionary(know: true).putPairs([
					\bufName, PathName(buffers[0].path).fileName,

					\params, IdentityDictionary(know: true).putPairs([
						\grnDur,		synths[0].grainDur,
						\grnRate,		synths[0].grainRate,
						\grnRand,		synths[0].grainRand,
						\grnDisp,		synths[0].grainDisp,
						\cluster,		synths[0].cluster,
						\clusterSpread,	synths[0].clusterSpread,
						\distFrmCen,	synths[0].distFrmCen,
					]);
				])
			);
		}
	}

	recallPreset { |name|
		var curbuffers, preset = this.presets[name.asSymbol];

		fork{
			block { |break|
				var
				preset	?? {Warn("Preset not found."); break.()};
				dataDir ?? {Error("Must set dataDir before recalling presets!"); break.()};
				// store to free later
				curbuffers = buffers;

				preset.bufName =
				// recall the buffer
				this.setBuffer(bufferOrPath, cond);

				// recall load the cluster data
				this.initClusterData();

				// recall the synth settings
				preset.keysValuesDo({ |k,v| this.perform((k++'_').asSymbol, v) });


				// free the old buffers
				(curbuffers.size > 0).if{curbuffers.do(_.free)};


			}
		}
	}

	loadGlobalSynthLib {
		grnSynthDef = CtkSynthDef(\grainScanner2, {
			arg outbus = 0, grainRate = 2, grainDur=1.25, grainRand = 0, grainDisp = 0,
			cluster = 0, clusterSpread = 0.1, distFrmCen = 0, // bookkeeping args
			buffer, bufnum, pos = 0, replyID = -1,
			pan = 0, spread = 0.25,
			fadein = 2, fadeout = 2, amp = 1, gate = 1;

			var env, trig, out, grain_dens, amp_scale, disp, dispNorm;

			// envelope for fading output in and out - re-triggerable
			env = EnvGen.kr(Env([1,1,0],[fadein, fadeout], \sin, 1), gate, doneAction: 0);


			// gaussian trigger
			// grainRand = 0 regular at grainRate
			// grainRand = 1 random around grainRate
			trig = GaussTrig.ar(grainRate, grainRand);
			// trig = Impulse.ar(grainRate);

			dispNorm = grainDisp * 0.5 * BufDur.kr(bufnum).reciprocal;
			disp = TRand.ar(dispNorm.neg, dispNorm, trig);

			// calculate grain density
			grain_dens = grainRate * grainDur;
			amp_scale = grain_dens.reciprocal.sqrt.clip(0, 1);

			SendReply.ar(trig, '/pointer', [clusterSpread, distFrmCen, grainDur], replyID);

			out = GrainBufJ.ar(
				4, //1, // pan to multiple channels
				trig, grainDur, buffer, 1,
				(pos + disp).wrap(0,1),
				1, interp:1, grainAmp: amp_scale,
				pan: WhiteNoise.kr(spread, pan).wrap(-1,1) // random grain location in the panned channels (difusers)
			);
			out = out * env;
			// out = Pan2.ar(out);
			Out.ar(outbus, out * amp);
		});
	}
}

// a single scanner created by GrainScanner2
GrainScan2 {
	// copyArgs
	var <master, <curCluster, initGUI;
	var <replyID, <synths, <grnResponder, setClusterCnt = 0, numFramesInCluster, clusterFramesByDist, <view, <bufDur, <playing = false;
	*new { |aGrainScanner, clusterNum = 0, initGUI=true|
		^super.newCopyArgs(aGrainScanner, clusterNum, initGUI).init;
	}

	init {

		master.getReplyID;
		this.cluster_(curCluster); // set the cluster data
		bufDur = master.buffers[0].duration;
		this.buildResponder;

		synths = master.buffers.collect{ |buf, i|
			master.class.grnSynthDef.note(addAction: \head, target: master.grnGroup)
			// .outbus_(outbus+i)
			// .outbus_(panBus)
			.outbus_(master.outbus)
			.buffer_(buf).bufnum_(buf.bufnum)
			.grainRate_(master.grnRateSpec.default)
			.grainDur_(master.grnDurSpec.default)
			.grainRand_(master.grnRandSpec.default)
			.grainDisp_(master.grnDispSpec.default)
			.cluster_(curCluster)
			.clusterSpread_(0.1)
			.distFrmCen_(0)
			.pos_(0).replyID_(replyID)
			.gate_(1)
		};

		initGUI.if{ this.gui };
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
		fork{ synths[0].fadeout.wait; playing.not.if{synths.do(_.pause)} };
	}

	grnDur_ { |dur| synths.do(_.grainDur_(dur)); this.changed(\grnDur, dur); }

	grnRate_ {|rateHz| synths.do(_.grainRate_(rateHz)); this.changed(\grnRate, rateHz); }

	// gaussian trigger: 0 = regular at grainRate, 1 = random around grainRate
	grnRand_ {|distro| synths.do(_.grainRand_(distro)); this.changed(\grnRand, distro); }

	// position dispersion of the pointer, in seconds
	grnDisp_ {|dispSecs|
		synths.do(_.grainDisp_(dispSecs)); this.changed(\grnDisp, dispSecs); }

	amp_ {|amp| synths.do(_.amp_(amp)); this.changed(\amp, amp); }

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/* space controls */
	// az_ { |azRad| xformSynth.az_(azRad); this.changed(\az, azRad); }
	// xformAmt_ { |amtRad| xformSynth.xformAmt_(amtRad); this.changed(\xformAmt, amtRad); }
	pan_ { |az| // -1, 1
		synths.do(_.pan_(az)); this.changed(\pan, az);
	}
	spread_ { |amt| // 0>1
		synths.do(_.spread_(amt)); this.changed(\spread, amt);
	}

	cluster_ { |clusterIndex|

		// make sure the cluster has frames in it
		if( master.invalidClusters.includes(clusterIndex) and: (setClusterCnt < 20),
			{
				warn("chose a cluster with no frames, choosing another randomly");
				this.cluster_(master.numClusters.rand);
				setClusterCnt = setClusterCnt + 1;
			},{
				curCluster = clusterIndex;
				synths.do(_.cluster_(curCluster));
				numFramesInCluster = master.numFramesInClusters[curCluster];
				clusterFramesByDist = master.clusterFramesByDist;
				setClusterCnt = 0;
				this.changed(\cluster, curCluster);
			}
		);
	}

	updateBuffer { |buffers|

		if( buffers.size != synths.size, {
			var diff = (buffers.size - synths.size).abs;
			warn("number of buffers (channels) doesn't match the number of synths in this GrainSan2");
			if( diff > 0,
				{	// more buffer channels than synths
					synths.do{|synth, i| synth.buffer_(buffers[i]).bufnum_(buffers[i].bufnum) }
				},{	// more synths than buffer channels
					buffers.do{|buf, i| synths[i].buffer_(buf).bufnum_(buf.bufnum) };
					diff.abs.do{|i| synths.reverse[i].release};
				}
			);
		},{
			buffers.do{|buf, i| synths[i].buffer_(buf).bufnum_(buf.bufnum) };
		}
		);

		bufDur = buffers[0].duration;
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

					frame = this.chooseClusterFrame(clust_spread, shift);
					// postFrames.if{ frame.postln }; // debug

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

	// spread controls the probablitity distribution
	//	probability -> 'shift' value as spread -> 0
	//	practical vals to still cluster around 'shift' are ~0.5 max
	//	beyond that it's pretty much uniform random
	//	spread of 0.001 pretty much converges on 'shift'
	chooseClusterFrame { |spread = 0.1, shift = 0|
		var ptr, index;
		// choose random (gausian) index into the frames
		ptr = shift.gaussian(spread);
		ptr = ptr.fold(0,1); // keep in range at cost of slightly altering distro

		// translate this normalized pointer position
		// into an index into the clustered frames
		index = (numFramesInCluster - 1 * ptr).round;
		^clusterFramesByDist[curCluster][index]
	}

	free {
		grnResponder.free;
		synths.do(_.free);
		view !? { view.win.isClosed.not.if{view.win.close} };
	}

	gui {
		var test = view.isNil;
		test.not.if{ test = view.win.isClosed };
		test.if{ view = GrainScan2View(this) };
	}
}

GrainScan2View {
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
				.value_(scanner.master.grnDurSpec.default)
				.maxDecimals_(3)
			)
			.knob_(	Knob().step_(0.001)
				.action_({|knb|
					scanner.grnDur_(scanner.master.grnDurSpec.map(knb.value)) })
				.value_(scanner.master.grnDurSpec.unmap(scanner.master.grnDurSpec.default))
			),

			\grnRate, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.grnRate_(bx.value) })
				.value_(scanner.master.grnRateSpec.default)
				.maxDecimals_(3)
			)
			.knob_(	Knob().step_(0.001)
				.action_({|knb|
					scanner.grnRate_(scanner.master.grnRateSpec.map(knb.value)) })
				.value_(scanner.master.grnRateSpec.unmap(scanner.master.grnRateSpec.default))
			),

			\grnRand, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.grnRand_(bx.value) })
				.value_(scanner.master.grnRandSpec.default)
				.maxDecimals_(3)
			)
			.knob_(	Knob().step_(0.001)
				.action_({|knb|
					scanner.grnRand_(scanner.master.grnRandSpec.map(knb.value)) })
				.value_(scanner.master.grnRandSpec.unmap(scanner.master.grnRandSpec.default))
			),

			\grnDisp, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.grnDisp_(bx.value) })
				.value_(scanner.master.grnDispSpec.default)
				.maxDecimals_(3)
			)
			.knob_(	Knob().step_(0.001)
				.action_({|knb|
					scanner.grnDisp_(scanner.master.grnDispSpec.map(knb.value)) })
				.value_(scanner.master.grnDispSpec.unmap(scanner.master.grnDispSpec.default))
			),

			\amp, ()
			.slider_( Slider().orientation_('vertical')
				.action_({|sl|
					scanner.amp_(scanner.master.ampSpec.map(sl.value).dbamp)
				})
				.value_(scanner.master.ampSpec.unmap(scanner.master.ampSpec.default))
			)
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.amp_(bx.value.dbamp) })
				.value_(scanner.master.ampSpec.default)
			)
			.txt_( StaticText().string_("dB").align_(\center)
			),

			// cluster controls

			\clusterSpread, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.clusterSpread_(bx.value) })
				.value_(scanner.master.clusterSpreadSpec.default)
				.maxDecimals_(3)
			)
			.knob_(	Knob().step_(0.001)
				.action_({|knb|
					scanner.clusterSpread_(scanner.master.clusterSpreadSpec.map(knb.value)) })
				.value_(scanner.master.clusterSpreadSpec.unmap(scanner.master.clusterSpreadSpec.default))
			),

			\distFrmCen, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.distFrmCen_(bx.value) })
				.value_(scanner.master.distFrmCenSpec.default)
				.maxDecimals_(3)
			)
			.knob_(	Knob().step_(0.001)
				.action_({|knb|
					scanner.distFrmCen_(scanner.master.distFrmCenSpec.map(knb.value)) })
				.value_(scanner.master.distFrmCenSpec.unmap(scanner.master.distFrmCenSpec.default))
			),

			\newCluster, ()
			.numBox_( NumberBox()
				.action_({ |bx| scanner.cluster_(bx.value.asInt) }) )
			.txt_( StaticText().string_("Cluster") ),


			// space controls
			\pan, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.pan_(bx.value) })
				// .value_(scanner.azSpec.default)
				.value_(scanner.master.panSpec.default)
			)
			.knob_(	Knob().step_(0.001).centered_(true)
				.action_({|knb|
					// scanner.az_(scanner.azSpec.map(knb.value)) })
					scanner.pan_(scanner.master.panSpec.map(knb.value)) })
				// .value_(scanner.azSpec.unmap(scanner.azSpec.default))
				.value_(scanner.master.panSpec.unmap(scanner.master.panSpec.default))
			),

			\spread, ()
			.numBox_( NumberBox()
				.action_({ |bx|
					scanner.spread_(bx.value) })
				// .value_(scanner.xformAmtSpec.default)
				.value_(scanner.master.spreadSpec.default)
			)
			.knob_(	Knob().step_(0.001)
				.action_({|knb|
					// scanner.spread_(scanner.xformAmtSpec.map(knb.value)) })
					scanner.spread_(scanner.master.spreadSpec.map(knb.value)) })
				// .value_(scanner.xformAmtSpec.unmap(scanner.xformAmtSpec.default))
				.value_(scanner.master.spreadSpec.unmap(scanner.master.spreadSpec.default))
			),

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
		win = Window("a GrainScanner", Rect(200,200,450,100)).layout_(
			HLayout(
				VLayout(
					[controls[\amp].slider.maxWidth_(30), a: \center],
					controls[\amp].numBox.fixedWidth_(45),
					controls[\amp].txt.maxWidth_(45),
				),
				VLayout(
					HLayout(
						*[\grnDur, \grnRate, \grnRand, \grnDisp].collect({ |key|
							VLayout( StaticText().string_(key).align_(\center),
								HLayout( controls[key].numBox.maxWidth_(55), controls[key].knob.mode_(\vert) )
							)
						})
					),
					HLayout(
						VLayout(
							[controls[\newCluster].txt.align_(\left), a: \topLeft ],
							[controls[\newCluster].numBox.maxWidth_(55), a: \topLeft],
							nil
						),
						nil,
						*[\distFrmCen, \clusterSpread].collect({ |key|
							VLayout( StaticText().string_(key).align_(\center),
								HLayout( controls[key].numBox.maxWidth_(55), controls[key].knob.mode_(\vert) )
							)
						})
					),
					HLayout(
						nil, nil,
						*[\pan, \spread].collect({ |key|
							VLayout( StaticText().string_(key).align_(\center),
								HLayout( controls[key].numBox.maxWidth_(55), controls[key].knob.mode_(\vert) )
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
		)
		.onClose_({scanner.removeDependant( this );})
		.front;
	}

	update {
		| who, what ... args |
		var val = args[0];

		if( who == scanner, {
			switch ( what,

				\grnDur, {  var ctl = controls.grnDur;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.master.grnDurSpec.unmap( val ));
				},
				\grnRate, { var ctl = controls.grnRate;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.master.grnRateSpec.unmap( val ));
				},
				\grnRand, {  var ctl = controls.grnRand;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.master.grnRandSpec.unmap( val ));
				},
				\grnDisp, {  var ctl = controls.grnDisp;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.master.grnDispSpec.unmap( val ));
				},
				\amp, {  var ctl = controls.amp;
					ctl.numBox.value_( val.ampdb );
					ctl.slider.value_(scanner.master.ampSpec.unmap( val.ampdb ));
				},

				\distFrmCen, {  var ctl = controls.distFrmCen;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.master.distFrmCenSpec.unmap( val ));
				},
				\clusterSpread, { var ctl = controls.clusterSpread;
					ctl.numBox.value_( val );
					ctl.knob.value_(scanner.master.clusterSpreadSpec.unmap( val ));
				},
				\pan, { var ctl = controls.pan;
					ctl.numBox.value_( val );
					// ctl.knob.value_(scanner.azSpec.unmap( val ));
					ctl.knob.value_(scanner.master.panSpec.unmap( val ));
				},
				\spread, { var ctl = controls.spread;
					ctl.numBox.value_( val );
					// ctl.knob.value_(scanner.xformAmtSpec.unmap( val ));
					ctl.knob.value_(scanner.master.spreadSpec.unmap( val ));
				},
				\cluster, {
					controls[\newCluster].numBox.value_( val );
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