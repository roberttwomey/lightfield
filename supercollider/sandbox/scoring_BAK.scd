// SCORING

//get audio initialized
s.boot
~eq = MasterEQ(4);

/* source file */
p = "/Users/admin/src/rover/data/AUDIO/EDITS/around_the_dining_room_morning_EDIT.WAV";

/* GrainScanner1 with 3 GrainScan1's */
~gs1 = GrainScanner1( 3, p )
~gs1.presetGUI(3)

~gs2 = GrainScanner2( 0, p )

3.do{|i|~gs2.addScanner(i)} // add scanners
~gs2.presetGUI(5)

~gs1.backupPreset

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
	"./textures/mike3.xml"
];

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
	\mike1_1,
	\mike1_2,
	\mike1_3,
	\mike1_4,
	\mike1_5_fruitbowl,
	\mike1_rover_mirror,
	\mike1_rover_rover
];

var audioSceneDict = IdentityDictionary(know: true).putPairs([
	\diningroom3, \int_,
	\mike1, \int_,
	\mike3, \int_,

	\dark_trees, \nightCD_,
	\carkeek, \sea_,
	\cliffside, \cliff1_,
	\tunnel, \sea_,
	\carkeek_night, \sea_,
	\outsidelookingin, \night_,
	\mike2, \garden_,
	\yellowcliff, \yellow_,
]);


~sceneScore = [
	// scene params
	//scene, dur, numViews

	// int
	["diningroom3", 90, 4],
	["mike3", 130, 4],
	// ext
	["tunnel", 150, 4],
	// int
	["mike3", 110, 3],
	["mike1", 150, 3],
	// ext
	["cliffside", 108, 4],
	// liminal
	["mike2", 90, 4],

	["diningroom3", 90, 3],
];



r = Task({
	var name, fade, waittime;

	inf.do { |i|
		~sceneScore.do{ |sceneParams|
			var scene, dur, nViews, sceneFileName, audioScene, whichScanner;
			var fadeOut = 3, fadeIn = 3, viewPresets, sceneType;
			#scene, dur, nViews = sceneParams;

			// fade out
			~fader.fadeTime_(fadeOut);
			~fader.value_(1.0);
			[~gs1, ~gs2].do(_.release(fadeOut));
			(fadeOut+1).wait;

			// load scene
			sceneFileName = format("./textures/%.xml", scene);
			c.loadScene(format("./textures/%.xml", scene)); //video

			interiors.collect(_.asSymbol).includes(sceneFileName.asSymbol).if({
				"new scene is INTERIOR".postln;
				sceneType = \int;
			},{
				"new scene is EXTERIOR".postln;
				sceneType = \ext;
			});

			// fade in
			~fader.fadeTime_(fadeIn+2);
			~fader.value_(0.0);

			// choose the views within the scene
			viewPresets = presets.scramble.keep(nViews);

			viewPresets.do { |vPreset, i|
				var viewDur, transition, linger;
				viewDur = dur/nViews; // equal time on each view
				transition = rrand(0.3, 0.7) * viewDur;
				linger = viewDur - transition;

				switch( sceneType,
					\int, {
						audioScene = ~gs1.presets.keys.choose; // choose between interiors
						whichScanner = ~gs1;
					},
					\ext, {
						var audioKey;
						audioKey = audioSceneDict[scene.asSymbol];
						postf("audioKey: %\n", audioKey);
						audioScene = GrainScanner2.presets.keys.asArray.collect(_.asString).select({
							|pset| pset.contains(audioKey.asString)}).choose.asSymbol;
						whichScanner = ~gs2;
					}
				);

				postf("chose audio scene %\n", audioScene);

				if(i == 0) {
					"recalling audio scene immediately".postln;
					whichScanner.recallPreset( audioScene, 0 );
					"fading audio in".postln;
					whichScanner.play(fadeIn);
				}{
					postf("recalling audio scene over % seconds\n", transition);
					whichScanner.recallPreset(audioScene, transition);
				};

				// RECALL video
				postf("recalling scene %, preset %\n", scene, vPreset);
				c.recallPreset(vPreset, transition);

				postf("waiting % seconds for view to play out\n", viewDur);
				(transition + linger).wait;
			};
		};
	}
});
)

r.play
r.run
r.stop

~gs1.free
~gs2.free