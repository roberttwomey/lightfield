// SCORING

//get audio initialized
s.waitForBoot({
	var intSndPath, extSndPath;

	1.wait;
	~eq = MasterEQ(4,s);

	/* source file */
	intSndPath = "/Users/dxlocal/Documents/ROVER/Rover_audio/EDITS/around_the_dining_room_morning_EDIT.WAV";

	~gs1 !? {~gs1.free};
	~gs2 !? {~gs2.free};

	/* GrainScanner1 with 3 GrainScan1's */
	~gs1 = GrainScanner1( 3, intSndPath );
	~gs1.presetGUI(3);
	3.wait;

	extSndPath = "/Users/dxlocal/Documents/ROVER/Rover_audio/EDITS/discovery_cliffside_1_EDIT.WAV";
	~gs2 = GrainScanner2( 0, extSndPath );
	5.wait;
	3.do{|i|~gs2.addScanner(i)}; // add scanners
	~gs2.presetGUI(5);


	~imageCtl = ControlMixMaster(
		["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ],
		// NetAddr("refocuser.local", 12345));
		NetAddr("localhost", 12345));
	2.wait;
	~imageCtl.mixers.do({ |mxr| mxr.plotter.stop });

	~fader=ControlFade(1.0);
	1.wait;
	~fader.broadcast( ~imageCtl.broadcastNetAddr, '/fade', 30 );
	// ~fader.fadeTime_(6.0);
	// ~fader.value_(1.0)
	// ~fader.value_(0.0)




	// interiors
	~interiors = [
		"./textures/diningroom3.xml",
		"./textures/mike1.xml",
		"./textures/mike3.xml"
	];

	// departures
	~departures = [
		"./textures/dark_trees.xml",
		"./textures/carkeek.xml",
		"./textures/cliffside.xml",
		"./textures/tunnel.xml",
		"./textures/carkeek_night.xml",

	];

	// portals, liminal spaces
	~portals = [
		"./textures/outsidelookingin.xml",
		"./textures/mike2.xml"
	];

	~videoPresets = [
		\mike1_1,
		\mike1_2,
		\mike1_3,
		\mike1_4,
		\mike1_5_fruitbowl,
		\mike1_rover_mirror,
		\mike1_rover_rover
	];

	~audioSceneDict = IdentityDictionary(know: true).putPairs([
		/* interiors */
		\diningroom3, \int_,
		\mike1, \int_,
		\mike3, \int_,

		/* exteriors */
		\dark_trees, \nightCD_,
		\carkeek, \sea_,
		\cliffside, \cliff1_,
		\tunnel, \sea_,
		\carkeek_night, \sea_,
		\outsidelookingin, \night_,
		\mike2, \garden_,
		\yellowcliff, \yellow_,

		/* for one soundfile only */
		// \dark_trees, \cliff1_,
		// \carkeek, \cliff1_,
		// \cliffside, \cliff1_,
		// \tunnel, \cliff1_,
		// \carkeek_night, \cliff1_,
		// \outsidelookingin, \cliff1_,
		// \mike2, \cliff1_,
		// \yellowcliff, \cliff1_,
	]);

	/*tests*/
	~sceneScore = [
		["diningroom3", 15, 4],
		["cliffside", 15, 2],
		["dark_trees", 15, 2.rand+1],
		["carkeek", 15, 2.rand+1],
		["tunnel", 15, 2.rand+1],
		["carkeek_night", 15, 2.rand+1],
		["outsidelookingin", 15, 2.rand+1],
		["mike2", 15, 2.rand+1],
		["yellowcliff", 15, 2.rand+1],
		["mike2", 15, 4],
		["diningroom3", 15, 3],
	];


	// ~sceneScore = [
	// 	// scene params
	// 	//scene, dur, numViews
	//
	// 	// int
	// 	["diningroom3", 130, 4],
	// 	["mike3", 130, 4],
	// 	// ext
	// 	["tunnel", 150, 4],
	// 	// int
	// 	["mike3", 110, 3],
	// 	["mike1", 150, 3],
	// 	// ext
	// 	["cliffside", 108, 3],
	// 	["carkeek", 78, 3],
	//
	// 	// liminal
	// 	["mike2", 90, 4],
	// 	["diningroom3", 90, 3],
	// ];


	~scoreTask !? {~scoreTask.stop.clock.clear};

	~scoreTask = Task({
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
				~imageCtl.loadScene(format("./textures/%.xml", scene)); //video

				~interiors.collect(_.asSymbol).includes(sceneFileName.asSymbol).if({
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
				viewPresets = ~videoPresets.scramble.keep(nViews);

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
							audioKey = ~audioSceneDict[scene.asSymbol];
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
						fork({
							if( sceneType == \ext, {2.wait});
							whichScanner.play(fadeIn) }, AppClock);
					}{
						postf("recalling audio scene over % seconds\n", transition);
						whichScanner.recallPreset(audioScene, transition);
					};

					// RECALL video
					postf("recalling scene %, preset %\n", scene, vPreset);
					~imageCtl.recallPreset(vPreset, transition);

					postf("waiting % seconds for view to play out\n", viewDur);
					(transition + linger).wait;
				};
			};
		}
	}, AppClock);


	1.wait;
	~scoreTask.play;
	// ~scoreTask.stop
});