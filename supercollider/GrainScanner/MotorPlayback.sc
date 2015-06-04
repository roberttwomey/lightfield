MotorPlayback {
	classvar <playbackDef;
	// copyArgs
	var <outbus, <buf;
	var <synth;

	*new { |outbus = 0, buf|
		^super.newCopyArgs(outbus, buf).init;
	}

	init {
		fork{
			this.class.playbackDef ?? { this.initSynth; 0.2.wait; Server.default.sync; };
			// synth = playbackDef.note.buf_(buf).bufnum_(buf.bufnum).outbus_(outbus);
		}
	}

	play { |dur = 20 |
		synth = playbackDef.note.buf_(buf).bufnum_(buf.bufnum).outbus_(outbus).dur_(dur).play;
		synth.t_startPos_(1); // random start position in the soundfile
	}

	free { synth.free }

	initSynth {

		playbackDef = CtkSynthDef( \motorPlaybuf, {

			arg outbus = 0, buf, bufnum, stPos = 0, amp=1, mix=0.5,
			predelay = 0.03, cutoffHigh = 4000, cutoffLow=450,
			t60low = 2.2, t60high = 1.5, diffusion = 1,
			mixHigh = 1, mixLow = 0.2,
			fadeIn=0.25, sustain=0.5, fadeOut=0.25, dur = 20, onsetCurveIn = 3, onsetCurveOut = -3, ampCurveIn = 3, ampCurveOut = -3, gate = 1, t_startPos = 1;
			var pb, encoder, decoder, verb, cutoffenv, mixenv, xFormEnv, ampEnv;

			pb = PlayBuf.ar(2, buf,
				startPos: TRand.kr(0, BufFrames.kr(bufnum), t_startPos),
				loop: 1
			);

			encoder = FoaEncode.ar( pb, FoaEncoderMatrix.newStereo(pi/3.5) );

			xFormEnv = EnvGen.kr(
				Env([0,1,1,0],[fadeIn, sustain, fadeOut], [onsetCurveIn,1,onsetCurveOut]),
				gate, timeScale: dur, doneAction: 2
			);

			ampEnv = EnvGen.kr(
				Env([0,1,1,0],[fadeIn, sustain, fadeOut], [ampCurveIn,1,ampCurveOut]),
				gate, levelScale: amp, timeScale: dur, doneAction: 2
			);

			cutoffenv = LinLin.kr(xFormEnv, 0, 1, cutoffLow, cutoffHigh);
			mixenv = LinLin.kr(xFormEnv, 0, 1, mixHigh, mixLow);

			verb = BFormatReverb.ar(encoder,
				mixenv.sqrt, //mix,
				predelay: predelay,
				cutoff: cutoffenv,
				t60low: t60low, t60high: t60high, diffusion: diffusion);

			decoder = FoaDecode.ar( verb,
				FoaDecoderMatrix.newDiametric([30.degrad, -30.degrad], 'controlled'),
			);

			Out.ar(outbus, decoder * ampEnv);
		});
	}
}

/* SCRATCH

b = CtkBuffer.playbuf("/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_capture_EDIT.WAV").load;

m = MotorPlayback(0, b)
m.synth
m.synth.onsetCurve_(2)
m.synth.ampCurve_(-1)
m.synth
m.synth.fadeIn_(0.25).sustain_(0.5).fadeOut_(0.25)


m.play( 30 )
m.free

*/