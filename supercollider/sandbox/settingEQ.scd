// 6 channels of noise: 0 - 5
SynthDef(\noi, {Out.ar(0, PinkNoise.ar(0.8 ! 6))}).send(s)
// 1 channel of noise
SynthDef(\noi2, {Out.ar(8, PinkNoise.ar(0.8))}).send(s)
x = Synth.new(\noi) // ch 0 - 5
x = Synth.new(\noi2) // ch 8

s.freqscope

m = MasterEQ(6);
// get the eq settings [freq, dbgain, rq]
m.eq[ \frdb ]
// set the eq settings [freq, dbgain, rq]
m.eq[ \frdb ] = [[100,0,1], [250,0,1], [1000,0,1], [3500,0,1], [6000,0,1]];
m.eq[ \frdb ] = [[100,4,1], [145,-4,0.3], [145*2,-3,0.3], [145*3,-2,0.3], [6000,0,1]];
m.eq[ \send_current ].value; // send values to the synths
// update the gui to reflect
m.eq[ \uvw ].refresh;
m.eq[ \tvw_refresh ].value;
m.eq[ \pumenu_check ].value;

// move the eq synth from bus 2 to bus 8
m.eq[ \synths ][2].set(\in, 8)
// note there's no longer eq on bus 2