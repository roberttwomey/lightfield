"ssh pi@rover2.local kill -USR1 1629".unixCmd
"ssh pi@rover2.local -t 'kill -USR1 1629'".unixCmd
unixCmd("ssh" + "pi@rover2.local -t".quote + "kill -USR1 $(pgrep raspistill)".quote)
"ssh pi@rover2.local -t 'kill -USR1 1629; exec $SHELL -l'".unixCmd


a = unixCmd("ssh pi@rover2.local 'test -e image0004.jpg && echo"+"true".quote+"|| echo"+"false".quote+"'")
a = ("ssh pi@rover2.local 'test -e image0004.jpg && echo"+"true".quote+"|| echo"+"false".quote+"'").unixCmd({|...args| "received".postln; args.postln; \n.post; })


// Take a photo once raspistill has started - WORKS
// make sure you've created and logged your authentication keys:
// http://www.vineetmanohar.com/2009/07/howto-ssh-without-password/
// (instead of 'vi', use 'nano' for editing the text file)
unixCmd("ssh pi@rover2.local 'kill -USR1 $(pgrep raspistill)'")


a = ("ssh pi@rover2.local pgrep raspistill").unixCmdGetStdOut
~pid = a.split[0].asInt

unixCmd("ssh pi@rover2.local 'kill $(pgrep raspistill)'")

(// find out of the file was created by getting stdout from this test:
a = ("ssh pi@rover2.local 'test -e /home/pi/lfimages/image0004.jpg && echo"+"true".quote+"|| echo"+"false".quote+"'").unixCmdGetStdOut;
a.contains("true").postln;
"done".postln;
nil
)


pid

// faking it
r = ()
r.camAddr = NetAddr("rover2.local", 9000)

/*
To get into the pi:
longthinwire:~ admin$ ssh pi@rover2.local
pw: raspberry

To open an xterm window, from which to issue commands and open multiple windows
in the same shell
longthinwire:~ lxterminal &

If this doesn't work, replace lxterminal with another available terminal, which you
can find by running:
cd /usr/bin;ls *term*

kill it
kill $(pgrep raspistill)

take a photo once raspistill is running in signal (-s) mode:
$ kill -USR1 $(pgrep raspistill)
*/

/*
Taking a snapshot from the terminal:

raspistill -o /home/pi/lfimages/tester.jpg -t 2000 // have raspistill program open for 2000ms
raspistill -o /home/pi/lfimages/tester.jpg -t 2000 -n// no preview


*/


// DEFAULT
r.camAddr.sendMsg("/camera", "paramsnap", "-o /home/pi/lfimages/testThisMutha.jpg")
r.camAddr.sendMsg("/camera", "paramsnap", "-o /home/pi/lfimages/testThisMutha.jpg")
r.camAddr.sendMsg("/camera", "start")
r.camAddr.sendMsg("/camera", "snap")
r.camAddr.sendMsg("/camera", "exit")

// PNG ENCODING, -e png
// lossless copression png, but much slower than jpg, and larger (7MB vs 2.5MB)
r.camAddr.sendMsg("/camera", "paramsnap", "-t 1 -o /home/pi/lfimages/testThisMutha.png -e png")

// DISABLE PREVIEW, -n
// probably useful
r.camAddr.sendMsg( "/camera", "paramsnap", format("-t 1 -o /home/pi/lfimages/%.jpg -n", Date.getDate.rawSeconds) )
r.camAddr.sendMsg( "/camera", "paramsnap", format("-t 1 -o /home/pi/lfimages/%.jpg -n -ss 12000", Date.getDate.rawSeconds) )


r.camAddr.sendMsg( "/camera", "paramsnap", format("-t 1 -o /home/pi/lfimages/%.jpg -n -sh 25 -ex snow -mm average -awb sun -ss 1400", Date.getDate.rawSeconds) )

r.camAddr.sendMsg( "/camera", "paramsnap", format("-t 1 -o /home/pi/lfimages/%.jpg -n -ex snow -mm average", Date.getDate.rawSeconds) )

--sharpness,    -sh     Set image sharpness (-100 to 100); 0 is the default.
--contrast, -co     Set image contrast (-100 to 100); 0 is the default.
--brightness,   -br     Set image brightness (0 to 100); 50 is the default. 0 is black, 100 is white.
--saturation,   -sa     Set image saturation (-100 to 100) - 0 is the default.
--ISO,  -ISO        Set capture ISO -  Range is 100 to 800.
--vstab,    -vs     Turn on video stabilisation; In video mode only, turn on video stabilisation.
--ev,   -ev     Set EV compensation; Range is -10 to +10, default is 0.
--exposure, -ex     Set exposure mode; Possible options are:
[
	auto Use automatic exposure mode
	night Select setting for night shooting
	nightpreview
	backlight Select setting for back lit subject
	spotlight
	sports Select setting for sports (fast shutter etc)
	snow Select setting optimised for snowy scenery
	beach Select setting optimised for beach
	verylong Select setting for long exposures
	fixedfps Constrain fps to a fixed value
	antishake Antishake mode
	fireworks Select settings
]

--awb,  -awb        Set Automatic White Balance (AWB) mode
[
    off Turn off white balance calculation
    auto Automatic mode (default)
    sun Sunny mode
    cloud Cloudy mode
    shade Shaded mode
    tungsten Tungsten lighting mode
    fluorescent Fluorescent lighting mode
    incandescent Incandescent lighting mode
    flash Flash mode
    horizon Horizon mode
]

--metering, -mm     Set metering mode for the preview and capture
[
    average Average the whole frame for metering.
    spot Spot metering
    backlit Assume a backlit image
    matrix Matrix metering
]

--roi,  -roi        Set sensor region of interest
Allows the specification of the area of the sensor to be used as the source for
the preview and capture. This is defined as x,y for the top left corner, and a width
and height, all values in normalised coordinates (0.0-1.0). So to set a ROI at half way
across and down the sensor, and a width and height of a quarter of the sensor use:
ex: -roi 0.5,0.5,0.25,0.25

--shutter,  -ss     Set shutter speed (in microseconds).
There is currently an upper limit of approximately 6000000us (6000ms, 6s) past which
operation is undefined.

--drc,  -drc        Enable/Disable Dynamic Range compression
DRC changes the images by increasing the range of dark areas of the image,
and decreasing the brighter areas. This can improve the image in low light areas.
[
    off
    low
    medium
    high
]

--mode, -md
Sets a specified sensor mode, disabling the automatic selection. Possible values are :
[
	Mode 	Size 	Aspect Ratio 	Frame rates 	FOV 	Binning
	0 	automatic selection
	1 	1920x1080 	16:9 	1-30fps 	Partial 	None
	2 	2592x1944 	4:3 	1-15fps 	Full 	None
	3 	2592x1944 	4:3 	0.1666-1fps 	Full 	None
	4 	1296x972 	4:3 	1-42fps 	Full 	2x2
	5 	1296x730 	16:9 	1-49fps 	Full 	2x2
	6 	640x480 	4:3 	42.1-60fps 	Full 	2x2 plus skip
	7 	640x480 	4:3 	60.1-90fps 	Full 	2x2 plus skip
]

RASPISTILL specific settings

--width,    -w      Set image width <size>

--height,   -h      Set image height <size>

--quality,  -q      Set jpeg quality <0 to 100>
Quality 100 is almost completely uncompressed. 75 is a good all round value

--raw,  -r      Add raw bayer data to jpeg metadata
This option inserts the raw Bayer data from the camera in to the JPEG metadata

--output,   -o      Output filename <filename>.
Specify the output filename. If not specified, no file is saved. If the
filename is '-', then all output is sent to stdout.

--latest,   -l      Link latest frame to filename <filename>
Make a file system link under this name to the latest frame.

--verbose,  -v      Output verbose information during run
Outputs debugging/information messages during the program run.

--timeout,  -t      Time before takes picture and shuts down.
The program will run for this length of time, then take the capture
(if output is specified). If not specified, this is set to 5 seconds.

--timelapse,    -tl     time-lapse mode.
The specific value is the time between shots in milliseconds. Note you should
specify %04d at the point in the filename where you want a frame count
number to appear. e.g:

-t 30000 -tl 2000 -o image%04d.jpg

will produce a capture every 2 seconds, over a total period of 30s,
named image0001.jpg, image0002.jpg..image0015.jpg. Note that the %04d
indicates a 4 digit number with leading zero's added to pad to the required
number of digits. So, for example, %08d would result in an 8 digit number.

If a time-lapse value of 0 is entered, the application will take pictures as
fast as possible. Note there is an minimum enforced pause of 30ms between
captures to ensure that exposure calculations can be made.

--thumb,    -th     Set thumbnail parameters (x:y:quality)

Allows specification of the thumbnail image inserted in to the JPEG file.
If not specified, defaults are a size of 64x48 at quality 35.
if --thumb none is specified, no thumbnail information will be placed in the file.
This reduces the file size slightly.

--demo, -d      Run a demo mode <milliseconds>
This options cycles through range of camera options, no capture is done, the demo
will end at the end of the timeout period, irrespective of whether all the options
have been cycled. The time between cycles should be specified as a millisecond value.

--encoding, -e      Encoding to use for output file
Valid options are jpg, bmp, gif and png.
Note that unaccelerated image types (gif, png, bmp) will take MUCH LONGER to save
than JPG which is hardware accelerated. Also note that the filename suffix is completely
ignored when deciding the encoding of a file.

--keypress, -k      Keypress mode
The camera is run for the requested time (-t), and a captures can be initiated
throughout that by pressing the Enter key. Press X then Enter will exit the application
before the timeout is reached. If the timeout is set to 0, the camera will run indefinitely
until X then Enter is typed. Using the verbose option (-v) will display a prompt asking
for user input, otherwise no prompt is displayed.

--signal,   -s      Signal mode
The camera is run for the requested time (-t), and a captures can be initiated
throughout that time by sending a USR1 signal to the camera process. This can be done
using the kill command. You can find the camera process ID using the 'pgrep raspistill'
command.
[
	kill -USR1 <process id of raspistill>
]

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
