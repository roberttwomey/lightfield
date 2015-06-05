(
// modulating BPF frequency
d = CtkSynthDef(\bpfsweep, { arg inbus, outbus = 0;
    var in, bw, mod, out;
	//     in = Blip.ar(SinOsc.kr(5,0,20,300), 1000, 0.1);
	// in = PinkNoise.ar(0.2);
	in = In.ar(inbus, 1);
	bw = MouseX.kr(40, 12000).poll;
	// 2.collect{
		mod = LFDNoise3.kr(3.reciprocal).range(100, 1000);
		//     Formlet.ar(in, XLine.kr(1500,700,8), 0.0005, 0.004);
		out = Mix.ar(
			5.collect{ |i|
				var frq;
				// frq=mod*(i+1*3);
				frq= if(i==0,{mod},{mod*(i*4)});
				// Formlet.ar(in, mod*(i+1*3), att, dec)
				BPF.ar(in, frq, bw/frq)
			}
		);
// }
	ReplaceOut.ar(outbus, out)
})

)

x = 4.collect{|i| d.note(addAction: \tail).inbus_(i).outbus_(i).play}
4.do{|i|{Out.ar(i, PinkNoise.ar(0.2))}.play}
x.do(_.free)

pitchDriftPct = 0.1, pitchDriftPer = 5, bw = 1655, bpfDriftPer = 5;;

g.scanners.do{|scnr| scnr.synths.do(_.pitchDriftPct_(0.13))}
g.scanners.do{|scnr| scnr.synths.do(_.pitchDriftPer_(5))}
g.scanners.do{|scnr| scnr.synths.do(_.bw_(1850))}
g.scanners.do{|scnr| scnr.synths.do(_.bpfDriftPer_(6))}


(
// modulating BPF frequency
{
    var in, att, dec, bw, mod;
	//     in = Blip.ar(SinOsc.kr(5,0,20,300), 1000, 0.1);
	in = PinkNoise.ar(0.2);
	#att, dec = [0.00005, 0.000006]/2;
	bw = MouseX.kr(40, 12000).poll;
	2.collect{
		mod = LFDNoise3.kr(8.reciprocal).range(100, 1000).poll;
		//     Formlet.ar(in, XLine.kr(1500,700,8), 0.0005, 0.004);
		Mix.ar(
			4.collect{ |i|
				var frq;
				// frq=mod*(i+1*3);
				frq= if(i==0,{mod},{mod*(i*4)});
				// Formlet.ar(in, mod*(i+1*3), att, dec)
				BPF.ar(in, frq, bw/frq)
			}
		);
	}
}.play;
)


(
// modulating RLPF/RHPF frequency
{
    var in, att, dec, bw, fmod, twoCh;
	//     in = Blip.ar(SinOsc.kr(5,0,20,300), 1000, 0.1);
	in = PinkNoise.ar(0.2);
	#att, dec = [0.00005, 0.000006]/2;
	bw = MouseX.kr(400, 12000).poll;
	twoCh = 2.collect{
		fmod = LFDNoise3.kr(0.3).range(100, 1000).poll;
		//     Formlet.ar(in, XLine.kr(1500,700,8), 0.0005, 0.004);
		Mix.ar(
			3.collect{ |i|
				var rq, frq, lpf;
				frq=fmod*(i+1*3);
				rq = bw/frq;
				// Formlet.ar(in, mod*(i+1*3), att, dec)
				lpf = RLPF.ar(in, frq, rq);
				RHPF.ar(lpf, frq, rq)
			}
		);
	};
	LeakDC.ar(twoCh)
}.play;
)

(
// modulating resonz frequency
{
    var in, att, dec, bw, fmod, twoCh;
	//     in = Blip.ar(SinOsc.kr(5,0,20,300), 1000, 0.1);
	in = PinkNoise.ar(0.2);
	#att, dec = [0.00005, 0.000006]/2;
	bw = MouseX.kr(240, 15000, 3).poll;
	twoCh = 2.collect{
		fmod = LFDNoise3.kr(0.3).range(100, 1000).poll;
		//     Formlet.ar(in, XLine.kr(1500,700,8), 0.0005, 0.004);
		Mix.ar(
			3.collect{ |i|
				var rq, frq;
				frq=fmod*(i+1*3);
				rq = bw/frq;
				// Formlet.ar(in, mod*(i+1*3), att, dec)
				Resonz.ar(in, frq, rq);
			}
		);
	};
	LeakDC.ar(twoCh)
}.play;
)
