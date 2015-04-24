SerialPort.listDevices

a = ArduinoGRBL("/dev/tty.usbserial-A94JRL5D", 115200)
// a.free

// args:
//	anArduinoGRBL, << an instance of ArduinoGRBL that is driving the rig
//	cameraNetAddr, << a NetAddr for the pi snapping photos
r = RoverDriver(a, NetAddr("localhost", 12345));

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

// set the homeing pulloff the first time around
a.settings
// pulloff should be less than the distance from the limit switch to the pulley
a.send("$27=65")

// home the first time around
a.home
// be ready if it wigs out:
a.reset
a.unlock

// set up rig dimensions: dimensions of the motor suspension, sets the arduino world offset from the machine coordinate space

// motorSeparation: distance between motors (or pulleys)
// MachineX/Y:	after homing and pulling off, MachineX/Y machine coordinates (usually negative)
// lengthA/B:	after homing and pulling off, lengthA and lengthB are the distance from the pulley to the middle Rover's width (where the cables would intersect if they extended)
// camOffset:	offset from the end of the cable at the rover to the camera's center
r.rigDimensions_(motorSeparation: 60.25, machineX: -135, machineY: -135, lengthA: 68.5, lengthB: 68.5) //, camOffset: 1.5 );


// check the state
a.state
// the world position should be the length mentioned above (pulley>Roverhole)

// now the rig is initialized!



// set up capture dimensions: dimensions of your capture grid
// all args in inches
// captureSpanX: width of the capture plane
// captureSpanY: height of the capture plane
// insetY: vertical offset from the rig's pulley height to the 0,0 camera capture position
// nCols, nRows: number of rows and columns of subimages to capture
r.captureDimensions_(captureSpanX: 40, captureSpanY: 24, insetY: 10, nCols: 10, nRows: 6 );


// set Rover to capture in 1 of 3 ways:

// capture in a GRID
// args:
// 	rowsFirst, leftToRight, topDown, wrap,	<< bools to determine grid order
//	displayPath << bool to show the resultant path order

r.gridCapture( rowsFirst: true, leftToRight: true, topDown: true, wrap: true, displayPath: true )


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




// Choose the capture sequence timing
// args:
//	autoAdvance,	<< bool, if true, Rover advances when GRBL is ready
// 	stepWait,		<< if autoAdvance is false, advance every stepWait seconds
//	waitToSettle,	<< time to wait after arriving at location before taking photo
//	waitAfterPhoto,	<< time to wait after taking photo before advancing
//	travelTimeOut,	<< time to wait to timeout in case anything goes wrong waiting for GRBL state to report "Idle"
//	stateCheckRate	<< number of times GRBL state is queried per second when using auto-advance

r.initCapture( autoAdvance: true, waitToSettle: 1.5, waitAfterPhoto: 1.5, travelTimeOut: 30, stateCheckRate: 5)


// set GRBL's feed rate if not set already
a.feed_(500)
// a.send("G0F500")


// go to the location of the first capture point
r.goToFirstCapturePoint

// make sure the camera is ready to take images
n.sendMsg("/camera", "start")

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
"rsync -avz pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/data/".unixCmd



// TEST IT: get status as it moves
x = Routine.run({ inf.do{a.state; 0.2.wait} })
x.stop // stop checking the GRBL state


// return to the origin of the grid (this isn't GRBL homing)
r.goHome

// free GRBL when done
a.free




//////////////////////////////////////////////
// SCRATCH
//////////////////////////////////////////////

// get status as it moves
x = Routine.run({ inf.do{a.state; 0.2.wait} })
x.stop

a.goTo_(0,0)

r.captureTask.isPlaying

a.mode == "Idle"

