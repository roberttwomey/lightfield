(
var motorSeparation; // dist between cable axis points
var canvasW, canvasH, yOff;
var poH, poW;  // pulloff height/width
var pulloff; // motor pulloff after finding limit
var machx, machy; // the destination, in machine space, defined by limits
var macha, machb; // length a and b, in machine space
var destx, desty; // x,y destination sent to grbl
var limOffset; // distance between pivot point and rover tie point when retracted to limit point

e = (
	init: {{
		|mSeparation, limitOffset=0, tetherSeparation=1, width, height, yOffset|

		motorSeparation = mSeparation - tetherSeparation; // subtract span of tie points on camera mount
		// motorSeparation = mSeparation - limitSeparation;
		if (width >= (motorSeparation-(2*limitOffset))) {"width must be less than [motorSeparation - (2*limitOffset)]".throw};

		canvasW = width;
		canvasH = height;
		yOff = yOffset;
		limOffset = limitOffset;

		poH = height + yOffset;
		poW = motorSeparation/2;
		pulloff = (poH.squared + poW.squared).sqrt - limOffset;
		if (pulloff < (motorSeparation - (2*limOffset))) {
			postf("(pulloff + limOffset) : %\nmotorSeparation : %\n", (pulloff + limOffset), motorSeparation);
			(
				"Pulloff must be larger than the motor separation. " ++
				"Consider lowering the bottom bound of the canvas or bringing the motors closer together."
			).throw
		};
	}},
	goto: {{
		|gox, goy|
		machx = gox + ((motorSeparation-canvasW)/2);
		machy = goy + yOff;

		macha = (machx.squared + machy.squared).sqrt;
		machb = ((motorSeparation-machx).squared + machy.squared).sqrt;

		destx = macha - pulloff + limOffset;
		desty = machb - pulloff + limOffset;

		e.sendmsg.(destx, desty)
	}},
	sendmsg: {{
		|x,y|
		postf("Going to: [%, %]\n", x, y);
		// grbl.goTo_(x,y)
	}}
);
)

e.init.( mSeparation:10.125, width:6, height:6, yOffset: 4 )
// goto is in canvas coordinates
e.goto.( 0,0 )
e.goto.( 5+2, 3 )
e.goto.( 5-2, 3 )

/* ----------------------------------------------------------------
// test driving
----------------------------------------------------------------*/

SerialPort.listDevices
SerialPort.closeAll

// Connect arduino to Computer
g = Grbl("/dev/tty.usbserial-A9ETD3VR", 115200)
g.postState_(true)

// g.invertAxes_(false, false)
// g.homingInvertDirection_(true, true)

// set the homeing pulloff the first time around
g.settings
g.state

// if homing initially, set pulloff to more than the machine separation
g.homingPullOff_(45)

// home the first time around
// confirm pulloff first
g.home
g.reset
g.unlock

// Turn on Rover
// Connect to Rover_AP. pwd: roverrover
// dhcp

// args:
//	aGrbl, << an instance of Grbl that is driving the rig
//	cameraNetAddr, << a NetAddr for the pi snapping photos
r = RoverDriver2(g, NetAddr("localhost", 9000)); // testing
// r = RoverDriver2(g, NetAddr("rover.local", 9000));
// r.free




r.rigDimensions_(machineSpan:33,  limitOffset:0 , tetherSeparation: 2.375, captureWidth: 20, captureHeight: 34, captureYoffset: 3 );
// .rigDimensions_ sets the homingPulloff, so home after setting rig dimensions
g.home

r.goToTopLeft // should shift x positive
r.goToTopRight // should shift x negative
r.goToBottomRight
r.goToBottomLeft
r.goTo_(0,0,500)
r.goTo_(0,34,500)
r.goTo_(20,34,500)
r.goTo_(20,0,500)
r.goTo_(10,17,500)
g.goTo_(0,0,500)

g.goTo_(0, 0,500) // r 0,0
g.goTo_(-2, 0,500) // r 0,0
g.goTo_(0, -2,500) // r 0,0
g.goTo_(-6.708, 2.208,500) // r 0,0
g.goTo_(-2.208, 6.708,500) // r.goTo_(6,0,500)
g.reset

// check the state
g.state

g.free

// the world position (first two numbers after Idle) should be the length mentioned above (pulley>Roverhole), eg:
// [ Idle, [ 72.499, 72.499, 0 ], [ -135.001, -135.001, 0 ] ]

// now the rig is initialized!


// set up capture dimensions: dimensions of your capture grid
// all args in inches
// captureSpanX: width of the capture plane
// captureSpanY: height of the capture plane
// insetY: vertical offset from the rig's pulley height to the 0,0 camera capture position
// nCols, nRows: number of rows and columns of subimages to capture
r.captureDimensions_(captureSpanX: 10, captureSpanY: 10, insetY: 20, nCols: 17, nRows: 17 );