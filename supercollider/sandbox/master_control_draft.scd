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

~fader = ControlFade(0.1);
~fader.broadcast( ~broadcastDestination, '/fade', 30 );
~fader.fadeTime_(0.1)
~fader.plot

~fader.stopBroadcast;
~fader.free

o = OSCFunc({|msg| msg.postln;}, '/fade')
o.free


////////////////////////
// Audio
////////////////////////
