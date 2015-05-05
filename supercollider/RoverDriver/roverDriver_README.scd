SerialPort.listDevices

// Connect arduino to Computer
a = ArduinoGRBL("/dev/tty.usbserial-A94JRL5D", 115200)

a = ArduinoGRBL("/dev/tty.AdafruitEZ-Link418c-SPP", 115200)

// home the first time around
a.home
// be ready if it wigs out:
a.reset
a.unlock

// set the homeing pulloff the first time around
a.settings
// pulloff should be less than the distance from the limit switch to the pulley
a.send("$27=52")

// Turn on Rover
// Connect to Rover_AP. pwd: roverrover
// dhcp

// args:
//	anArduinoGRBL, << an instance of ArduinoGRBL that is driving the rig
//	cameraNetAddr, << a NetAddr for the pi snapping photos
r = RoverDriver(a, NetAddr("rover.local", 9000));


/*
SETUP NOTE
- put the c stands at the same height, make the line taut with Rover far enough down to reach the farthest corner of the capture plane (max radius from oppostite pulley)
- put the limit bobbers at the same height
- in setting the limit bobbers, ensure the distance between bobber and limit switch is less than the distance from pulley to Rover ring
*/


// make sure GRBL is ready (Idle)
a.postState_(true)
a.state
// unlock if needed
a.unlock


// set up rig dimensions: dimensions of the motor suspension, sets the arduino world offset from the machine coordinate space
// motorSep = 66
// lengthA/B: 71 + 1.5 = 72.5
// MachineX/Y: -135, -135

// motorSeparation: distance between motors (or pulleys)
// MachineX/Y:	after homing and pulling off, MachineX/Y machine coordinates (usually negative)
// lengthA/B:	after homing and pulling off, lengthA and lengthB are the distance from the pulley to the middle Rover's width (where the cables would intersect if they extended)
// camOffset:	offset from the end of the cable at the rover to the camera's center
r.rigDimensions_(motorSeparation: 56.125, machineX: -148, machineY: -148, lengthA: 62.25, lengthB: 61.5) //, camOffset: 1.5 );


// check the state
a.state
// the world position (first two numbers after Idle) should be the length mentioned above (pulley>Roverhole), eg:
// [ Idle, [ 72.499, 72.499, 0 ], [ -135.001, -135.001, 0 ] ]

// now the rig is initialized!


// set up capture dimensions: dimensions of your capture grid
// all args in inches
// captureSpanX: width of the capture plane
// captureSpanY: height of the capture plane
// insetY: vertical offset from the rig's pulley height to the 0,0 camera capture position
// nCols, nRows: number of rows and columns of subimages to capture
r.captureDimensions_(captureSpanX: 32, captureSpanY: 30, insetY: 8, nCols: 22, nRows: 22 );


// set Rover to capture in 1 of 3 ways:

// capture in a GRID
// args:
// 	rowsFirst, leftToRight, topDown, wrap,	<< bools to determine grid order
//	displayPath << bool to show the resultant path order

r.gridCapture( rowsFirst: true, leftToRight: true, topDown: false, wrap: true, displayPath: true )


/*

// capture in a RANDOM ORDER
// args:
//	displayPath << bool to show the resultant path order

r.randomPathCapture( displayPath: true);



// capture in a CUSTOM ORDER (fancy!)
(
// A little array manipulation to get a capture path radiating from a center point

// create your own capture order: provide an array of points on the grid
// in the order you want them shot
// first get the points in rows (left>right top>down)
p = r.getCamPointRows;

// now manipulate them...
// get the points in a 1D array
p = p.flat;

// collect the points with their associated distance from the specified origin
~radialOrigin = Point(7,13);
~distancesFromOrigin = p.collect{ |pt, i| Dictionary[ \dist->pt.dist(~radialOrigin), \pt->pt ] };

// sort them in ascending order (capture outward from origin)
p = ~distancesFromOrigin.sortBy(\dist).collect{ |distDict| distDict[\pt] };
)

// or descending order (capture in an order converging on origin)
p = p.reverse;

// now give it to Rover
// args:
//	pointArray		<< a 1D array with grid points (x/y indices) in the order you'd like them captured
//	displayPath		<< bool to show the resultant path order

r.customPathCapture( pointArray: p, displayPath: true)

*/


// Choose the capture sequence timing
// args:
//	autoAdvance,	<< bool, if true, Rover advances when GRBL is ready
// 	stepWait,		<< if autoAdvance is false, advance every stepWait seconds
//	waitToSettle,	<< time to wait after arriving at location before taking photo
//	waitAfterPhoto,	<< time to wait after taking photo before advancing
//	travelTimeOut,	<< time to wait to timeout in case anything goes wrong waiting for GRBL state to report "Idle"
//	stateCheckRate	<< number of times GRBL state is queried per second when using auto-advance

r.initCapture( autoAdvance: true, waitToSettle: 0.5, waitAfterPhoto: 1.5, travelTimeOut: 30, stateCheckRate: 5, writePosData: true, fileName: "dome")


// TODO set this in RoverDriver class
// set GRBL's feed rate if not set already
a.feed_(500)
// a.send("G0F500")


// go to the location of the first capture point
r.goToFirstCapturePoint

a.unlock
a.reset

// logon to rover and check status of camera service
// in terminal:
// ssh pi@rover.local
// screen -ls
// also empty out lfimages directory:
// rm -r ~/lfimages/*

// ROVE
r.run  // or r.play
// stop/pause
r.stop // or r.pause
// continue of you paused
r.run
// or reset from the beginning of the shoot
r.reset

// a.goTo_(68.5, 68.5)
// return to the location Rover is after pulloff (to check no slippage)
r.goTopulloffHome

n.sendMsg("/camera", "stop")

n.sendMsg("/camera", "exit")

// download all images
//"rsync -avz pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/data/".unixCmd
d = "rtest3"
("rsync -avz pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/"++d++"/").unixCmd

r.writeDataToFile(fileName:"dome")

// for setting up the contact sheet, it's useful to read the data file:
r.readDataFile( r.dataDir ++ "test1.txt", postResults: true )
// use the image index to know which image to place in order on
// the contact sheet from top to bottom, left to right
// (this assumes Rover captured images with a 0-based index for each capture path)


// TEST IT: get status as it moves
x = Routine.run({ inf.do{a.state; 0.2.wait} })
x.stop // stop checking the GRBL state


// return to the origin of the grid (this isn't GRBL homing)
r.goHome

// free GRBL when done
a.free



//////////////////////////////////////////////
// setting steps/mm
//////////////////////////////////////////////

a = ArduinoGRBL("/dev/tty.usbserial-A94JRL5D", 115200)

// home
a.home

// be ready if it wigs out:
a.reset
a.unlock


// measure actual pull off compared to pulloff setting ($27)
a.settings

// set new steps/mm as necessary, eg:
// 64.0 measures / 65.0 setting * current steps/mm = new steps/mm
a.send("$100=206.59798263355")
a.send("$101=206.59798263355")

// pulloff should be less than the distance from the limit switch to the pulley
a.send("$27=65")



//////////////////////////////////////////////
// SCRATCH
//////////////////////////////////////////////

// get status as it moves
x = Routine.run({ inf.do{a.state; 0.2.wait} })
x.stop
a.feed_(500)
a.goTo_(100,1000)

r.captureTask.isPlaying

a.mode == "Idle"

