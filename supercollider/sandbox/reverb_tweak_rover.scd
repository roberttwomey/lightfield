a = CtkAudio.play(2)
s.scope(1, a.bus)
(
d = CtkSynthDef(\verb_localin, {
	arg outbus = 0, inbus, revTime = 3, decayTime = 2, mix = 0.5, apDecay = 0.2, scaleReflections = 1, dampFreq = 1800, impFreq = 0.257;
	var src, combDels, g, lIn, lOut, delay, combs, ap, out;

	// var apDecay = 0.2; //2.0;
	var apDelay = 0.095;
	var apOrder = 6;

	src = In.ar(inbus, 1);
	// src = In.ar(0, 1);
	// src = Decay.ar(Impulse.ar(impFreq, 0.25), 0.2, PinkNoise.ar, 0);

	combDels = ([0.0297, 0.0371, 0.0411, 0.0437] + 4.collect({Rand(0.0, 0.004)})) * scaleReflections;

	// calculate feedback coefficient
	g = 10.pow(-3 * combDels / decayTime);

	lIn = LocalIn.ar(4);

	combs = DelayC.ar(src + (lIn * g),
		// combDels.maxItem - ControlRate.ir.reciprocal,
		2.5 - ControlRate.ir.reciprocal,
		combDels - ControlRate.ir.reciprocal
	);

	combs = LPF.ar(combs, dampFreq); // damping

	combs = LeakDC.ar(combs);

	lOut = LocalOut.ar(combs);

	ap = combs.sum;
	apOrder.do({|i|
		ap = AllpassC.ar( ap,
			apDelay, // 2.0,
			apDelay.rand * LFTri.kr( rrand(8,17.0).reciprocal ).range(0.9, 1), // mod delays a bit
			apDecay
		);
	});

	delay = DelayN.ar(src, ControlRate.ir.reciprocal, ControlRate.ir.reciprocal); // make up delay

	out = (mix.sqrt * ap) + ((1 - mix.sqrt) * delay);

	// Out.ar(0, out.dup)
	ReplaceOut.ar(outbus, out)
})
)

v = d.note(addAction: \tail).outbus_(0).inbus_(a).apDecay_(2).mix_(1).play
q = d.note(addAction: \tail).outbus_(1).inbus_(a.bus+1).apDecay_(2).mix_(1).play
// v = d.note(addAction: \tail).apDecay_(2).mix_(1).play

v = 2.collect{ |i| d.note(addAction: \tail).outbus_(0+i).inbus_(a.bus+i).apDecay_(2).mix_(1).play }

v.do(_.free)
v.free
q.free

v.scaleReflections_(0.253971) // pack the early reflections closer together (denser)
v.scaleReflections_(0.53971)
v.scaleReflections_(1.53971) // thin them out
v.scaleReflections_(3.53971) // thin them out

v.decayTime_(0.5) // early reflection decay (affects feedback coefficient)
v.decayTime_(0.05) // early reflection decay
v.decayTime_(5)

v.apDecay_(2.5) // late field decay
// shorter than early reflections
v.apDecay_(5) // late field decay
v.apDecay_(0.5) // late field decay

// unnatural but interesting... early reflection decay lasts longer than late (allpass) decay
v.decayTime_(1.5) // early reflection decay
v.scaleReflections_(2)
v.apDecay_(0.1) // late field decay
v.apDecay_(0.2) // late field decay
v.apDecay_(0.5) // late field decay


v.scaleReflections_(11.6241); // delays in early reflections
v.decayTime_(15); // affects feedback coefficient in early reflections - longer decay means more feedback
// v.apDecay_(2.6); // late field decay
v.apDecay_(0.2); // late field decay
v.dampFreq_(1800) // normal
v.dampFreq_(200) // muffled


v.scaleReflections_(21.6241); // delays in early reflections
v.decayTime_(1); // affects feedback coefficient in early reflections - longer decay means more feedback
v.apDecay_(0.01);
v.apDecay_(2); // late field decay
v.dampFreq_(1800); // normal
v.dampFreq_(2200) // muffled

v.dampFreq_(13800)


v.scaleReflections_(1.6241) // delays in early reflections
v.decayTime_(15) // affects feedback coefficient - longer decay means more feedback
v.apDecay_(0.2); // late field decay
v.apDecay_(1.6); // late field decay
v.decayTime_(5)


v.mix_(0) // hear the source with the reverb
v.mix_(0.5) // hear the source with the reverb
v.mix_(1) // hear the source with the reverb

(
var dim, gap, margin, spacing;
w = Window();
dim = 50@w.view.bounds.width;
spacing = w.view.bounds.width / 5;
gap = 5@5;
margin = 5@5;

EZSlider(w, bounds: Rect(spacing * 0, 0, dim.x, dim.y),
	label: "Scale Reflections",
	controlSpec: ControlSpec(0.5,35, 'exp'),
	action: { |sl|
		// v.scaleReflections_(sl.value);
		v.do(_.scaleReflections_(sl.value));
	},
	initVal:1, labelWidth: 85, labelHeight: 40,
	layout: 'vert', gap: gap, margin: margin
);
EZSlider(w, bounds: Rect(spacing * 1, 0, dim.x, dim.y),
	label: "Decay Time",
	controlSpec: ControlSpec(0.05, 15, 'exp'),
	action: { |sl|
		// v.decayTime_(sl.value);
		v.do(_.decayTime_(sl.value));
	},
	initVal:2, labelWidth: 85, labelHeight: 40,
	layout: 'vert', gap: gap, margin: margin
);
EZSlider(w, bounds: Rect(spacing * 2, 0, dim.x, dim.y),
	label: "AP Decay",
	controlSpec: ControlSpec(0.25, 15, 'exp'),
	action: { |sl|
		// v.apDecay_(sl.value);
		v.do(_.apDecay_(sl.value));
	},
	initVal:5, labelWidth: 85, labelHeight: 40,
	layout: 'vert', gap: gap, margin: margin
);
EZSlider(w, bounds: Rect(spacing * 3, 0, dim.x, dim.y),
	label: "mix",
	controlSpec: ControlSpec(0, 1, 'lin'),
	action: { |sl|
		// v.mix_(sl.value);
		v.do(_.mix_(sl.value));
	},
	initVal:0.2, labelWidth: 85, labelHeight: 40,
	layout: 'vert', gap: gap, margin: margin
);
EZSlider(w, bounds: Rect(spacing * 4, 0, dim.x, dim.y),
	label: "Damp Freq",
	controlSpec: ControlSpec(100,20000, 'exp'),
	action: { |sl|
		// v.dampFreq_(sl.value);
		v.do(_.dampFreq_(sl.value));
	},
	initVal:1800, labelWidth: 85, labelHeight: 40,
	layout: 'vert', gap: gap, margin: margin
);
w.front;
)