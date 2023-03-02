/*
Hi all:

Here's a B-Format reverb. It takes a B-Format signal in, and sends B-Format out. A quick description:

- Input signal is converted to A-Format, to preserve directionality (Joseph Anderson and Juan suggested this a while back)
- The signal is filtered (controlled by cutoff) and predelayed (controlled by predelay). These parameters are often useful for helping a reverb to sit in the mix better. A lower cutoff can make a reverb sound more natural.
- Each of the A-Format channels is processed by 4 series allpass filters, in order to decorrelate the input signal, and add reflection density. See http://www.stanford.edu/~dattorro/EffectDesignPart1.pdf for details about why this is done. The diffusion parameter controls the coefficients of the allpass filters
- Each of the decorrelated A-Format chanels feeds into a 4-branch feedback delay network. The feedback delay network has allpasses embedded within its structure, to enable a quick build of echo density (the allpass coefficients are also controlled by the diffusion parameter). The scattering matrix is at the front of the structure, and a single output per feedback delay network is taken right after the scattering matrix. Each branch of the feedback delay network has a lowpass filter, used to control the decay time at DC and Nyquist (see pretty much any paper by Jean-Marc Jot for further details).
- The scattering matrices for the individual feedback delay networks are coupled by a larger scattering matrix, in order to control the spread between the various A Format channels. The spreading between left and right is controlled by diffusionLR, while the spreading between front and back is controlled by diffusionFB. Higher settings of these parameters will result in a denser impulse response, but lower settings will yield better imaging of the reverb (as the reverb energy from a signal will primarily be focused in the channel from which the signal originated).
- Each of the branches in the FDNs uses a modulated delay line, which increases the sound quality, but also the computation cost (the modulation amount is controlled by mod).

I think the reverb sounds pretty good, but my guess is that the delay line lengths could be set better. However, it takes a lot of time to tweak 48 delay lengths, so this will have to wait for some future date. Ideally, the delay times would be tweaked by a computer simulation.

Give this a try, and let me know if you have any questions.

Regards,

Sean Costello

//(for DXARTS 567)
// Sean Costello
// November 20 - December 14, 2006
// "mailto:seancostello2000@yahoo.com"seancostello2000@yahoo.com
*/
/*

Edited to use ATK matricies / features. This adds the following:

- A/B encoder/decoder: "diffuse field" weighting for the A/B conversion, the ideal for reverberation
- Dominance on X: weighting across the front/back (x-axis) to allow asymmetric weighting of reverberance (like natural soundfields)
  [NOTE: a slightly different architecture would be required to allow asymmetric weighting for the early reflections]

Joseph Anderson
DXARTS
3 March 2014

*/

BFormatReverb {
	*ar {|in, mix=1, predelay=0.05,
		cutoff=3000, t60low=2.2, t60high=1.5,
		diffusion=1.0, diffusionLR=1.0, diffusionFB=1.0, mod=1.0,
		inscale = 1|
		var local, sum, delays, delayMod, allpassDelays, lateAllpassDelays;
		var allpassCoefEarly, allpassCoefLate;
		var g0late, g1late, a1late, b0late;
		var matrix, temp;
		var minDelay, maxDelay, numDelays, foo;
		var minAllpassDelay, maxAllpassDelay, numAllpassDelays;
		var minLateAllpassDelay, maxLateAllpassDelay, numLateAllpassDelays;
		var earlyVec, outVec;
		var diffusionLRcos, diffusionLRsin, diffusionFBcos, diffusionFBsin;
		var orientation, weight, dominanceGain, out;

		// ATK parameters
		// orientation of the A-format tetrahedron
		// front & left-up: [[45.0,  35.3], [-45.0, -35.3], [135.0, -35.3], [-135.0,  35.3]]
		// weight, choose 'dec' for ideal decorrelated soundfield
		// dominanceGain, gain @ [0, 0]
		// J Anderson, 28 February 2014
		orientation = 'flu'; // front & left-up corresponds to Sean's matrix...
		weight = 'dec';
		// dominanceGain = -1.5; // gives a 3dB difference between Front and Back, weighted to Back
		dominanceGain = 0.0; // gives a 2dB difference between Front and Back, weighted to Back

		// scale diffusionLR and diffusionFB values by 0.5pi
		diffusionLR = diffusionLR * 0.25pi;
		diffusionFB = diffusionFB * 0.25pi;

		// precalculate cos and sin of diffusionLR and diffusionFB values
		diffusionLRcos = diffusionLR.cos;
		diffusionLRsin = diffusionLR.sin;
		diffusionFBcos = diffusionFB.cos;
		diffusionFBsin = diffusionFB.sin;

		// calculate delay times
		// all delay times are exponentially increasing (i.e. form a straight line
		// in log space)
		minDelay = 0.04402;
		maxDelay = 0.115905;
		numDelays = 16;
		foo = (maxDelay/minDelay)**(1.0/numDelays);

		delays = Array.newClear(numDelays);
		for(0, 3, {arg j;
			for(0, 3, {arg i;
				delays[(4*j) + i] = minDelay*(foo**((4*i) + j));
			});
		});

		minAllpassDelay = 0.00617;
		maxAllpassDelay = 0.0211;
		numAllpassDelays = 16;
		foo = (maxAllpassDelay/minAllpassDelay)**(1.0/numAllpassDelays);

		allpassDelays = Array.newClear(numAllpassDelays);
		for(0, 3, {arg j;
			for(0, 3, {arg i;
				allpassDelays[(4*j) + i] = minAllpassDelay*(foo**((4*i) + j));
			});
		});

		// coefficient calculations for first order filters used
		// in frequency dependent attenuation for each delay line
		// in the late reverb
		// based on filter calculation code by Tim Stilson

		g0late = exp(-6.90775527898214*(delays)/t60low);
		g1late = exp(-6.90775527898214*(delays)/t60high);
		a1late = (g1late-g0late)/(g1late+g0late);
		b0late = (1.0+a1late)*g0late;

		// allpass coefficient calculation. SC3 only has a T60 for the allpass
		// delay coefficients, and I prefer to work with raw coefficients, so
		// the following calculation generates a coefficient of 0.6*diffusion
		// for each allpass in the network
		allpassCoefEarly = -3.0*(allpassDelays/log10(0.6*diffusion));

		// most commercial reverbs (that sound decent) use some delay length modulation
		// within the recursive tank. With large feedback delay networks, you may
		// be able to get away with no modulation, but I would still recommend using it.
		// for the lite version, only 2 of the 4 branches per channel are modulated
		// the modulation depth is twice as large as in BFormatReverb, to compensate
		// for the reduced number of modulating delay lines
		mod = LFTri.kr([0.41, 0.47, 0.53, 0.552], 0.0, mod*0.0012);
		delayMod =   [delays[0]+mod[0], delays[1], delays[2]-mod[0], delays[3],
			delays[4]+mod[1], delays[5], delays[6]-mod[1], delays[7],
			delays[8]+mod[2], delays[9], delays[10]-mod[2], delays[11],
			delays[12]+mod[3], delays[13], delays[14]-mod[3], delays[15]];

		// 4 channel input
		in = in * inscale;

		// ATK B-Format to A-Format decoding for early reflections vector
		// --> add the input into the system as A-format
		// J Anderson, 28 February 2014
		earlyVec = FoaDecode.ar(
			in,
			FoaDecoderMatrix.newBtoA(orientation, weight)
		);

		// predelay and lowpass filter the input signal
		earlyVec = OnePole.ar(DelayN.ar(earlyVec, 1.0, predelay), exp(-2.0pi*cutoff/SampleRate.ir));



		// 4 series allpass delays per input channel, to decorrelate inputs
		for(0, 3, {arg j;
			for(0, 3, {arg i;
				earlyVec[j] = AllpassN.ar(earlyVec[j], allpassDelays[(4*i)+j], allpassDelays[(4*i)+j], allpassCoefEarly[(4*i)+j]);
			});
		});

		// use LocalIn for feedback, and add early reflections
		local = LocalIn.ar(16) +   [earlyVec[0], 0.0, 0.0, 0.0,
			earlyVec[1], 0.0, 0.0, 0.0,
			earlyVec[2], 0.0, 0.0, 0.0,
			earlyVec[3], 0.0, 0.0, 0.0];


		// unitary scattering matrix for reverberator in each branch
		// based upon junction of equal impedence waveguides
		// see Julius O. Smith III website for details
		for(0, 3, {arg j;
			sum = 0.0;

			for(0, 3, {arg i;
				sum = sum + local[(4*j)+i];
			});


			for(0, 3, {arg i;
				local[(4*j)+i] = local[(4*j)+i] - (0.5*sum);
			});
		});

		// create output vector from a single branch in each channel
		outVec = [local[0], local[4], local[8], local[12]];

		// ATK A-Format to B-Format encoding for output vector
		// ... followed by Dominance to control the Front-Back balance
		// --> send the output from the system as B-format
		// J Anderson, 28 February 2014
		// Encoding to B-format (from A-format) and Dominance as a single operation
		outVec = AtkMatrixMix.ar(
			outVec,
            FoaXformerMatrix.newDominateX(dominanceGain).matrix *
			FoaEncoderMatrix.newAtoB(orientation, weight).matrix
		);


		// mix input with output vector, and send to out bus
		// Out.ar(outbus, (In.ar(inbus, 4)*(1.0-mix)) + (outVec*mix));
		out = (in*(1.0-mix)) + (outVec*mix);

		// block DC in feedback loop
		local = LeakDC.ar(local);

		// -----------------------------------------------------------------------
		// late reverb tank
		// each A-Format channel is processed by a 4-branch feedback delay network,
		// where each branch consists of a delay line and a first-order filter
		// for gain control at DC and Nyquist
		// the even numbered delay lines are modulated, and use DelayC
		// the odd numbered delay lines use DelayN for efficiency
		forBy(0, 14, 2, {arg i;
			local[i] = FOS.ar(
				DelayC.ar(local[i], delays[i]+0.005, delayMod[i]),
				b0late[i], 0.0, a1late[i].neg);
			local[i+1] = FOS.ar(
				DelayN.ar(local[i+1], delays[i+1], delayMod[i+1]),
				b0late[i], 0.0, a1late[i].neg);
		});

		// left<->right diffusion for front channels
		for(0, 3, {arg i;
			temp = [local[i], local[i+4]];
			local[i] = (diffusionLRcos*temp[0]) - (diffusionLRsin*temp[1]);
			local[i+4] = (diffusionLRsin*temp[0]) + (diffusionLRcos*temp[1]);
		});

		// left<->right diffusion for rear channels
		for(8, 11, {arg i;
			temp = [local[i], local[i+4]];
			local[i] = (diffusionLRcos*temp[0]) - (diffusionLRsin*temp[1]);
			local[i+4] = (diffusionLRsin*temp[0]) + (diffusionLRcos*temp[1]);
		});

		// front<->back diffusion
		for(0, 7, {arg i;
			temp = [local[i], local[i+8]];
			local[i] = (diffusionFBcos*temp[0]) - (diffusionFBsin*temp[1]);
			local[i+8] = (diffusionFBsin*temp[0]) + (diffusionFBcos*temp[1]);
		});


		// send delays to LocalOut for feedback
		LocalOut.ar(local);
		^out;
	}
}