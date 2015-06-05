// SCORING

//get audio initialized
s.waitForBoot({
	var interiors, departures, portals, presets, audioSceneDict;
	var extSndPath;

	1.wait;
	~eq = MasterEQ(4,s);


	/* added!! */
	~motorBuf = CtkBuffer.playbuf("/Users/dxlocal/Documents/ROVER_audio/dining_room_capture_EDIT.WAV").load;
	s.sync;
	~motorPB = MotorPlayback(0, ~motorBuf);
	s.sync;


	/* source file */
	p = "/Users/dxlocal/Documents/ROVER_audio/around_the_dining_room_morning_EDIT.WAV";

	~gs1 !? {~gs1.free};
	~gs2 !? {~gs2.free};

	/* GrainScanner1 with 3 GrainScan1's */
	~gs1 = GrainScanner1( 3, p );
	~gs1.presetGUI(3);
	3.wait;

	extSndPath = "/Users/dxlocal/Documents/ROVER_audio/discovery_cliffside_1_EDIT.WAV";
	~gs2 = GrainScanner2( 0, extSndPath );
	5.wait;
	3.do{|i|~gs2.addScanner(i)}; // add scanners
	~gs2.presetGUI(5);


	c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ],
		NetAddr("refocuser.local", 12345)
		// NetAddr("localhost", 12345)
	);
	2.wait;
	c.mixers.do({ |mxr| mxr.plotter.stop });

	~fader=ControlFade(1.0);
	1.wait;
	~fader.broadcast( c.broadcastNetAddr, '/fade', 30 );
	// ~fader.fadeTime_(6.0);
	// ~fader.value_(1.0)
	// ~fader.value_(0.0)


	//// main routine ////
	// var interiors, departures, portals, presets, audioSceneDict;
	// interiors
	interiors = [
		"./textures/diningroom3.xml",
		"./textures/mike1.xml",
		"./textures/mike3.xml"
	];

	// departures
	departures = [
		"./textures/dark_trees.xml",
		"./textures/carkeek.xml",
		"./textures/cliffside.xml",
		"./textures/tunnel.xml",
		"./textures/carkeek_night.xml",

	];

	// portals, liminal spaces
	portals = [
		"./textures/outsidelookingin.xml",
		"./textures/mike2.xml"
	];

	presets = [
		\mike1_1,
		\mike1_2,
		\mike1_3,
		\mike1_4,
		\mike1_5_fruitbowl,
		\mike1_rover_mirror,
		\mike1_rover_rover
	];

	audioSceneDict = IdentityDictionary(know: true).putPairs([
		\diningroom3, \int_,
		\mike1, \int_,
		\mike3, \int_,

		// \dark_trees, \nightCD_,
		// \carkeek, \sea_,
		// \cliffside, \cliff1_,
		// \tunnel, \sea_,
		// \carkeek_night, \sea_,
		// \outsidelookingin, \night_,
		// \mike2, \garden_,
		// \yellowcliff, \yellow_,
		\dark_trees, \cliff1_,
		\carkeek, \cliff1_,
		\cliffside, \cliff1_,
		\tunnel, \cliff1_,
		\carkeek_night, \cliff1_,
		\outsidelookingin, \cliff1_,
		\mike2, \cliff1_,
		\yellowcliff, \cliff1_,
	]);


	~sceneScore = [
		// scene params
		//scene, dur, numViews

		// int
		["diningroom3", 50, 4],
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


	r !? {r.stop.clock.clear};

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

				// fade video in
				~fader.fadeTime_(fadeIn+2);
				~fader.value_(0.0);

				// choose the views within the scene
				viewPresets = presets.scramble.keep(nViews);

				viewPresets.do { |vPreset, viewCount|
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

					/* added!!! */
					if(viewCount == 0)
					{	// first view in new scene

						// recalling audio scene immediately for first view
						whichScanner.recallPreset( audioScene, 0 );

						// wait for audio scene to load if exterior
						if( sceneType == \ext ){ 2.5.wait };

						// play the appropriate scanner
						whichScanner.play(fadeIn);


					}{	// new view in same scene, scanner is already playing

						postf("recalling audio scene over % seconds\n", transition);
						whichScanner.recallPreset(audioScene, transition);
					};

					// if interior, send to reverb after transition
					if( sceneType == \int ){
						fork{ transition.wait; ~gs1.sendToReverb( linger * 0.8)} };

					// RECALL video
					postf("recalling scene %, preset %\n", scene, vPreset);
					c.recallPreset(vPreset, transition);

					// wait to advance to the next scene/view
					postf("waiting % seconds for view to play out\n", viewDur);
					(transition + linger).wait;
				};
			};
		}
	}, AppClock);


	1.wait;
	r.play;
	// r.stop
});