// 1. Setup new rover installation. follow directions on repo
// https://github.com/roberttwomey/lightfield

Platform.userExtensionDir
QuarksGui.new
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");


ATK Kernel Installation
(
// Create ATK support directory
// Place unzipped kernels in the directory opened

Atk.createUserSupportDir;
Atk.openUserSupportDir;
)


// 2. Restoring Presets
// read in presets for first time
Archive.read("/Volumes/Work/Projects/lightfield/supercollider/preset_backups/ControlMixer_presets/FRIDAY_afternoon_150605_163419.sctxar")

// requires SenseWorld quark
c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ], NetAddr("192.168.1.111", 12345));

c.loadScene("./textures/yellowcliff.xml")
c.recallPreset(\mike1_rover_mirror)

GrainScanner1.presets.keys
GrainScanner2.presets.keys
ControlMixMaster.presets.keys

// test them
c.recallPreset(\bookcase_bed_knob_plant)
c.recallPreset(\bookcase_mirror_flat)
c.recallPreset(\bookcase_start)
c.recallPreset(\bookcase_window)