ArduinoGRBL : Arduino
{
	classvar <>numInstances = 0;

	var <id, <>stateAction, <>dispatching=false, <streamBuf, <followRoutine, <maxLagDist, <>minMoveQueue;
	var <>mPos, <>wPos=0, <>mode, <>maxDegPerSec, <minFeed, <maxFeed, <feedSpec, <lastDest, <stateRoutine;
	var <starving = false, <lagging = false, <>postState = false, <rx_buf_size;
	var <posBus, <writePos = false, <>stateUpdateRate, <motorInstructionRate;
	var <followView, <>debug = false, <>server;
	var <followSynth, <followDef, <followResponder;
	var <followSynthXY, <followDefXY, <followResponderXY;
	var <>xBoundLow, <>xBoundHigh, <>yBoundLow, <>yBoundHigh, <>xClipLow, <>xClipHigh, <>yClipLow, <>yClipHigh;
	var <posPlotter, <>underDrive, <>overDrive;

	*parserClass { ^ArduinoGRBLParser }

	// note this overwrites Arduino's init method
	init {
		// used to create a unique ID, no need to remove when freed
		ArduinoGRBL.numInstances = ArduinoGRBL.numInstances +1;
		id = ArduinoGRBL.numInstances;

		streamBuf = List();
		parser = this.class.parserClass.new(this);

		mPos			= [0,0,0];
		wPos			= [0,0,0];
		maxDegPerSec	= 90; //180 / 3.2702541628;	// seconds to go 180 degrees
		maxLagDist		= 10; 					// max degrees that the world can lag behind a control signal
		minFeed			= 50;
		maxFeed			= 4675;
		motorInstructionRate = 15;				// rate to send new motor destinations
		minMoveQueue	= 2;					// have at least 4 moves queue'd up
		feedSpec		= ControlSpec(minFeed, maxFeed, default: 500);
		rx_buf_size		= 128;
		underDrive		= 1.0;
		overDrive		= 0.4;

		xBoundLow = 292.00.half.neg;
		xBoundHigh = 292.00.half;
		yBoundLow = 164.00.half.neg;
		yBoundHigh = 164.00.half;

		xClipLow = xBoundLow + 0.5;
		xClipHigh = xBoundHigh - 0.5;
		yClipLow = yBoundLow + 0.5;
		yClipHigh = yBoundHigh - 0.5;

		// default rate that state will be requested when stateRoutine runs
		stateUpdateRate = 5;

		// // default response to a state message
		// stateAction = { |state, mpos, wpos|
		// 	format(
		// 		"% mode\tmachine position:\t%\n\t\t\tworld position:\t\t%\n",
		// 		state, mpos, wpos
		// 	).postln;
		// };

		inputThread = fork { parser.parse };
	}

	// Note: .send increments the streamBuf with the message character size
	// use port.putall to bypass the streamBuf
	send { | aString |
		var str;
		str = aString ++ "\n";
		port.putAll(str);

		// add this message's size to the stream buffer
		streamBuf.add(str.size); // .size takes the ascii size? "\n".size == 1
		// postf("adding:\t% from streamBuf\n", str.size);

		//GUI update
		this.changed(\streamSize, streamBuf.size);
		this.changed(\streamSum, streamBuf.sum);
	}

	goTo_{ |toX, toY, feed|
		var cmd = "G01";
		toX !? {cmd = cmd ++ "X" ++ toX.clip(xBoundLow, xBoundHigh)};
		toY !? {cmd = cmd ++ "Y" ++ toY.clip(yBoundLow, yBoundHigh)};
		feed !? {cmd = cmd ++ "F" ++ feed};
		this.send(cmd);
	}

	// go to x pos
	x_ {|toX, feed|
		var cmd = "G01";
		toX !? {cmd = cmd ++ "X" ++ toX};
		feed !? {cmd = cmd ++ "F" ++ feed};
		this.send(cmd);
	}

	// go to y pos
	y_ {|toY, feed|
		var cmd = "G01";
		toY !? {cmd = cmd ++ "Y" ++ toY};
		feed !? {cmd = cmd ++ "F" ++ feed};
		this.send(cmd);
	}

	minFeed_ { |feedRate|
		minFeed = feedRate;
		feedSpec = ControlSpec(minFeed, maxFeed, default: 500);
	}

	maxFeed_ { |feedRate|
		maxFeed = feedRate;
		feedSpec = ControlSpec(minFeed, maxFeed, default: 500);
	}

	maxLagDist_ { |maxDeg|
		maxLagDist = maxDeg;
	}

	updateState_ { |bool = true, updateRate, postStateBool|

		stateRoutine	!? { stateRoutine.stop };
		postStateBool	!? { postState = postStateBool };
		updateRate		!? { stateUpdateRate = updateRate};

		bool.if{
			stateRoutine.notNil.if(
				{ stateRoutine.isPlaying.not.if{ stateRoutine.reset.play } },
				{ stateRoutine = Routine.run({
					var wait;
					inf.do{
						wait = stateUpdateRate.reciprocal;
						this.state; wait.wait
					}
					})
				}
			);
		};
	}

	plotMotorPositions_ { |bool, boundLo = -90, boundHi = 90, plotLength = 50, plotRefreshRate = 10, plotMode = \points |
		bool.if(
			{
				{	var cond;
					cond = Condition(false);
					this.writePosToBus_(true, completeCondition: cond);
					cond.wait;

					posPlotter = ControlPlotter(posBus.bus, 2, plotLength, plotRefreshRate, plotMode);
					posPlotter.start.bounds_(boundLo,boundHi);
				}.fork(AppClock);
			},{
				posPlotter !? {posPlotter.free};
			}
		)
	}

	// write the motor position to a bus so it can be plotted
	writePosToBus_ { |bool = true, busnum, completeCondition|

		bool.if{
			server ?? {server = Server.default};
			server.waitForBoot({

				//make sure the state is being updated internally (setting, state and w/mPos)
				stateRoutine.isPlaying.not.if { this.updateState_(true) };

				posBus ?? {
					posBus =  busnum.notNil.if(
						{ CtkControl.play(2, bus: busnum) },
						{ CtkControl.play(2) }
					);
				};
				completeCondition !? {completeCondition.test_(true).signal};
			});
		};

		// set the writePos variable so the parser whether to update
		// posBus with the position value
		writePos = bool;
	}


	// NOTE: ? status, ~ cycle start/resume, ! feed hold, and ^X soft-reset
	// are responded to immediately so do not need to be tracked in the streamBuf
	// so use port.putAll (.send adds to the streamBuf)
	state	{ port.putAll("?") }
	pause	{ port.putAll("!") }
	resume	{ port.putAll("~") }
	reset	{ port.putAll([24, 120]); streamBuf.clear; } // cmd + x - no CR needed

	home	{ port.putAll("$H\n") }
	unlock	{
		if( mode == "Alarm",
			{ port.putAll("$X\n") },
			{
				mode.isNil.if({
					"GRBL state isn't known, first query .state before unlocking".warn;
					},{
						var msg;
						msg = format("GRBL is in % mode, no need to unlock", mode);
						this.changed(\status, msg);
						msg.postln;
				});
			}
		);
	}

	// getters
	commands	{ this.send("$") }
	settings	{ this.send("$$") }
	gCodeParams	{ this.send("$#") }

	// setters
	invertAxes_ {|invXbool, invYbool|
		var id;
		id = case
		{invXbool and: invYbool}			{3}
		{invXbool and: invYbool.not}		{1}
		{invYbool and: invXbool.not}		{2}
		{invXbool.not and: invYbool.not}	{0};

		this.send("$3="++id)
	}

	invertHomingDirection_ {|invXbool, invYbool|
		var id;
		id = case
		{invXbool and: invYbool}			{3}
		{invXbool and: invYbool.not}		{1}
		{invYbool and: invXbool.not}		{2}
		{invXbool.not and: invYbool.not}	{0};

		this.send("$23="++id)
	}

	worldOffset_ { |x, y|
		var str;
		str = format("G10L2P0X%Y%", x, y);
		this.send(str)
	}

	maxTravelX_ { |distanceDeg|
		this.send("$130="++distanceDeg)
	}

	maxTravelY_ { |distanceDeg|
		this.send("$131="++distanceDeg)
	}

	softLimit_ { |bool| // bool, 1 or 0
		bool.asBoolean.if(
			{ this.send("$20=1") }, // set soft limit on/off
			{ this.send("$20=0") } // set soft limit on/off
		)
	}

	free {
		this.unfollow;
		stateRoutine.stop;
		followSynth 		!? { followSynth.free };
		followSynthXY 		!? { followSynthXY.free };
		followResponder		!? { followResponder.free };
		followResponderXY	!? { followResponderXY.free };
		posPlotter 			!? { posPlotter.free };
		this.close;
	}

}

ArduinoGRBLParser
{
	var <arduinoGRBL, <port;
	var asciiInputLine, <charState;

	*new { | arduinoGRBL |
		^super.newCopyArgs(arduinoGRBL, arduinoGRBL.port).init
	}

	init { }

	parse {
		// hold each line of feedback from GRBL
		asciiInputLine = List();
		charState = nil;

		// start the loop that reads the SerialPort
		loop { this.parseByte(port.read) };
	}

	parseByte { | byte |
		if (byte === 13) {
			// wait for LF
			charState = 13;
		} {
			if (byte === 10) {
				if (charState === 13) {
					// CR/LF encountered, wrap up this line

					if (asciiInputLine.notEmpty) {
						//postf("asciiInputLine: %\n", asciiInputLine); // debug
						this.chooseDispatch(asciiInputLine);
					};

					// clear the line stream
					asciiInputLine.clear;
					charState = nil;
				}
			} {
				asciiInputLine.add( byte ); //.asAscii;
			}
		}
	}


	// note: the dispatching variable denotes if a message from
	// GRBL is complete signed of with [ok]
	chooseDispatch { |asciiLine|
		var localCopy;

		// must copy line so it isn't lost in the fork below once
		// asciiInputLine.clear in parseByte()
		localCopy = List.copyInstance(asciiLine);

		block { |break|

			// "ok"
			if ( asciiLine.asArray == [111, 107] ) {

				if( arduinoGRBL.streamBuf.size > 0, {
					// postf("removing:\t% from streamBuf\n",
					// arduinoGRBL.streamBuf[0]);
					arduinoGRBL.streamBuf.removeAt(0);

					arduinoGRBL.changed(\streamSize, arduinoGRBL.streamBuf.size);
					arduinoGRBL.changed(\streamSum, arduinoGRBL.streamBuf.sum);
				} );
				// this.postGRBLinfo(asciiLine); // uncomment to post 'ok'
				break.();
			};

			switch( localCopy[0],

				// "<" - GRBL motor state response
				60, {
					fork{
						var stateInfo;
						stateInfo = this.parseMotorState(localCopy);
						// execute user-specified stateAction method with the stateInfo
						arduinoGRBL.stateAction.value( *stateInfo );
						arduinoGRBL.postState.if { stateInfo.postln };
					};
					break.();
				},

				// "$" - GRBL params/settings
				36, {
					// "[GRBL params/settings] ".post; // debug
					this.postGRBLinfo(asciiLine);
					// could further filter asciiLine[1]
					// for separate dispatch actions/parsing
					// "N" - view startup blocks - $N
					// "$" - view GRBL settings - $$
					break.();
				},

				// "[" - G-code info
				91, {
					arduinoGRBL.state; // query state to set mode/coordinate variables
					this.postGRBLinfo(asciiLine);
					// "#" - view G-code parameters - $#
					// "G" - view G-code parser state - $G
					arduinoGRBL.changed(\status, asciiLine.asAscii);
					break.();
				},

				// "G" - Grbl 0.9g ['$' for help]
				71, {
					if (localCopy[0..3] == List[ 71, 114, 98, 108 ], //"Grbl"
						// Startup / reset
						{
							// query state to set mode/coordinate variables
							arduinoGRBL.state;
							// "Welcome to ArduinoGRBL in SC".postln; // debug
						}
					);
				},

				// "e" - error
				101, {
					arduinoGRBL.changed(\error, asciiLine.asAscii);
					this.postGRBLinfo(asciiLine);
				},

				// "A" - Alarm
				65, {
					arduinoGRBL.changed(\error, asciiLine.asAscii);
					arduinoGRBL.changed(\mode, "Alarm");
					arduinoGRBL.mode = "Alarm";
					this.postGRBLinfo(asciiLine);
				},
			);

			// catchall - just post the message
			this.postGRBLinfo(asciiLine);
		}
	}


	postGRBLinfo { | asciiLine |
		// ... do more if desired for generic messages
		asciiLine.asAscii.postln;
	}


	parseMotorState { | asciiLine |
		var split, mode, mPos, wPos;

		/*
		asciiLine.asAscii returns line in the format:
		<Idle,MPos:5.529,0.560,7.000,WPos:1.529,-5.440,-0.000>
		*/

		split = asciiLine.asAscii.split($,);
		mode = split[0].drop(1);
		mPos = split[1..3].put(0, split[1].drop(5)).asFloat;
		wPos = split[4..6].put(0, split[4].drop(5)).asFloat;

		// store the mode/pos back to the arduionoGRBL state vars
		arduinoGRBL.wPos = wPos;
		arduinoGRBL.mPos = mPos;

		arduinoGRBL.changed(\wPos, wPos);
		arduinoGRBL.changed(\mPos, mPos);

		if( arduinoGRBL.mode != mode, {
			arduinoGRBL.changed(\mode, mode);
			arduinoGRBL.mode = mode;
		});

		arduinoGRBL.writePos.if { arduinoGRBL.posBus.set(wPos[0..1]) };

		^[mode, wPos, mPos]
	}
}



/*  -------   SCRATCH   ---------

SerialPort.devices
a = ArduinoGRBL("/dev/tty.usbserial-A9WB75DP", 115200)

r = Routine({ var cnt = 0; 100.do{ cnt = cnt+1; a.state; cnt.postln; 0.5.wait}).play
*/

/*
	/*
	An attempt to create a buffer that filled instructions
	in advance of where the motor is.  Doesn't work all that well...
	*/
	followWithLeadingBuffer_ { |ctlFade, driveRate, instructionLag = 4|
		var iBuf, iBufSize, iDex, iBufState;

		stateRoutine.isPlaying.not.if{ this.updateState_(true) };

		lastDest	?? { lastDest = wPos[0] };
		driveRate	!? { motorInstructionRate = driveRate };

		iBuf = List(instructionLag * 3); // instruction buffer
		iBufSize = instructionLag * 3;
		iDex = 0;			// instruction index
		iBufState = 0; 		// states:	0 - filling the initial buffer
							//			1 - buffer is full and instructions are cycling


		followRoutine = Routine.run( {
			var maxNextDist, catchup = 1, ctlBufferSize, ctlBuffer, ctlPtr = 0;

			inf.do{ |i|
				if(mode != "Alarm", {

					// poll the control bus for a new position
					ctlFade.controlBus.get({ |busnum, goTo|
						var deltaFromWorld, deltaFromLast, nextPos, nextFeed;

						maxNextDist		= maxDegPerSec / motorInstructionRate;
						//maxNextDist		= maxNextDist * 1.2; // let it overshoot a bit if needed

						deltaFromWorld	= goTo - wPos[0]; // distance from the latest world position
						deltaFromLast	= goTo - lastDest; // distance from the last scheduled destination

						// is the instruction buffer starving ?
						starving = (streamBuf.size < minMoveQueue);

						// is it lagging too far behind the world?
						(deltaFromWorld > maxLagDist).if(
							{ lagging = true; debug.if{ "world is LAGGING".postln} },
							{ lagging = false }
						);

						if( deltaFromLast.abs > maxNextDist,
							// is it trying to go farther than a maximum single drive instruction?
							{
								// limit the next instruction to a max rate and distance
								nextPos = lastDest + (maxNextDist * deltaFromLast.sign);
								nextFeed = maxFeed;
								"Exceeding max move - limiting next destination".postln;
							},{

								// a regular destination and feed
								nextPos = goTo;
								nextFeed = feedSpec.map(deltaFromLast.abs/maxNextDist);

								if( lagging,
									// instruct to move further, bump up the next feed rate, clipping at max feed
									{
										// nextPos = lastDest + (deltaFromLast * 1.3);
										nextFeed = [(nextFeed * 1.2), maxFeed].minItem; // clip at maxFeed
									},
									// slow down if the instruction list is starving
									{
										if( starving, {
											// nextFeed = nextFeed * 0.8;
											// catchup = catchup * 1.05;
										}, { catchup = 1 });
									}
								);
						});

						switch( iBufState,
							// buffer full, cycling through
							1, {
								iDex.post; " - filling".postln; // debug
								iBuf.put( iDex, [nextPos, nextFeed]);

								if( ( ((iDex+1) % instructionLag) == 0 ), {
									var sendStart;
									sendStart = (iDex+1 - instructionLag).wrap(0, instructionLag*3-1);
									// send instruction set of last instructionLag number of new instructions
									this.sendInstructions( iBuf[sendStart..(sendStart + instructionLag - 1)] );

									// debug
									postf("sending instruction set - iDex: % sendStart: %\n", iDex, sendStart);
									iBuf[sendStart..(sendStart + instructionLag - 1)].do(_.postln;);

									// debug
									postf("updating las pos:\t%\n", lastDest );
									}
								);

							},
							// initial filling of instruction buffer
							// When follow is called, there is a (instructionLag*2*driveRate.reciprocal) second delay
							0,	{
								iDex.post; " - adding - ".post; [nextPos, nextFeed].postln; //debug
								iBuf.add( [nextPos, nextFeed]);

								case
								{iBuf.size == (instructionLag*2)} {
									// send first 2 instruction sets
									this.sendInstructions( iBuf[0..(instructionLag*2-1)] );
								}

								{iBuf.size == (instructionLag*3-1)} {
									// add a dummy entry which will be overwritten next iteration above
									iBuf.add( [nextPos, nextFeed]);
									// flip state to change into cycling mode
									iBufState = 1;
								};
							}
						);

						lastDest = nextPos;
						iDex = (iDex + 1) % iBufSize;
					});

					// rate to send G-code positions to GRBL
					// (motorInstructionRate * catchup).reciprocal.wait
					motorInstructionRate.reciprocal.wait

					},{"won't follow in ALARM mode".postln; 0.25.wait;}
				)
			}
		});
	}

	sendInstructions { |coordFeedArr|
		fork{ coordFeedArr.do{ | destFeed |
			"instructing: ".post; destFeed.postln;
			this.x_(*destFeed);
			// ideally count characters and ok responses then send the next instruction
			0.025.wait;
		} };
	}




// this version of follow_ works in a basic way
follow_ { |ctlFade, driveRate|
		// need the state to update for following to work

		stateRoutine.isPlaying.not.if{ this.updateState_(true) };

		lastDest	?? { lastDest = wPos[0] };
		driveRate	!? { motorInstructionRate = driveRate };

		followRoutine = Routine.run( {
			var maxNextDist, catchup = 1;

			inf.do{
				if(mode != "Alarm", {
					// poll the control bus for a new position
					ctlFade.controlBus.get({ |busnum, goTo|
						var deltaFromWorld, deltaFromLast, nextPos, nextFeed;

						maxNextDist		= maxDegPerSec / motorInstructionRate;

						// measure from the last scheduled ("ok") coordinate ?
						// or the last status updated coordinate
						deltaFromWorld	= goTo - wPos[0]; // distance from the latest world position
						deltaFromLast	= goTo - lastDest; // distance from the last scheduled destination

						// debug
						postf(
							"world\t\t%\nlastDest\t\t%\ngoTo\t\t\t%\nmaxNextDist\t%\ndeltaFromWorld\t%\ndeltaFromLast\t%\n",
							wPos[0], lastDest, goTo, maxNextDist, deltaFromWorld, deltaFromLast);
						postf("streamBuf\t%\n\n", streamBuf);

						// is the instruction buffer starving ?
						starving = (streamBuf.size < minMoveQueue);

						// is it lagging too far behind the world?
						(deltaFromWorld > maxLagDist).if({
							lagging = true;
							"world is lagging too far behind - DO SOMETHING".postln;
						},{	lagging = false });


						if( deltaFromLast.abs > maxNextDist,
							// is it trying to go farther than a maximum single drive instruction?
							{
								// limit the next instruction to a max rate and distance
								nextPos = lastDest + (maxNextDist * deltaFromLast.sign);
								nextFeed = maxFeed;
								"Exceeding max move - limiting next destination".postln;
							},{

								// a regular destination and feed
								nextPos = goTo;
								nextFeed = feedSpec.map(deltaFromLast.abs/maxNextDist);

								if( lagging,
									// instruct to move further, bump up the next feed rate, clipping at max feed
									{
										// nextPos = lastDest + (deltaFromLast * 1.3);
										nextFeed = [(nextFeed * 1.2), maxFeed].minItem;
									},
									// slow down if the instruction list is starving
									{
										if( starving, {
											// nextFeed = nextFeed * 0.8;
											"STARVING - slowing down the feed".postln;
											// catchup = catchup * 1.05;
										}, { catchup = 1 });
									}
								);
						});

						// [busnum, goTo].postln
						// ~az = goTo.postln;
						this.x_(nextPos, nextFeed);

						// debug
						postf("next move/feed:\t%\n\n\n", [nextPos, nextFeed]);

						lastDest = nextPos;
					});

					// rate to send G-code positions to GRBL
					// (motorInstructionRate * catchup).reciprocal.wait
					motorInstructionRate.reciprocal.wait

					},{"won't follow in ALARM mode".postln;}
				)
			}
		});
	}
*/

/*
// ROUTINE-BASED version, instead of OSC version
// follw a control bus (ControlFade), polling it as often as is needed to keep the
	// serial buffer full
	followSerialBuf_ { |aControlBus, driveRate, gui = false|

		// write the position of the motor to a bus
		// not necessary?? - this is used for plotting
		//writePos.not.if{ this.writePosToBus_(true) };

		// monitor how full the serial buffer is: starved or dropping messages
		gui.if{ followView = ArduinoGRBLView(this) };

		// start the stream buffer fresh
		streamBuf.clear;

		// make sure stateRoutine is playing to update wPos and state variables
		stateRoutine.isPlaying.not.if{
			// Recommended not to exceed 5Hz update rate
			this.updateState_(true, 5);
		};

		// ensure lastDest has a value
		lastDest	?? { lastDest = wPos[0] };
		// forward driveRate to motorInstructionRate, which is used for waittime below
		driveRate	!? { motorInstructionRate = driveRate };

		// make sure the routine hasn't already been started
		followRoutine !? {followRoutine.stop};

		followRoutine = Routine.run( {
			var maxNextDist, sent, catchup = 1;

			inf.do{
				if(mode != "Alarm", {
					// poll the control bus for a new position
					aControlBus.get({ |busnum, goTo|
						var deltaFromWorld, deltaFromLast, nextPos, nextFeed;

						maxNextDist		= maxDegPerSec / motorInstructionRate;

						// distance from the latest world position
						deltaFromWorld	= goTo - wPos[0];
						// distance from the last scheduled destination
						deltaFromLast	= goTo - lastDest;

						debug.if{
							postf(
								"world\t\t\t%
								lastDest\t\t%
								goTo\t\t\t%
								maxNextDist\t\t%
								deltaFromWorld\t%
								deltaFromLast\t%\n",
								wPos[0], lastDest, goTo, maxNextDist, deltaFromWorld, deltaFromLast
							);
							postf( "streamBuf\t%\n\n", streamBuf );
						};

						// is the instruction buffer starving ?
						starving = (streamBuf.size < minMoveQueue);
						this.changed(\starving, starving);

						// is it lagging too far behind the world?
						lagging = (deltaFromWorld > maxLagDist);
						this.changed(\lagging, lagging);

						// is it lagging too far behind the world?
						(deltaFromWorld > maxLagDist).if(
							{ lagging = true; debug.if{"world is LAGGING".postln} },
							{ lagging = false }
						);

						if( deltaFromLast.abs > maxNextDist,
							// is it trying to go farther than a maximum single drive instruction?
							{
								// limit the next instruction to a max rate and distance
								nextPos = lastDest + (maxNextDist * deltaFromLast.sign);
								nextFeed = maxFeed;
								debug.if{"Exceeding max move - limiting next destination".postln};
							},{

								// a regular destination and feed
								nextPos = goTo;
								nextFeed = feedSpec.map(deltaFromLast.abs/maxNextDist);

								if( lagging,
									// instruct to move further, bump up the next feed rate, clipping at max feed
									{
										// nextPos = lastDest + (deltaFromLast * 1.3);
										nextFeed = [(nextFeed * 1.2), maxFeed].minItem;
									},
									// // slow down if the instruction list is starving
									// {
									// 	if( starving, {
									// 		// nextFeed = nextFeed * 0.8;
									// 		// "STARVING - slowing down the feed".postln;
									// 		// catchup = catchup * 1.05;
									// 	}, { catchup = 1 });
									// }
								);
						});

						// try to send the move, returns false if no room in buffer
						sent = this.submitMove(nextPos.round(0.1), nextFeed.round(1));

						if( sent,
							{
								lastDest = nextPos;
								this.changed(\sent, 1);

								debug.if{
									postf( "move sent, RX BUFSIZE:\t%\n", streamBuf.sum);
									postf( "next move/feed:\t%\n\n\n", [nextPos, nextFeed]);
								};
							},{
								debug.if{ "skipping move".postln };
								this.changed(\sent, 0);
							}
						);


					});

					// rate to send G-code positions to GRBL
					// (motorInstructionRate * catchup).reciprocal.wait
					motorInstructionRate.reciprocal.wait

					},{"won't follow in ALARM mode".postln;}
				)
			}
		});
	}
*/