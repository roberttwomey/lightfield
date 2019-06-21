///// NEW

// read in controlmixers for video documentation script
Archive.read("/Volumes/Work/Projects/lightfield/supercollider/preset_backups/ControlMixer_presets/FRIDAY_afternoon_150605_163419.sctxar")

// save his control mixer settings to a variable
~ctlMxrPresets = Archive.global[\roverPresets]

// read in grainscanner presets for video documentation script
Archive.read("/Volumes/Work/Projects/lightfield/supercollider/preset_backups/GrainScanner_presets/archive_BAK_150527_233940_gs1gs2.sctxar")

// add Robert's mixer presets to my Archive
Archive.global.put(\roverPresets, ~ctlMxrPresets )

Archive.global[\roverPresets]

Archive.write(format("/Users/rtwomey/Desktop/archive_BAK_%.sctxar",Date.getDate.stamp))




///// OLD

// read in Robert's backup
// Archive.read( "/Users/admin/src/rover/supercollider/preset_backups/ControlMixer_presets/ControlMixer_fromRobert_150527_203422.sctxar" )


// save his control mixer settings to a variable
~ctlMxrPresets = Archive.global[\roverPresets]

// read in the default Archive
// Archive.read("/Users/dxlocal/Library/Application Support/SuperCollider/archive.sctxar")

// add Robert's mixer presets to my Archive
Archive.global.put(\roverPresets, ~ctlMxrPresets )

// write Archive to default location
Archive.write(format("/Users/admin/Desktop/archive_BAK_%.sctxar",Date.getDate.stamp))



// read in Mike's backup
Archive.read("/Users/admin/src/rover/supercollider/preset_backups/GrainScanner_presets/archive_BAK_150527_233940_gs1gs2.sctxar")



Archive.archiveDir

Archive.write(format("/Users/admin/Desktop/archive_BAK_%.sctxar",Date.getDate.stamp))

GrainScanner1.presets.keys
GrainScanner2.presets.keys
Archive.global[\roverPresets].keys

GrainScanner2.backupPreset


// transferring a set of presets, already joined, to the new machine
// read it in
Archive.read("/Users/dxlocal/Documents/ROVER/Rover_workFiles/preset_backups/COMBINED_presets/archive_BAK_150529_221131_combined_revisedInt.sctxar")

Archive.read("/Users/rtwomey/projects/lightfield/supercollider/preset_backups/COMBINED_presets/ALL_SCENES_150603_120355.sctxar")

// test
GrainScanner1.presets.keys
GrainScanner2.presets.keys
Archive.global[\roverPresets].keys
Archive.global[\roverPresets][\bookcase_bed_knob_plant]

// write it to the default location
Archive.write