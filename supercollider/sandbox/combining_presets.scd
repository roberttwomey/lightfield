// Combining presets from another computer with those on this machine

// 1. read in backup file
// dynamic presets from container tuesday
Archive.read( "/Volumes/Work/Projects/lightfield/supercollider/preset_backups/ControlMixer_presets/container_dynamic_tests_MR_archive.sctxar" )

// 2. save control mixer settings to a variable
~ctlMxrPresets = Archive.global[\roverPresets]

// 3. read in Mike's grain scanner presets
Archive.read( "/Volumes/Work/Projects/lightfield/supercollider/preset_backups/GrainScanner_presets/archive_BAK_150527_233940_gs1gs2.sctxar" )

// 4. add controlmixer presets to my mike's grain scanner presets
Archive.global.put(\roverPresets, ~ctlMxrPresets )

// 5. check that things are there
GrainScanner1.presets.keys
GrainScanner2.presets.keys
Archive.global[\roverPresets].keys

// 6. write global archive to default location
Archive.write

// 7. read in Global default archive
Archive.read

// 8. check that things are there
GrainScanner1.presets.keys
GrainScanner2.presets.keys
Archive.global[\roverPresets].keys

// backup presets


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

// test
GrainScanner1.presets.keys
GrainScanner2.presets.keys
Archive.global[\roverPresets].keys

