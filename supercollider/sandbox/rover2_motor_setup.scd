// --------------------------------------------------------
// MotorDriver How-To
// --------------------------------------------------------

// Look up your arduino's serial ID: "/dev/tty.usbserial-....."

SerialPort.listDevices
SerialPort.cleanupAll

// start Grbl with the Arduino serial address, baudrate 115200
a = Grbl("/dev/tty.usbserial-A9ETD3VR", 115200)
// a = Grbl("/dev/tty.usbserial-A9CBV1D5", 115200)

a.free
// 0.exit

a.postState_(true)
a.state

a.unlock
a.reset

a.home
a.reset

a.settings

a.worldOffset_(0,0)

a.goTo_(0,0,300)

/* for testing a new rover motor */
a.enableSoftLimit_(false)


// (steps_per_revolution*microsteps)/mm_per_rev
// 50:1 gearing (50x down per step), * 16 microsteps (configured in motor driver wiring), treating mm as degrees (360mm/revolution)
// 200*50*16/360 = 444.444
// or put another way...
// For steps/degree(mm) 50*16 / 1.8 = 444.4444... steps per degree

// Rover2 - suspended setup
a.stepPerMmX_(431.708)
a.stepPerMmY_(431.708)


/* The code below doesn't necessarily pertain to the rover 2 setup

// 200 steps/rev * 16 microsteps / 360 deg/rev
a.stepPerMmX_()
a.stepPerMmY_()
a.maxRateX_()
a.maxRateY_()
a.maxAccelX_(500)
a.maxAccelY_(500)

a.feed_(6000)
a.feed_(600)
a.feed_(29000)
a.x_(-10)
a.x_(10)
a.x_(0)
a.y_(0)
a.y_(1290)
a.y_(-10)
a.y_(10)

a.goTo_(50, 50, 4000)

a.free;
*/

a.enableHoming_(true)
a.enableSoftLimit_(true)
a.enableHardLimit_(true)
a.homingSeek_(1500)
a.homingPullOff_(5)
a.maxRateX_(4675)
a.maxRateY_(4675)
a.maxRateZ_(4675)
a.maxAccelX_(85)
a.maxAccelY_(85)
a.maxAccelZ_(85)
a.maxTravelX_(292)
a.maxTravelY_(164)
a.maxTravelZ_(360)
a.send("$3=6") // invert Y
// a.send("$3=4") // don't invert either


// // new to GRBL 0.9i,
// // when homing, GRBL first seeks to the limit (first pass),
// // pulls off HOMING PULL-OFF ($27) distance then enters a "locate" phase
// // at a slower HOMING FEED ($24) rate.
// // Once the limit is located again, it pulls off HOMING PULL-OFF again
// // so... to do: the pulloff needs to be a move instruction stored in
// a.send("$26=25") // was 250
// a.send("$24=550") // Homeing seek was 25


// do something based on the motor's position
(
// this function you define takes it's state, machine pos, and work pos as args
a.stateAction_({ |state, mpos, wpos|
	// post the position
	format(
		"% mode\tmachine position:\t%\n\t\t\tworld position:\t\t%\n",
		state, mpos, wpos
	).postln;
});
)

s.boot // boot so you can run that annoying ding
(
// this function you define takes it's state, machine pos, and work pos as args
a.stateAction_({ |state, wpos, mpos|
	fork{
		var ding;
		ding = Synth(\default);
		0.1.wait;
		ding.free
	};
	// post the position
	format(
		"My motor:\n% mode\tmachine position:\t%\n\t\t\tworld position:\t\t%\n",
		state, mpos, wpos
	).postln;
});
)

// get the info you need by polling the position in a routine
(
r = Routine.run({
	var updateRate = 10;
	inf.do{
	a.state;
		updateRate.reciprocal.wait
	}
});
)

r.stop


// who do you want to talk to?
~addr = NetAddr("192.168.2.2", 12345);
~addr.sendMsg("/motorPos", "hi", "marty");
(
// this function you define takes it's state, machine pos, and work pos as args
a.stateAction_({ |state, wpos, mpos|

	// send the work/world position to the other computer
	// ~addr.sendMsg('/motorPos', *wpos); // <-- [x,y,z]
	//~addr.sendMsg('/motorPos', wpos[0]); // <-- or just x
	~addr.sendMsg('/motorPos', wpos[0].linlin(-90,90,0,-5120.0)); // <-- or x scaled to your video werld


	// post the position
	format(
		"My motor:\n% mode\tmachine position:\t%\n\t\t\tworld position:\t\t%\n",
		state, mpos, wpos
	).postln;
});
)
a.motorInstructionRate

( // send a few instructions at "once"
fork {
	a.x_(-90,700);
	a.x_(90, 2000);
	a.x_(0, 1200)
}
)


// all done? Free.
a.free

a.reset
a.home
// now run that above routing again

// clear the state action
a.stateAction_({})


(
var dur = 0, cnt = 0, now = Main.elapsedTime;
// this function you define takes it's state, machine pos, and work pos as args
a.stateAction_({ |state, wpos, mpos|
	dur = dur + (Main.elapsedTime - now);
	if(dur > 1,
		{
			now =  Main.elapsedTime;
			dur = 0;
			cnt = 0
		},{
			cnt = cnt+1;
		}
	);
	cnt.postln;
	~addr.sendMsg('/motorPos', wpos[0].linlin(-90,90,0,-5120.0)); // <-- or x scaled to your video werld

});
)

// smooth out the motor polling so it drives the video at a faster update rate
a.stateUpdateRate_(25)

// alternative approach... read directly from the motor's posBus
(
r = Routine.run({
	inf.do{
		m.lfoControlX.controlBus.get({ |busnum, goTo| ~addr.sendMsg('/motorPos', goTo.linlin(-90,90,0,-5120.0).postln) });
		// a.posBus.get({ |busnum, goTo| ~addr.sendMsg('/motorPos', goTo.linlin(-90,90,0,-5120.0)) });
		60.reciprocal.wait
	}
})
)
r.stop




// now create a MotorDriver to drive through your arduino
m = MotorDriver(a);
~m2 = MotorDriver(~a2);
a.free
m.free

a.motorInstructionRate = 15
~a2.motorInstructionRate = 15

// g = GrainFader(0, 1, bufFolderPath: "/Users/admin/Documents/Recordings/test/");
g = GrainFader(0, 1, bufFolderPath: "/Users/admin/Documents/Recordings/performance/");

// t = TouchOSC("169.254.58.201", 9000)
t = TouchOSC("169.254.137.35", 9000)

// connect the TouchOSC to the GrainFader
g.connectTouchOSC(t, numSfColumns: 2, numSfRows: 4)
// >> Note you should see the soundfile names show up at the top of your TouchOSC interface, in the labels of the multi-push widgets.

t.clearControls
t.disconnectAll

// cleanup
// (close MotorDriver window to free it)
a.free
// free the GrainFader
g.free
// free the TouchOSC
t.free

g.sfNames.do(_.postln)

a.settings
a.home



// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Advanced settings for Grbl
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// first time setting or when resetting EEPROM
a.send("$100=444.444")	// x, step/mm
a.send("$101=444.444")	// y, step/mm
a.maxTravelX_(292.000)	// set max X travel in mm -150 +145 -3 in case
a.maxTravelY_(164.000)	// set max y travel in mm -84 +83 - 3 in case
a.send("$25=750.000")	// (homing seek, mm/min)


// Note seize feed and speeds: accel 100 mm/min^2, feed 5500 mm/min
// 15% reduction in each
a.send("$120=85")		// max accel x mm/min
a.send("$121=85")		// max accel y mm/min
a.send("$110=4675")		// max rate x mm/min
a.send("$111=4675")		// max rate x mm/min


a.send("$22=1")			// make sure homing is on
a.send("$20=1")			// set soft limit on/off
a.send("$21=1")			// set hard limit on/off
a.send("$27=5")			// homing pulloff

a.settings				// confirm

//  HOMING
a.home					// run homing routine

// set the world offset relative to the machine coordinates
// where the machine's limits are it's 0,0
a.worldOffset_(-150, -84); // = a.send("G10L2P0X-150Y-84")

// travel to origin
a.goTo_(0,0,2000) // go to "world" 0,0, feedrate 2000

// request the state and position of the motor system
a.state

// update the instance internally with the world position of the motors, at an updateRate,
// optionally post it with postStateBool
a.updateState_(true, updateRate: 5, postStateBool: true)
a.postState = true
a.postState = false
a.updateState = false
a.stateUpdateRate		// introspection
a.stateUpdateRate = 10	// setting

// write the motors' position to a control bus
// Note: writes to the bus at a.stateUpdateRate
a.writePosToBus_(true)
a.postState_(false)
a.posBus		// get the bus it writes to

// this allows you to then plot the motor's position:
// Note, each axis is plotted separately, so specify if you want more than one channel
~plot = ControlPlotter(busindex: a.posBus.bus, numChans: 2, plotLength: 50, refresh_rate: 10).start.bounds_(-90,90);
