// read in presets for first time
Archive.read("/Volumes/Work/Projects/lightfield/supercollider/preset_backups/ControlMixer_presets/FRIDAY_afternoon_150605_163419.sctxar")

// requires SenseWorld quark
c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ], NetAddr("127.0.0.1", 12345));

c.loadScene("./textures/yellowcliff.xml")
c.recallPreset(\mike1_rover_mirror)


c.loadScene("./textures/bookcase.xml")
c.loadScene("./textures/carkeek.xml")
c.loadScene("./textures/carkeek_night.xml")
c.loadScene("./textures/cliffside.xml")
c.loadScene("./textures/dark_trees.xml")
c.loadScene("./textures/diningroom3.xml")
c.loadScene("./textures/mike1.xml")
c.loadScene("./textures/mike2.xml")
c.loadScene("./textures/mike3.xml")
c.loadScene("./textures/outsidelookingin.xml")
c.loadScene("./textures/precise.xml")
c.loadScene("./textures/towers.xml")
c.loadScene("./textures/tunnel.xml")
c.loadScene("./textures/yellowcliff.xml")
