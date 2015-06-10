// testing new lightfield splotter rig

SerialPort.closeAll
SerialPort.listDevices

a = ArduinoGRBL("/dev/tty.usbmodemfd131", 115200)

a = ArduinoGRBL("/dev/tty.usbserial-A94JRL5D", 115200)

//  HOMING
a.home					// run homing routine
a.reset
a.unlock

a.postState_(true)
a.state

a.worldOffset_( (-72-130),  (-72-130))

(
a.xBoundLow = -1000;
a.yBoundLow = -1000;
a.xBoundHigh = 1000;
a.yBoundHigh = 1000;
a.xClipLow = -1000;
a.yClipLow = -1000;
a.xClipHigh= 1000;
a.yClipHigh= 1000;
)


-114.002

a.settings

a.commands

// a.send("G90") // switch to absolute positioning
// a.send("G91") // switch to relative positioning
// a.send("G0Y3") // switch to absolute positioning

// a.send("$N0=")
// a.send("$N")
//
// a.send("G92X92Y92") // switch to absolute positioning


a.send("$G")
a.send("$#")
a.goTo_(114,114,875) // go to "world" 0,0, feedrate 2000

(
~page0x = 12;
~page0y = 10;
~motorSeparation = 71;

~xy2ab = { |inX,inY|
	[
		sqrt( (~page0x + inX).pow(2) +  (~page0y + inY).pow(2) ) - 1.5,
		sqrt( (~motorSeparation - (~page0x + inX)).pow(2) +  (~page0y + inY).pow(2) - 1.5 )
	]
};
)

// SET FEED
a.send("G0F500") // switch to absolute positioning

a.goTo_(90, 90)
a.state
a.send("G0X90Y90")
a.state

a.goTo_(42.426406871193, 70.908832313048)
a.goTo_(39.426406871193, 67.908832313048, 875)
a.goTo_(*~xy2ab.(0,0))
a.goTo_(*~xy2ab.(60,0))

a.goTo_(*~xy2ab.(60,40))
a.goTo_(*~xy2ab.(0,40))
a.reset


a.goTo_(95,95)

~xy2ab.(95,95)


a.reset

a.unlock

$120=10.000 (x accel, mm/sec^2)
a.send("$121=10.000") // default
a.send("$120=10.000") // default

a.send("$121=2.000")
a.send("$120=2.000")


a.send("$27=70")
a.home()
a.reset()
5661
1.5
a.settings
a.send("$100=197.925")
a.send("$101=197.925")

a.send("$110=875")
a.send("$111=875")
a.send("$112=875")

a.settings
a.send("$27=84")
a.send("$120=2")
a.send("$121=2")

n = NetAddr("192.168.42.1", 9000)

n.sendMsg("/camera", "start")

n.sendMsg("/camera", "snap");

(
r = Routine.run({
	var
	waittime = 4,
	numXshots = 20,
	numYshots = 15,
	spanX = 48,
	spanY = 36,
	xStep, yStep;

	xStep = spanX/(numXshots-1);
	yStep = spanY/(numYshots-1);

	numYshots.do{ |y|
		numXshots.do{ |x|
			var wait;
			a.goTo_(*~xy2ab.(x * xStep, y * yStep));
			postf("next... %\n\n", [x,y]);
			wait = if( (x == 0) and: (y>0),
				{waittime * 4},{waittime}
			);
			(wait * 0.8).wait;
			n.sendMsg("/camera", "snap");
			"SNAP".postln;
			(wait * 0.2).wait;
		}
	};
})
)

n.sendMsg("/camera", "stop")

n.sendMsg("/camera", "exit")

// download all images
"rsync -avz pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/data/".unixCmd


a.state

// slow oscillate
a.settings
a.postState_(true)
a.reset

a.unlock
a.send("G91")
a.send("G0X5Y5")
(
r = Routine.run({
	var
	waittime = 5;

	inf.do {
	a.send("G0X-5Y-5");
	waittime.wait;
	a.send("G0X5Y5");
	waittime.wait;
	}

})
)