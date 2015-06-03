(
d = CtkSynthDef(\motorPlaybuf, {
	arg outbus = 0, buf, bufnum, startPos = 0, amp=1, mix=0.5,
	predelay = 0.03, cutoffHigh = 4000, cutoffLow=450, t60low = 2.2, t60high = 1.5, diffusion = 1,
	mixHigh = 1, mixLow = 0.2,
	fadeIn=0.25, sustain=0.5, release=0.25, dur = 20, onsetCurve = 3, t_onset = 0;
	var pb, encoder, decoder, verb, cutoffenv, mixenv, xFormEnv;

	pb = PlayBuf.ar(2, buf, startPos: startPos * BufFrames.kr(bufnum), loop: 1);

	encoder = FoaEncode.ar( pb, FoaEncoderMatrix.newStereo(pi/3.5) );

	xFormEnv = EnvGen.kr(
		Env([0,0,1,1,0],[0,fadeIn, sustain, release], onsetCurve, releaseNode:1, loopNode: 0),
		TDelay.kr(t_onset, 0.05), timeScale: dur, doneAction: 0
	);

	cutoffenv = LinLin.kr(xFormEnv, 0, 1, cutoffLow, cutoffHigh);
	mixenv = LinLin.kr(xFormEnv, 0, 1, mixHigh, mixLow).poll;

	verb = BFormatReverb.ar(encoder,
		mixenv.sqrt, //mix,
		predelay: predelay,
		cutoff: cutoffenv,
		t60low: t60low, t60high: t60high, diffusion: diffusion);

	decoder = FoaDecode.ar(verb,
		FoaDecoderMatrix.newDiametric([30.degrad, -30.degrad], 'controlled'),
	);

	Out.ar(outbus, decoder);
});
)
b = CtkBuffer.playbuf("/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_capture_EDIT.WAV").load;

x = d.note.outbus_(0).buf_(b).play

x.t_onset_(1)

x.cutoff_(800)
x.mix_(1)

x.free