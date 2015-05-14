// test file for ControlMixer
<<<<<<< HEAD
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount"], NetAddr("localhost", 57120) )
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount"], NetAddr("192.168.0.102", 12345) )
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount", "xscroll", "yscroll", "zoom"], NetAddr("192.168.0.102", 12345) )
=======
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount"], NetAddr("ubuntu.local", 12345) )
>>>>>>> 816a75775d8f1d3b4b1a81563a733780345859b5
c = ControlMixMaster( ["focus", "xstart", "ystart"], NetAddr("localhost", 57120) )

// c = ControlMixer( "/focus", NetAddr("localhost", 57120) );
// d = ControlMixer( "/test2", NetAddr("localhost", 57120) );


c.storePreset( \first )
c.storePreset( \second )
c.storePreset( \third )
c.storePreset( \fourth )
c.storePreset( \fifth )
c.storePreset( \sixth )

c.storePreset(\myFirst)

c.recallPreset( \first )
c.recallPreset( \second )
c.recallPreset( \third )
c.recallPreset( \fourth )
c.recallPreset( \fifth )
c.recallPreset( \sixth )

c.recallPreset(\myFirst)

c.removePreset( \first )

c.presetGUI(3)

c.presets[\first].mixers.keys
c.presets[\first].mixers['/ycount'].size

(
ControlMixMaster.archive[\first].mixers.keysValuesDo({|k,v| k.postln; v.do({|ctlFadeStates, i| i.postln; ctlFadeStates.keysValuesDo({|k,v| [k,v].postln }) }); "".postln; });
nil
)
(
ControlMixMaster.archive[\fifth].mixers.keysValuesDo({|k,v| k.postln; v.do({|ctlFadeStates, i| i.postln; ctlFadeStates.keysValuesDo({|k,v| [k,v].postln }) }); "".postln; });
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