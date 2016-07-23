// rover2 test run
// run the drawing machine with rover mounted
// establish the grid, set up rover connection and shoot a routine

// Open connection to Rover


// start raspistill in signal mode (-s -t 0) to take photos via trigger below
// NOTE: check the path is correct for the shoot and confirm parameters
// -s -t 0 // signal mode, timeout is 0 (stay on until killed)
// -th none // no thumbnail, reduces size
// -q 100 // quality

unixCmd("ssh pi@rover2.local 'raspistill -o /home/pi/lfimages/run1/image%04d.jpg -s -t 0 -th none -q 100'")

// get the raspistill process ID (return empty space if not running)
a = ("ssh pi@rover2.local pgrep raspistill").unixCmdGetStdOut
~pid = a.split[0].asInt

SerialPort.listDevices
// SerialPort.cleanupAll
// a.free

// mounted to drawing machine
d = DMDriver("/dev/tty.usbserial-A9M55Z3B", 115200)

d.unlock
d.home
d.reset

// negative coordinate space
d.goTo_(-20, -20, 500)

(
~getPoints = { arg numCols = 5, numRows = 4, canvasWidth = 20, canvasHeight = 20, canvasTopLeft = Point(15,15);
	var points;

	points = numRows.collect{ |i|
		var stepx, stepy;
		stepx =canvasWidth / (numCols-1);
		stepy =canvasHeight / (numRows-1);
		numCols.collect{ |j|
			canvasTopLeft + Point( stepx*j, stepy*i );
		};
	};

	points.do(_.postln);
	points = points.flat;
}
)

// gather the points
// .neg for machine coordinates
~pnts = ~getPoints.(numCols: 5, numRows: 4, canvasWidth: 20, canvasHeight: 20, canvasTopLeft: Point(20,15)).neg

// help rover out by going to the first point
d.goTo_(~pnts[0].x, ~pnts[0].y, 1000)

(
var travelTime = 3, waitTime=3;
// routine to drive through the points
~captureRoutine = fork {

	~pnts.do{ |pnt|
		// travel to point
		d.goToDur_(pnt.x, pnt.y, travelTime);
		travelTime.wait;
		// snap shot
		unixCmd("ssh pi@rover2.local 'kill -USR1 $(pgrep raspistill)'");
		"snapping".postln;
		// wait before moving on
		waitTime.wait;
	};
	"done".postln;
}
)

~captureRoutine.stop


// copy files to local machine from terminal
// scp pi@rover2.local:/home/pi/lfimages/run1/image0004.jpg ~/Desktop/test/

// kill raspistill
unixCmd("ssh pi@rover2.local 'kill $(pgrep raspistill)'")