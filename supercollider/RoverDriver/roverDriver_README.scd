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

// set up rig dimensions: dimensions of the motor suspension
// motorSeparation: distance between motors (or pulleys)
// originX, originY: offset from the rig's limit to set the capture canvas's origin 0,0
// camOffset: offset from the end of the cable at the rover to the camera's center
r.rigDimensions_(motorSeparation: 60.25, originInsetX: 13.5, originInsetY: 17, camOffset: 1.5 );

// TODO move originInsetX/Y to captureDimensions_
// TODO move AB<>XY function to rigDimensions_
// infer xinset from pulley separation and spanx, and set yinset directly

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

//
f = { |machineX, machineY, lengthA, lengthB|
	a.worldOffset_( (lengthA.neg + machineX),  (lengthB.neg + machineY))
}
// after homing and pulling off, lengthA and lengthB are the
// distance from the pulley to the Rover ring mount hole center
f.( -135, -135, 68.5, 68.5 )

// check the state
a.state
// the world position should be the length mentioned above (pulley>Roverhole)


// now the rig is initialized!



// set up capture dimensions: dimensions of your capture grid
r.captureDimensions_(nCols: 10, nRows: 6, spanx: 40, spany: 24 );


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

// create your own capture order: provide an array of points on the grid
// in the order you want them shot
// first get the points in rows (left>right top>down)
p = r.getCamPointRows

// now manipulate them...
// get the points in a 1D array
p = p.flat

// collect the points with their associated distance from the specified origin
~radialOrigin = Point(7,13);
~distancesFromOrigin = p.collect{ |pt, i| Dictionary[ \dist->pt.dist(~radialOrigin), \pt->pt ] };

// sort them in ascending order (capture outward from origin)
p = ~distancesFromOrigin.sortBy(\dist).collect{ |distDict| distDict[\pt] };

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
// a.feed_(500) // TODO
a.send("G0F500")

r.goHome



// TODO
// r.goHome (goes to position after pulloff)
// r.goToFirstPoint

// TODO
// check the update state routine's role in making the state check work in autoAdvance () check out ArduinoGRBL's mode is updated

a.goTo_(68.5, 68.5)

// ROVE
r.run  // or r.play
// stop/pause
r.stop // or r.pause
// continue of you paused
r.run
// or reset from the beginning of the shoot
r.reset

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

