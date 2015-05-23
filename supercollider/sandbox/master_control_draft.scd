// master startup system

s.options.sampleRate_(44100)
s.boot

~broadcastDestination = NetAddr("localhost", 57120);

////////////////////////
// Video
////////////////////////


// start control signals for refocuser
~refocuser = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount", "xscroll", "yscroll", "zoom"], ~broadcastDestination );

// start a control for fade in/out

~fader = ControlFade(3);
~fader.broadcast( ~broadcastDestination, '/fade', 30 );
~fader.fadeTime_(1)
~fader.plot
~fader.lfo_(SinOsc, 3, 0,1)

~fader.value_(0, 4)
~fader.value_(1, 3)

~fader.stopBroadcast;
~fader.free

o = OSCFunc({|msg| msg.postln;}, '/fade')
o.free


////////////////////////
// Audio
////////////////////////
