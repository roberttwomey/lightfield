d = CtkSynthDef(\motorPlaybuf, {arg outbus = 0, buf, bufnum, startPos = 0, amp=1, mix=0.5,
	predelay = 0.03, cutoff = 3000, t60low = 2.2, t60high = 1.5, diffusion = 1;
	var pb, encoder, decoder, verb, m_cutoff, xformEnv;

	pb = PlayBuf.ar(2, buf, startPos: startPos * BufFrames.kr(bufnum), loop: 1);

	encoder = FoaEncode.ar( pb, FoaEncoderMatrix.newStereo(pi/3.5) );

	xFormEnv = EnvGen.kr(
		Env([0,0,1],[0,auxLag*0.6], auxOnsetCurve, releaseNode:1, loopNode: 0),
		TDelay.kr(t_auxOnset, 0.05), doneAction: 0
	);

	m_cutoff = MouseX.kr(4000, 450);

	verb = BFormatReverb.ar(encoder,
		MouseX.kr(0,1).sqrt, //mix,
		predelay: predelay,
		cutoff: m_cutoff, //cutoff,
		t60low: t60low, t60high: t60high, diffusion: diffusion);

	decoder = FoaDecode.ar(verb,
		FoaDecoderMatrix.newDiametric([30.degrad, -30.degrad], 'controlled'),
	);

	Out.ar(outbus, decoder);
});

b = CtkBuffer.playbuf("/Users/admin/src/rover/data/AUDIO/EDITS/dining_room_capture_EDIT.WAV").load;

x = d.note.outbus_(0).buf_(b).play

x.cutoff_(800)
x.mix_(1)

x.free