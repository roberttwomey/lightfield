(
~grnDef = CtkSynthDef(\grainJ, {
	arg
	buffer, bufnum,
	out_bus, 			// main out
	out_bus_aux,		// outbus to reverb
	start=0, end=1,		// bounds of grain position in sound file
	grainRand = 0,		// gaussian trigger: 0 = regular at grainRate, 1 = random around grainRate
	grainRate = 10, grainDur = 0.04,
	posDisp = 0.01,	// position dispersion of the pointer, in seconds
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

	// envelope for fading output in and out
	env = EnvGen.kr(Env([0,1,0],[fadein, fadeout], \sin, 1), gate, doneAction: 0);

	// calculate grain density
	grain_dens = grainRate * grainDur;
	amp_scale = grain_dens.reciprocal.clip(0, 1);

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
	Out.ar( out_bus,		out );
	// Out.ar( out_bus_aux,	aux );
})
)


/* set up the buffer */
// handle each of the stereo channels independently
~path = "/Users/admin/src/rover/data/AUDIO/discovery_cliffside_clip.WAV"
~b1 = Buffer.readChannel(Server.default, ~path, channels: 0 );
~b2 = Buffer.readChannel(Server.default, ~path, channels: 1 );

[~b1, ~b2].do(_.free)

x = ~grnDef.note
.buffer_(~b1)
.bufnum_(~b1.bufnum)
.out_bus_(0).play


x.grainDur_(3.3)
x.grainDur_(1.3)
x.posDisp_(0.03)

x.posRate_(0.4).posDisp_(0.001)

y = ~grnDef.note
.buffer_(~b2)
.bufnum_(~b2.bufnum)
.out_bus_(1).play

y.grainDur_(1.3)

y.posDisp_(0.01)
y.posRate_(0.4).posDisp_(0.001)

[x,y].do(_.t_posReset_(1)) // sync up the instances

//jump to a particular moment, spanning a window of time (looping right now)
~scan = { | centerSec, spanSec |
	~span = spanSec / ~b1.duration; // the span of time of the scanning window
	~moment = centerSec / ~b1.duration;
	[x,y].do({|me| me.start_(~moment - ~span.half).end_(~moment + ~span.half).t_posReset_(1)}) // sync up the instances
}

~scan.(rand(~b1.duration).postln, rrand(2.5,9.2))

[x,y].do(_.posRate_(0.8))

[x,y].do(_.posDisp_(0.8)) // disperse to break apart the inherent time gesture (moment/onset), but retain the timbre, etc. of the moment

// volume increases with smaller dispersion?

// create slight variance in rate, so they depart over time
[x,y].do(_.posRate_(0.8 + sum3rand(0.05).postln))
// make smallish dispersion to hear the offset
[x,y].do(_.posDisp_(0.02))

start=0, end=1,		// bounds of grain position in sound file
grainRand = 0,		// gaussian trigger: 0 = regular at grainRate, 1 = random around grainRate
grainRate = 10,
grainDur = 0.04,
posDisp = 0.01,	// position dispersion of the pointer, in seconds
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

[x,y].do(_.free)