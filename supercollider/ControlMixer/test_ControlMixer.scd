// test file for ControlMixer
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount"], NetAddr("localhost", 57120) )
c = ControlMixMaster( ["focus", "xstart", "ystart"], NetAddr("localhost", 57120) )

// c = ControlMixer( "/focus", NetAddr("localhost", 57120) );
// d = ControlMixer( "/test2", NetAddr("localhost", 57120) );


c.storePreset( \first )
c.storePreset( \second )
c.storePreset( \third )
c.storePreset( \fourth )

c.recallPreset( \first )
c.recallPreset( \second )
c.recallPreset( \third )
c.recallPreset( \fourth )


c.removePreset( \first )

c.presets[\first].mixers.keys
c.presets[\first].mixers['/ycount'].size

(
c.presets[\first].mixers.keysValuesDo({|k,v| k.postln; v.do({|ctlFadeStates, i| i.postln; ctlFadeStates.keysValuesDo({|k,v| [k,v].postln }) }); "".postln; });
nil
)

(
c.presets[\first].mixers['/ycount'].do({|ctlFadeStates, i| i.postln; ctlFadeStates.keysValuesDo({|k,v| [k,v].postln }) });
nil
)

c.presets[\first].mixers['/xstart']
c.presets[\first].mixers['/xstart'].size
(
c.presets[\first].mixers['/xstart'].do({|ctlFadeStates, i| i.postln; ctlFadeStates.keysValuesDo({|k,v| [k,v].postln }) });
nil
)


c.addMixer

OSCdef(\cmtest1, {|msg, time, addr, recvPort| msg.postln}, '/focus', n); // def style

OSCdef(\cmtest2, {|msg, time, addr, recvPort| msg.postln}, '/test2', n); // def style

to save, an array of controls to be mixed, each with:
\min, ctl.low
\max, ctl.high
\signal, ctl.lfo,
\rate, ctl.freq
\val, ctl.value
\scale, ctl.scale
\offset, ctl.offset
\mix, ctl.amp

c.ctlFades[0].lfo //symbol
c.ctlFades[0].freq
c.ctlFades[0].low
c.ctlFades[0].high
c.ctlFades[0].value
c.ctlFades[0].scale
c.ctlFades[0].offset
c.ctlFades[0].amp

c.addCtl(-1,3)