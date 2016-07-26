// rover2 test run
// run the drawing machine with rover mounted
// establish the grid, set up rover connection and shoot a routine

// Open connection to Rover

// how much room is left on the drive
//    df /path/to/dev
// list volumes mounted
//    lsblk

// start raspistill in signal mode (-s -t 0) to take photos via trigger below
// NOTE: check the path is correct for the shoot and confirm parameters
// -s -t 0 // signal mode, timeout is 0 (stay on until killed)
// -th none // no thumbnail, reduces size
// -q 100 // quality

unixCmd("ssh pi@rover2.local 'raspistill -o /home/pi/lfimages/run1/image%04d.jpg -s -t 0 -th none -q 100'")
unixCmd("ssh pi@rover2.local 'raspistill -o /media/pi/ROVER2/run6/image%04d.jpg -s -t 0 -th none -q 100'")

// take a photo
unixCmd("ssh pi@rover2.local 'kill -USR1 $(pgrep raspistill)'");


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
d.send("$1=255")

d.yClipLow
d.xClipLow

// negative coordinate space
d.goTo_(-20, -20, 500)

d.goTo_(-3, -55, 1500)
d.goTo_(-75, -55, 500)
d.goTo_(-75, -3, 1500)
d.goTo_(-3, -3, 1500)

d.pause
d.resume

(
~getPoints = { arg numCols = 20, numRows = 20, canvasWidth = 72, canvasHeight = 58, canvasTopLeft = Point(2,2);
	var points;

	points = numRows.collect{ |i|
		var stepx, stepy;
		stepx = if (numCols>1) {canvasWidth / (numCols-1)} {0};
		stepy =if (numRows>1) {canvasHeight / (numRows-1)} {0};
		numCols.collect{ |j|
			canvasTopLeft + Point( stepx*j, stepy*i );
		};
	};


	points = points.collect{|row, i| if (i.odd) {row.reverse} {row}};
		points.do(_.postln);
	points = points.flat;
}
)

// gather the points
// .neg for machine coordinates
~pnts = ~getPoints.(numCols: 17, numRows: 1, canvasWidth: 72, canvasHeight: 1, canvasTopLeft: Point(2,62)).neg
~pnts
// help rover out by going to the first point
d.goTo_(~pnts[0].x, ~pnts[0].y, 1000)

(
~travelTime = 2;
~waitTime=2;
// routine to drive through the points
~captureRoutine = Task( {

	~pnts.do{ |pnt, i|
		// travel to point
		d.goToDur_(pnt.x, pnt.y, ~travelTime);
		~travelTime.wait;
		// snap shot
		unixCmd("ssh pi@rover2.local 'kill -USR1 $(pgrep raspistill)'");
		postf("snapping %/%\n\t", i+1, ~pnts.size);
		// wait before moving on
		~waitTime.wait;
	};
	"done".postln;
})
)

~captureRoutine.stop
~captureRoutine.play

~travelTime = 1;
~waitTime=1;

d.postState=true
d.state

d.unlock


// copy files to local machine from terminal
// scp pi@rover2.local:/home/pi/lfimages/run1/image0004.jpg ~/Desktop/test/

// kill raspistill
unixCmd("ssh pi@rover2.local 'kill $(pgrep raspistill)'")


// run 2
~pnts = ~getPoints.(numCols: 17, numRows: 17, canvasWidth: 72, canvasHeight: 57, canvasTopLeft: Point(2,2)).neg
// ... cables snagged multiple times (motors skipped steps)
// ... there was drift (when stopped), so hit limit and didnt complete, had to ad hoc last 3 rows
// run 3
~pnts = ~getPoints.(numCols: 17, numRows: 17, canvasWidth: 72, canvasHeight: 57, canvasTopLeft: Point(2,2)).neg