// control mixer

c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ], NetAddr("192.168.2.2", 12345));
// c = ControlMixMaster( ["focus", "zoom", "xscroll", "yscroll", "xstart", "ystart", "xcount", "ycount" ], NetAddr("refocuser.local", 12345));

~fader=ControlFade(1.0);
~fader.broadcast( c.broadcastNetAddr, '/fade', 30 );
~fader.value_(0)

c.backupPreset

// loading from list of snapshot files
(
j =  [
"/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_night/carkeek_night_06021537_0000.txt",
"/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_night/carkeek_night_06021537_0001.txt",
"/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_night/carkeek_night_06021537_0002.txt"
];

postf("\n");
j.do { |fname|
	postf("c.loadSnapshot(\"%\")\n", fname);
	postf("c.storePreset()\n");
};
postf("\n");
)



// search for certain preset
(
q = "tunnel";
c.presets.keys.do { |p|
	p.asString.contains(q).if{ postf("%%, 5.0, 5.0,\n", "\\", p);};
};
)



// create a new preset



// remove a preset
c.presets.removeAtFail(\myFirst)

// load a scene
c.loadScene("./textures/tunnel.xml")



r.stop()
r.reset()
r.play()


(
var start = 0;

thisThread.randSeed=54321;

d = [
	// ballard wall
	// carkeek_night
	// precise
	// tivon1
	// towers
	// tunnel
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
	\carkeek_night,
	[
		\carkeek_night_ground, 5.0, 5.0,
		\carkeek_night_shore, 5.0, 5.0,
		\carkeek_night_hypercolortree, 5.0, 5.0,
		\carkeek_night_oceanblur, 5.0, 5.0,
	],
	\cliffside,
	[
		\cliffside_shore, 10.0, 25.0,
		\cliffside_trees_breathing, 35.0, 15.0,
		// \cliffside_greenery_close, 10.0, 25.0,
		\cliffside_right, 10.0, 20.0,
	],
	\dark_trees,
	[
		\dark_trees_whitetree, 5.0, 5.0,
		\dark_trees_start, 5.0, 5.0,
		\dark_trees_deepzoom, 5.0, 5.0,
		\dark_trees_leaves, 5.0, 5.0,
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
	\yellowcliff,
	[
		\yellowcliff_bush, 5.0, 5.0,
		\yellowcliff_sky_top, 5.0, 5.0,
		\yellowcliff_sky_bot, 5.0, 5.0,
		\yellowcliff_bush_left, 5.0, 5.0,
		\yellowcliff_bush_right, 5.0, 5.0,
		\yellowcliff_close, 5.0, 5.0,
	],

].clump(2);

r = Task ({
	// d = d.scramble();
	d = d.rotate(-1 * start);
	d.do { |params|
		var scene, sceneType, views;
		var fadeOut = 3, fadeIn = 3, loadTime = 10;
		#scene, views = params;
		views = views.clump(3);

		// fade out
		~fader.fadeTime_(fadeOut);
		~fader.value_(1.0);
		(fadeOut+1).wait;

		// load sceen
		c.loadScene(scene);
		postf("load scene: %\n", scene);
		loadTime.wait;

		// fade in
		~fader.fadeTime_(fadeIn+2);
		~fader.value_(0.0);
		(fadeIn+1).wait;

		// iterate over views
		views.do{ |vals|
			var preset, fadetime, waittime;
			#preset, fadetime, waittime = vals;
			c.recallPreset(preset, fadetime);
			(fadetime + waittime).wait;
		}
	};

}).play();

)

r.stop()

r.play()
r.reset()


c.updatePreset

// snapshots
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/yellowcliff/yellowcliff_0002.txt")

c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/outsidelookingin_tex_0000.txt")
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/outsidelookingin_tex_0001.txt")
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/outsidelookingin_tex_0004.txt")
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/outsidelookingin_tex_0005.txt")


// c.loadScene("./textures/tivon1_calib.xml")
// c.loadScene("./textures/tivon2_sm.xml")

// c.loadScene("./textures/ballard_wall_sm.xml")

// c.loadScene("./textures/carkeek_med_tile.xml")


// presets
c.loadScene("./textures/yellowcliff.xml")
// c.storePreset( \yellowcliff_close)
// c.storePreset( \yellowcliff_bush)


// oops I deleted this:
// c.storePreset( \tivon1 )
// c.storePreset( \tivon1_lights )
// c.storePreset( \tivon1_mirror )
c.globalFadeTime_(3)



// c.storePreset(\mike1_rover_mirror, true)
// c.storePreset(\mike1_rover_rover, true)

c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/mike1_laptop_0002.txt")
c.recallPreset(\mike1_rover_mirror)
10.wait();
c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/mike1_laptop_0003.txt")
c.recallPreset(\mike1_rover_rover)


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



// BOOKCASE

// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/bookcase_0000.txt")
// c.storePreset(\bookcase_close)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/bookcase_0006.txt")
// c.storePreset(\bookcase_bed)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/bookcase_0007.txt")
// c.storePreset(\bookcase_mirror)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/diningroom3_0008.txt")

// [
// 	"./textures/bookcase.xml",
// 	[
// bookcase_rover_mobile_selfie, 5.0, 5.0,
// bookcase_mirror_flat, 5.0, 5.0,
// bookcase_close, 5.0, 5.0,
// bookcase_start, 5.0, 5.0,
// bookcase_window, 5.0, 5.0,
// bookcase_bed, 5.0, 5.0,
// bookcase_mirror_rover, 5.0, 5.0,
// bookcase_doorknob, 5.0, 5.0,
// bookcase_mirror, 5.0, 5.0,
// bookcase_mirror_flat_up, 5.0, 5.0,
// 	]
// ]


// MIKE3 TILED

// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3_tiled/20150521211423_0000.txt")
// c.storePreset(\mike3_fruittable)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3_tiled/20150521211452_0001.txt")
// c.storePreset(\mike3_distant_window)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3_tiled/20150521211515_0002.txt")
// c.storePreset(\mike3_cloth_table)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3_tiled/20150521211546_0003.txt")
// c.storePreset(\mike3_cloth_table_pull)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3_tiled/20150521211704_0004.txt")
// c.storePreset(\mike3_lamp_glow)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3_tiled/20150521211736_0005.txt")
// c.storePreset(\mike3_lamp_glow_2)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3_tiled/20150521211854_0006.txt")
// c.storePreset(\mike3_lamp_glow_3)

// MIKE3
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3/mike3_05301111_0000.txt")
// c.storePreset(\mike3_lamp)
//
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3/mike3_05301247_0000.txt")
// c.storePreset(\mike3_book_orbit1)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3/mike3_05301247_0001.txt")
// c.storePreset(\mike3_book_orbit2)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3/mike3_05301247_0002.txt")
// c.storePreset(\mike3_book_orbit3)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike3/mike3_05301247_0003.txt")
// c.storePreset(\mike3_book_orbit4)
//
// c.storePreset(\mike3_fence)
// c.storePreset(\mike3_windowplane)
// c.storePreset(\mike3_sputnik)
// c.storePreset(\mike3_start)
// c.storePreset(\mike3_peeker)
// [
// 	"./textures/mike3.xml",
// 	[
// 		\mike3_lamp, 5.0, 5.0,
// 		\mike3_book_orbit1, 5.0, 5.0,
// 		\mike3_book_orbit2, 5.0, 5.0,
// 		\mike3_book_orbit3, 5.0, 5.0,
// 		\mike3_book_orbit4, 5.0, 5.0,
// 		\mike3_fruittable, 5.0, 5.0,
// 		\mike3_distant_window, 5.0, 5.0,
// 		\mike3_cloth_table, 5.0, 5.0,
// 		\mike3_cloth_table_pull, 5.0, 5.0,
// 		\mike3_lamp_glow, 5.0, 5.0,
// 		\mike3_lamp_glow_2, 5.0, 5.0,
// 		\mike3_lamp_glow_3, 5.0, 5.0,
// 	]
// ]


// MIKE1

// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/mike1_0000.txt")
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/mike1_0001.txt")
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/mike1_0002.txt")
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/orbits/mike1_0003.txt")
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/mike1_0002.txt")
// c.storePreset(\mike1_window)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/mike1_0003.txt")
// c.storePreset(\mike1_rover)
//
// c.loadScene("./textures/mike1.xml");
//
//
// p = [
// 	"./textures/mike1.xml",
// 	[
// 		\mike1_1, 5.0, 5.0,
// 		\mike1_2, 5.0, 5.0,
// 		\mike1_3, 5.0, 5.0,
// 		\mike1_4, 5.0, 5.0,
// 		\mike1_5_fruitbowl, 5.0, 5.0,
// 		\mike1_5_weird, 5.0, 5.0,
// 		\mike1_parallax_left, 5.0, 5.0,
// 		\mike1_rover_mirror, 5.0, 5.0,
// 		\mike1_window, 5.0, 5.0,
// 		\mike1_rover_rover, 5.0, 5.0,
// 		\mike1_rover, 5.0, 5.0,
// 	]
// ];


// CARKEEK

// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek/carkeek_05301108_0000.txt")
// c.storePreset(\carkeek_pile)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek/carkeek_05301109_0000.txt")
// c.storePreset(\carkeek_pile_distant)
//
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek/carkeek_0000.txt")
// c.storePreset(\carkeek_train_blur)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek/carkeek_0001.txt")
// c.storePreset(\carkeek_train_start)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek/carkeek_0002.txt")
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek/carkeek_0003.txt")
//
//
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_train/05221118_0000.txt")
// c.storePreset(\carkeek_train1)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_train/05221118_0001.txt")
// c.storePreset(\carkeek_train2)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_train/05221118_0002.txt")
// c.storePreset(\carkeek_train3)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_train/05221118_0003.txt")
// c.storePreset(\carkeek_train4)
//
// p = [
// 	\carkeek_train_blur, 5.0, 1.0,
// 	\carkeek_train_start, 5.0, 1.0,
// 	\carkeek_train1, 1.0, 1.0,
// 	\carkeek_train2, 1.0, 1.0,
// 	\carkeek_train3, 1.0, 1.0,
// 	\carkeek_train4, 1.0, 1.0,
// 	\carkeek_pile, 5.0, 7.0,
// 	\carkeek_pile_distant, 5.0, 7.0
// ].clump(3);


// MIKE2 looking in

// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike2_portal/0000.txt")
// c.storePreset(\mike2_yellowtunnel)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/mike2_portal/0001.txt")
// c.storePreset(\mike2_window)
// c.storePreset(\mike2_rover)
//
// p = [
// 	"./textures/mike2.xml",
// 	[
// 		\mike2_yellowtunnel, 5.0, 5.0,
// 		\mike2_window, 5.0, 5.0,
// 		\mike2_rover, 5.0, 5.0,
// 		\mike2_yellowtunnel, 5.0, 5.0
// 	]
// ];



// OUTSIDE LOOKING IN
//
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/outsidelookingin/20150521163332_0000.txt")
// c.storePreset()
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/outsidelookingin/20150521163356_0001.txt")
// c.storePreset(\outside_1)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/outsidelookingin/20150521163400_0002.txt")
// c.storePreset(\outside_2)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/outsidelookingin/20150521163417_0003.txt")
// c.storePreset(\outside_book)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/outsidelookingin/20150521163452_0004.txt")
// c.storePreset(\outside_book_left)
//
// p = [
// 	"./textures/outsidelookingin.xml",
// 	[
//
// 		\outside_1, 5.0, 5.0,
// 		\outside_2, 5.0, 5.0,
// 		\outside_book, 5.0, 5.0,
// 		\outside_book_left, 5.0, 5.0,
// 		\outside_book, 5.0, 5.0,
// 		\outside_book_left, 5.0, 5.0,
// 	]
// ];


// DINING ROOM 3

// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/diningroom3_0004.txt")
// c.storePreset(\diningroom3_kaleid)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/diningroom3_0005.txt")
// c.storePreset(\diningroom3_detail_books_nofocus)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/diningroom3_0006.txt")
// c.storePreset(\diningroom3_detail_books_focus)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/diningroom3_0007.txt")
// c.storePreset(\diningroom3_books3)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/diningroom3_0008.txt")
// c.storePreset(\diningroom3_books4)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/diningroom3_0009.txt")
// c.storePreset(\diningroom3_flower)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/20150524/diningroom3_0010.txt")
// c.storePreset(\diningroom3_floor)
//
// c.loadScene("./textures/diningroom3.xml");

//
// p = [
// 	"./textures/diningroom3.xml",
// 	[
// 		\diningroom3_kaleid, 3.0, 15.0,
// 		\diningroom3_detail_books_nofocus, 10.0, 5.0,
// 		\diningroom3_detail_books_focus, 5.0, 5.0,
// 		\diningroom3_books3, 5.0, 5.0,
// 		\diningroom3_books4, 5.0, 5.0,
// 		\diningroom3_flower, 5.0, 10.0,
// 		\diningroom3_floor, 10.0, 10.0
// 	]
// ];
//


// BOOKCASE


// YELLOWCLIFF
//
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/yellowcliff/yellowcliff_05311545_0000.txt")
// c.storePreset(\yellowcliff_bush)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/yellowcliff/yellowcliff_05311601_0000.txt")
// c.storePreset(\yellowcliff_sky_top)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/yellowcliff/yellowcliff_05311602_0000.txt")
// c.storePreset(\yellowcliff_sky_bot)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/yellowcliff/yellowcliff_05311605_0000.txt")
// c.storePreset(\yellowcliff_bush_left)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/yellowcliff/yellowcliff_05311605_0001.txt")
// c.storePreset(\yellowcliff_bush_right)
//
// [
// 	"./textures/yellowcliff.xml",
// 	[
// 		\yellowcliff_bush, 5.0, 5.0,
// 		\yellowcliff_sky_top, 5.0, 5.0,
// 		\yellowcliff_bush_left, 5.0, 5.0,
// 		\mike2_yellowtunnel, 5.0, 5.0,
// 		\yellowcliff_bush_right, 5.0, 5.0,
// 		\yellowcliff_sky_bot, 5.0, 5.0,
// 		\yellowcliff_close, 5.0, 5.0,
// 	]
// ]


// CLIFFSIDE
//
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/cliffside/cliffside_05311717_0000.txt")
// c.storePreset(\cliffside_greenery_close)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/cliffside/cliffside_05311717_0001.txt")
// c.storePreset(\cliffside_shore)
// \cliffside_right
//
// [
// 	"./textures/cliffside.xml",
// 	[
// 		\cliffside_shore, 5.0, 30.0,
// 		\cliffside_greenery_close, 5.0, 30.0,
// 		\cliffside_right, 5.0, 30.0,
// 	]
// ],


// CARKEEK NIGHT
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_night/carkeek_night_06021537_0000.txt")
// c.storePreset(\carkeek_night_shore, true)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_night/carkeek_night_06021537_0001.txt")
// c.storePreset(\carkeek_night_oceanblur)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_night/carkeek_night_06021537_0002.txt")
// c.storePreset(\carkeek_night_ground)
// c.loadSnapshot("/Volumes/Work/Projects/lightfield/scenes/scratch/carkeek_night/carkeek_night_06021609_0000.txt")
// c.storePreset(\carkeek_night_hypercolortree)

// scenes

/*

// interiors

<scene>./textures/mike1.xml</scene>
<scene>./textures/mike2.xml</scene>
<scene>./textures/mike3.xml</scene>
<scene>./textures/diningroom3.xml</scene>


// departures
// desaturate?

<scene>./textures/dark_trees.xml</scene>
<scene>./textures/outsidelookingin.xml</scene>
<scene>./textures/carkeek.xml</scene>
<scene>./textures/bookcase.xml</scene>


// outtakes
<scene>./textures/cliffside.xml</scene>
<scene>./textures/tunnel.xml<	/scene>
<scene>./textures/yellowcliff.xml</scene>


<scene>./textures/precise.xml</scene>
<scene>./textures/towers.xml</scene>
<scene>./textures/ballard_wall.xml</scene>
<scene>./textures/carkeek_night.xml</scene>

*/
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
