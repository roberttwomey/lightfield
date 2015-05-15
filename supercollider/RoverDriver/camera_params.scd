// faking it
r = ()
r.camAddr = NetAddr("rover.local", 9000)

// DEFAULT
r.camAddr.sendMsg("/camera", "paramsnap", "-t 1 -o /home/pi/lfimages/testThisMutha.jpg")

// PNG ENCODING, -e png
// lossless copression png, but much slower than jpg, and larger (7MB vs 2.5MB)
r.camAddr.sendMsg("/camera", "paramsnap", "-t 1 -o /home/pi/lfimages/testThisMutha.png -e png")

// DISABLE PREVIEW, -n
// probably useful
r.camAddr.sendMsg( "/camera", "paramsnap", format("-t 1 -o /home/pi/lfimages/%.jpg -n", Date.getDate.rawSeconds) )


r.camAddr.sendMsg( "/camera", "paramsnap", format("-t 1 -o /home/pi/lfimages/%.jpg -n -sh 50 -ex antishake -mm average", Date.getDate.rawSeconds) )


// SHARPNESS - useful!, -sh 50
// sharpness -100 > 100, def 0

// EXPOSURE, -ex night
// auto
// night
// backlight
// spotlight
// sports
// snow
// beach
// verylong
// antishake
// fireworks

// BRIGHTNESS, -br 0
// 0>100, def 0

// CONTRAST, -co 0
// -100 > 100, def 0

// SATURATION, -sa 0
// -100 > 100, def 0


// ISO, -ISO 100
// 100 > 800, def ?

// AUTO WHITE BALANCE, -awb auto
// off
// auto
// sun
// cloud
// shade
// tungsten
// fluorescent
// incandescent
// horizon


// METERING, -mm average
// average
// spot
// backlit
// matrix

// DYNAMIC RANGE COMPRESSION, -drc medium
// off
// low
// medium
// high

// DISPLAY IMAGE STATISTICS
r.camAddr.sendMsg("/camera", "paramsnap", "-t 1 -o /home/pi/lfimages/myImageStats.jpg -n -st")

// BOOOOOO
r.camAddr.sendMsg("/camera", "paramsnap", "-t 1 -o /home/pi/lfimages/testThisMuthaBOSS.jpg -n -ifx emboss") // emboss oh boi!
r.camAddr.sendMsg("/camera", "paramsnap", "-t 1 -o /home/pi/lfimages/testThisMuthapasty.jpg -n -ifx pastel") // pasteeeeeel!
