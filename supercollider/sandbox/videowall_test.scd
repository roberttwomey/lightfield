// Robert Twomey - testing video wall 2016

c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" , "fade"], NetAddr("refocuser.local", 12345));

~fader=ControlFade(1.0);
~fader.broadcast( c.broadcastNetAddr, '/fade', 30 );
~fader.value_(0.0)
~fader.value_(1.0)
~fader.value_(255.0)

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


Quarks.gui

// Install Quarks.
// From a fresh install of SC 3.7, I had to install the following quarks for rover to run:
//   KMeans
//   SenseWorld
//   Ctk
//   arduino
//
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");


// Read in presets.
Archive.read("/Volumes/Work/Projects/lightfield/supercollider/preset_backups/COMBINED_presets/ALL_SCENES_150603_120355.sctxar")

GrainScanner1.presets.keys
GrainScanner2.presets.keys
Archive.global[\roverPresets].keys

// Start refocuser on remote machine
("ssh refocuser.local 'export DISPLAY=:0; /home/rtwomey/refocuser-videowall/bin/refocuser-videowall'").unixCmd;

// Stop refocuser
("ssh refocuser.local 'killall refocuser-videowall'").postln;//unixCmd;
