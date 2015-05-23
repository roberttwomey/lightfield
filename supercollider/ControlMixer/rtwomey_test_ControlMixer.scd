// test file for ControlMixer
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount"], NetAddr("localhost", 57120) )
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount"], NetAddr("192.168.0.102", 12345) )
c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount", "xscroll", "yscroll", "zoom"], NetAddr("192.168.0.102", 12345) )

c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount", "xscroll", "yscroll", "zoom"], NetAddr("refocuser.local", 12345) )

c = ControlMixMaster( ["focus", "xstart", "ystart", "xcount", "ycount", "xscroll", "yscroll", "zoom"], NetAddr("localhost", 57120) )

// test fade
// test snapshot loading

c = ControlMixMaster( ["focus", "fade", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ], NetAddr("refocuser.local", 12345))


c.loadScene("./textures/dark_trees_calib.xml")
c.loadScene("./textures/diningroom3.xml")
c.loadScene("./textures/cliffside.xml")
c.loadScene("./textures/bookcase.xml")
c.loadScene("./textures/carkeek_night.xml")
c.loadScene("./textures/carkeek.xml")
c.loadScene("./textures/mike1.xml")
//c.loadScene("./textures/mike2.xml")
//c.loadScene("./textures/mike3.xml")
c.loadScene("./textures/outsidelookingin.xml")
c.loadScene("./textures/tivon1_calib.xml")
c.loadScene("./textures/tivon2_sm.xml")

c.loadScene("./textures/ballard_wall_calib.xml")

c.loadScene("./textures/carkeek_med_tile.xml")


// snapshots
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/yellowcliff/yellowcliff_0002.txt")

c.loadSnapshot("/Volumes/Home Directory/code/lightfield/scenes/test/diningroom3_0000.txt")


// presets
c.storePreset( \yellowcliff_close)
c.storePreset( \yellowcliff_bush)

// oops I deleted this:
// c.storePreset( \tivon1 )
// c.storePreset( \tivon1_lights )
// c.storePreset( \tivon1_mirror )


c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/rover_in_mirror/20150521132155_0000.txt")
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/rover_in_mirror/20150521132159_0001.txt")
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/rover_in_mirror/20150521132202_0002.txt")
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/rover_in_mirror/20150521132205_0003.txt")
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/rover_in_mirror/20150521132208_0004.txt")


c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/books/book_spines_small.txt")

c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/mike_portal/0000_sm.txt")

c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/train/05221118_0000_sm.txt")

c.loadSnapshot("/Users/admin/Downloads/loadsnapshotparamsintocontrolmixer/20150522111823_0003.txt")
c.loadSnapshot("/Users/admin/Downloads/loadsnapshotparamsintocontrolmixer/20150522111823_0004.txt")

OSCdef(\texture, {|msg| msg.postln;}, '/loadTextures')


// NetAddr("localhost", 12345).sendMsg("/")

c.storePreset( \projTest, true )
c.storePreset( \first )
c.storePreset( \second )
c.storePreset( \third )
c.storePreset( \fourth )
c.storePreset( \fifth )
c.storePreset( \sixth )
c.storePreset( \basement )

c.recallPreset( \first )
c.recallPreset( \second )
c.recallPreset( \third )
c.recallPreset( \fourth )
c.recallPreset( \fifth )
c.recallPreset( \sixth )
c.recallPreset( \projTest )


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