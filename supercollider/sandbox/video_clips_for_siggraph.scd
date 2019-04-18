// read in presets for first time
Archive.read("/Volumes/Work/Projects/lightfield/supercollider/preset_backups/ControlMixer_presets/FRIDAY_afternoon_150605_163419.sctxar")

// requires SenseWorld quark
c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ], NetAddr("127.0.0.1", 12345));

c.loadScene("./textures/yellowcliff.xml")
c.recallPreset(\mike1_rover_mirror)

