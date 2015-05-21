GrainScanner {
	classvar <grnSynthDef;

	// copyArgs
	var <outbus, bufferOrPath;
	var server, <sf, <buffers, <group, <synths, <bufDur, <view, <bufferPath;
	var <grnDurSpec, <grnRateSpec, <grnRandSpec, <pntrRateSpec, <pntrDispSpec;

	*new { |outbus=0, bufferOrPath|
		^super.newCopyArgs( outbus, bufferOrPath ).init;
	}

	init {
		server = Server.default;

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
		synths = buffers.collect{|buf, i|
			grnSynthDef.note(target: group).buffer_(buf).bufnum_(buf.bufnum).outbus_(outbus+i).grainDur_(1.3)
		}
	}

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

	// TODO:
	// align to the moment in secs
	timeAlign { |secs| }

	// sync the synths' pointers by resetting to beginning of loop
	// optionally supply pointer rate so they stay sync'd
	syncLoop { |pntrRate|
		pntrRate !? { synths.do(_.posRate_(pntrRate)) };
		synths.do(_.t_posReset_(1));
	}

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	/* scan controls */


	// move to a new "moment" and loop over spanSec seconds
	// window centered at centerSec
	scanRange{ | centerSec, spanSec, syncBufs=true |
		var span, moment;

		span = spanSec / bufDur; // the span of time of the scanning window
		moment = centerSec / bufDur;

		synths.do({|me|
			me.start_(moment - span.half)
			.end_(moment + span.half)
		});
		// sync up the instances, by resetting to start position
		syncBufs.if{ synths.do(_.t_posReset_(1)) };
	}

	// // direct control over pointer location
	// setPointer { | distFromCentroid = 0, grainSize = 2 |
	// 	cluster
	// }


	gui { view = GrainScannerView(this); }


	free {
		group.freeAll;
		buffers.do(_.free)
	}


	loadSynthLib {
		grnSynthDef = CtkSynthDef(\grainScanner, {
			arg
			buffer, bufnum,
			outbus, 			// main out
			outbus_aux,		// outbus to reverb
			start=0, end=1,		// bounds of grain position in sound file
			grainRand = 0,		// gaussian trigger: 0 = regular at grainRate, 1 = random around grainRate
			grainRate = 10, grainDur = 0.04,
			posDisp = 0.01,		// position dispersion of the pointer, as percentage of soundfile duration
			pitch=1,
			auxmix=0, amp=1,
			fadein = 2, fadeout = 2,
			posRate = 1,	// change the speed of the grain position pointer (can be negative)
			posInv = 0,		// flag (0/1) to invert the posRate
			monAmp = 1,		// monitor amp, for headphones
			amp_lag = 0.3,		// time lag on amplitude changes (amp, xfade, mon send, aux send)
			balance_amp_lag = 0.3,	// time lag on amplitude xfade changes
			recvUpdate = 0,		// flag to check if next selected buffer is to be input to this instance
			t_posReset = 0,		// reset the phasor position with a trigger
			gate = 1;			// gate to start and release the synth

			var
			env, grain_dens, amp_scale, trig, b_frames,
			pos, pos_lo, pos_hi, sig, out, aux, auxmix_lagged;

			// envelope for fading output in and out - re-triggerable
			env = EnvGen.kr(Env([1,1,0],[fadein, fadeout], \sin, 1), gate, doneAction: 0);

			// calculate grain density
			grain_dens = grainRate * grainDur;
			amp_scale = grain_dens.reciprocal.sqrt.clip(0, 1);

			// gaussian trigger
			// grainRand = 0 regular at grainRate
			// grainRand = 1 random around grainRate
			trig = GaussTrig.ar(grainRate, grainRand);


			b_frames = BufFrames.kr(bufnum);
			// use line to go from start to end in buffer
			pos = Phasor.ar( t_posReset,
				BufRateScale.kr(bufnum) * posRate * (1 - (posInv*2)),
				b_frames * start, b_frames * end, b_frames * start
			);
			pos = pos * b_frames.reciprocal;

			pos_lo = posDisp * 0.5.neg;
			pos_hi = posDisp * 0.5;

			// add randomness to position pointer, make sure it remains within limits

			pos = pos + TRand.ar(pos_lo, pos_hi, trig);
			pos = pos.wrap(start , end);

			/* granulator */
			sig = GrainBufJ.ar(1, trig, grainDur, buffer, pitch , pos, 1, interp:1, grainAmp: amp_scale);

			/* overall amp control */
			sig = Limiter.ar( sig * Lag.kr(amp, amp_lag) * env, -0.5.dbamp);

			/* aux send control */
			// auxmix_lagged = Lag.kr(auxmix, amp_lag);
			// balance between dry and wet routing
			// out = sig * (1 - auxmix_lagged).sqrt;
			// aux = sig * auxmix_lagged.sqrt;
			out = sig;

			// send signals to outputs
			Out.ar( outbus,		out );
			// Out.ar( outbus_aux,	aux );
		})
	}
}

GrainScannerView {
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