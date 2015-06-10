// twomey work file


c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ], NetAddr("refocuser.local", 12345));


~fader=ControlFade(1.0);
~fader.broadcast( c.broadcastNetAddr, '/fade', 30 );
~fader.fadeTime_(6.0);
~fader.value_(1.0)
~fader.value_(0.0)

// 	"./textures/mike2.xml",

(
//// main routine ////

// interiors
var interiors = [
	"./textures/diningroom3.xml",
	"./textures/mike1.xml",
"./textures/mike3.xml"];

//bookcase
var scenes;

// departures
var departures = [
	"./textures/dark_trees.xml",
	"./textures/carkeek.xml",
	"./textures/cliffside.xml",
	"./textures/tunnel.xml",
	"./textures/carkeek_night.xml",

];

// portals, liminal spaces

var portals = [
	"./textures/outsidelookingin.xml",
	"./textures/mike2.xml"
];

var presets = [
	\mike1_1, 15.0, 10.0,
	\mike1_2, 15.0, 10.0,
	\mike1_3, 15.0, 10.0,
	\mike1_4, 15.0, 10.0,
	\mike1_5_fruitbowl, 15.0, 10.0,
	\mike1_rover_mirror, 15.0, 10.0,
	\mike1_rover_rover, 15.0, 10.0].clump(3);

// scenes = scenes.rotate(2);
scenes = interiors;

r = Task ({
	var name, fade, waittime;

	inf.do { |i|
		scenes.do{ |scene|
			// fade out
			~fader.value_(1.0);

			// load scene
			c.loadScene(scene);

			// fade in
			~fader.value_(0.0);

			// hit positions
			presets.do { |eventarray|

				eventarray.postln;
				#name, fade, waittime = eventarray;
				// [name, fade, waittime].postln;
				// name.postln;
				c.recallPreset(name, fade);
				(fade+waittime).wait;
			};
		};
	}
});
)

r.play
r.run
r.stop


c.backupPreset


// sound

// chatty thing
// events, dwell
// swell (less chatty, more texture)