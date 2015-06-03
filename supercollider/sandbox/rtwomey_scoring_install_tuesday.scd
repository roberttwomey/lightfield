// SCORING

//get audio initialized
s.waitForBoot({
	var intSndPath, extSndPath;

	1.wait;
	~eq = MasterEQ(4,s);

	/* source file */
	// intSndPath = "/Users/dxlocal/Documents/ROVER/Rover_audio/EDITS/around_the_dining_room_morning_EDIT.WAV";
	intSndPath = "/Volumes/Work/Projects/lightfield/data/audio/EDITS/around_the_dining_room_morning_EDIT.WAV";

	~gs1 !? {~gs1.free};
	~gs2 !? {~gs2.free};

	/* GrainScanner1 with 3 GrainScan1's */
	~gs1 = GrainScanner1( 3, intSndPath );
	~gs1.presetGUI(3);
	3.wait;

	// extSndPath = "/Users/dxlocal/Documents/ROVER/Rover_audio/EDITS/discovery_cliffside_1_EDIT.WAV";
	extSndPath = "/Volumes/Work/Projects/lightfield/data/audio/EDITS/discovery_cliffside_1_EDIT.WAV";

	~gs2 = GrainScanner2( 0, extSndPath );
	5.wait;
	3.do{|i|~gs2.addScanner(i)}; // add scanners
	~gs2.presetGUI(5);


	~imageCtl = ControlMixMaster(
		["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ],
		NetAddr("192.168.0.100", 12345));
	// NetAddr("refocuser.local", 12345));
	// NetAddr("localhost", 12345));
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
		"./textures/bookcase.xml",
		"./textures/diningroom3.xml",
		"./textures/mike1.xml",
		"./textures/mike3.xml"
	];

	// departures
	~departures = [
		"./textures/dark_trees.xml",
		"./textures/carkeek.xml",
		"./textures/cliffside.xml",
		"./textures/yellowcliff.xml",
		"./textures/tunnel.xml",
		"./textures/carkeek_night.xml",

	];

	// portals, liminal spaces
	~portals = [
		"./textures/mike2.xml",
		"./textures/outsidelookingin.xml"
	];

	~audioSceneDict = IdentityDictionary(know: true).putPairs([
		/* interiors */
		\diningroom3, \int_,
		\mike1, \int_,
		\mike3, \int_,
		\bookcase, \int_,

		/* exteriors */
		\dark_trees, \nightCD_,
		\carkeek, \sea_,
		\cliffside, \cliff1_,
		\tunnel, \sea_,
		\carkeek_night, \sea_,
		\yellowcliff, \yellow_,

		/* liminal spaces */
		\outsidelookingin, \night_,
		\mike2, \garden_,

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
	/*	~sceneScore = [
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
	];*/

	~sceneScore = [
		// scene params
		//scene, dur, numViews
		// ext
		["dark_trees", 120, 3],
		//int
		["bookcase", 120, 3],
		// int
		["diningroom3", 130, 4],
		["mike3", 130, 4],
		// ext
		// ["tunnel", 150, 4],
		// int
		["mike3", 110, 3],
		["mike1", 150, 3],
		// ext
		["cliffside", 108, 3],
		// ["carkeek", 78, 3],

		// liminal
		["mike2", 90, 4],
		["diningroom3", 90, 3],
	];

	~sceneViews = IdentityDictionary(know: true).putPairs([
		\dark_trees,
		[
			\dark_trees_whitetree, 5.0, 5.0,
			\dark_trees_start, 5.0, 5.0,
			\dark_trees_deepzoom, 5.0, 5.0,
			\dark_trees_leaves, 5.0, 5.0,
		],
		\bookcase,
		[
			\bookcase_start, 10.0, 15.0,
			\bookcase_bed, 5.0, 5.0,
			\bookcase_doorknob, 5.0, 5.0,
			\bookcase_plant_books, 5.0, 5.0,
			\bookcase_close, 7.0, 5.0,
			\bookcase_mirror_flat, 10.0, 7.0,
			\bookcase_window, 5.0, 5.0,
			\bookcase_mirror, 7.0, 5.0,
			\bookcase_mirror_flat_up, 5.0, 5.0,
			\bookcase_mirror_rover, 5.0, 5.0,
			\bookcase_rover_mobile_selfie, 5.0, 30.0,
			\bookcase_mirror, 15.0, 5.0,
		],
		\cliffside,
		[
			\cliffside_shore, 10.0, 25.0,
			\cliffside_trees_breathing, 35.0, 15.0,
			// \cliffside_greenery_close, 10.0, 25.0,
			\cliffside_right, 10.0, 20.0,
		],
		\yellowcliff,
		[
			\yellowcliff_bush, 5.0, 5.0,
			\yellowcliff_sky_top, 5.0, 5.0,
			\yellowcliff_sky_bot, 5.0, 5.0,
			\yellowcliff_bush_left, 5.0, 5.0,
			\yellowcliff_bush_right, 5.0, 5.0,
			\yellowcliff_close, 5.0, 5.0,
		],
		\mike1,
		[
			\mike1_start, 10.0, 20.0,
			\mike1_1, 10.0, 5.0,
			\mike1_1_rover, 5.0, 5.0,
			\mike1_2, 5.0, 5.0,
			\mike1_3_rover, 5.0, 5.0,
			\mike1_4, 5.0, 5.0,
			\mike1_3, 5.0, 5.0,
			\mike1_5_fruitbowl, 25.0, 15.0,
			// \mike1_5_weird, 5.0, 5.0,
			\mike1_parallax_left, 5.0, 5.0,
			// \mike1_rover_mirror, 5.0, 5.0,
			// \mike1_rover, 5.0, 5.0,
			\mike1_rover_mirror, 10.0, 7.0,
			\mike1_rover_rover, 10.0, 7.0,
			\mike1_window, 5.0, 5.0,
		],
		\mike2,
		[
			\mike2_yellowtunnel, 10.0, 5.0,
			\mike2_swimmingtrees, 3.0, 20.0,
			\mike2_window, 5.0, 5.0,
			\mike2_strings, 15.0, 5.0,
			\mike2_desk_ironingboard, 10.0, 30.0, // **
			\mike2_rover, 5.0, 5.0,
			\mike2_yellowtunnel, 5.0, 5.0
		],
		\mike3,
		[

			\mike3_start, 10.0, 10.0,
			\mike3_fruittable, 10.0, 5.0, // *** abstractish

			// \mike3_lamp, 15.0, 10.0,
			\mike3_book_orbit2, 10.0, 1.0,
			\mike3_book_orbit1, 4.0, 1.0,
			// \mike3_book_orbit3, 5.0, 5.0,
			\mike3_book_orbit4, 4.0, 5.0,
			\mike3_distant_window, 10.0, 15.0, // **
			\mike3_peeker, 10.0, 15.0,
			\mike3_fence, 10.0, 10.0,
			\mike3_windowplane, 10.0, 10.0, // **
			\mike3_cloth_table, 5.0, 5.0,
			\mike3_cloth_table_pull, 5.0, 5.0,
			\mike3_sputnik, 10.0, 5.0,
			\mike3_lamp, 15.0, 10.0,
			\mike3_lamp_glow, 5.0, 5.0,
			\mike3_lamp_glow_2, 5.0, 5.0,
			\mike3_lamp_glow_3, 5.0, 5.0,
		],
		\outsidelookingin,
		[
			\outside_1, 5.0, 5.0,
			\outside_2, 5.0, 5.0,
			\outside_book, 5.0, 5.0,
			\outside_book_left, 5.0, 5.0,
			// \outside_book, 5.0, 5.0,
			// \outside_book_left, 5.0, 5.0,
		],
		\carkeek,
		[
			\carkeek_train_blur, 5.0, 1.0,
			\carkeek_train_start, 5.0, 1.0,
			\carkeek_train1, 1.0, 1.0,
			\carkeek_train2, 1.0, 1.0,
			\carkeek_train3, 1.0, 1.0,
			\carkeek_train4, 1.0, 1.0,
			\carkeek_pile, 5.0, 7.0,
			\carkeek_pile_distant, 5.0, 7.0
		],
		\diningroom3,
		[
			\diningroom3_kaleid, 15.0, 15.0,
			\diningroom3_detail_books_nofocus, 10.0, 5.0,
			\diningroom3_detail_books_focus, 5.0, 5.0,
			\diningroom3_books3, 5.0, 5.0,
			\diningroom3_books4, 5.0, 5.0,
			\diningroom3_flower, 5.0, 10.0,
			\diningroom3_floor, 10.0, 10.0
		]
	]);

	~scoreTask !? {~scoreTask.stop.clock.clear};

	~scoreTask = Task({
		var name, fade, waittime;

		inf.do { |i|
			~sceneScore.do{ |sceneParams|
				var scene, dur, nViews, sceneFileName, audioScene, whichScanner;
				var fadeOut = 3, fadeIn = 3, viewPresets, sceneType;
				var tempPreset, tempTransition, tempLinger;
				#scene, dur, nViews = sceneParams;

				// fade out
				~fader.fadeTime_(fadeOut);
				~fader.value_(1.0);
				[~gs1, ~gs2].do(_.release(fadeOut));
				(fadeOut+1).wait;

				// load scene
				sceneFileName = format("./textures/%.xml", scene);
				~imageCtl.loadScene(format("./textures/%.xml", scene));
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
				// viewPresets = ~videoPresets.scramble.keep(nViews);
				viewPresets = ~sceneViews[scene.asSymbol].clump(3).scramble.keep(nViews);


				viewPresets.do { |vPreset, i|
					var viewDur, transition, linger;
					viewDur = dur/nViews; // equal time on each view
					transition = 0.0;//rrand(0.3, 0.7) * viewDur;
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

					#tempPreset, tempTransition, tempLinger = vPreset;

					// postf("recalling scene %, preset %\n", scene, vPreset);
					// ~imageCtl.recallPreset(vPreset, transition);
					postf("recalling scene %, preset %\n", scene, tempPreset);
					~imageCtl.recallPreset(tempPreset, transition);

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
