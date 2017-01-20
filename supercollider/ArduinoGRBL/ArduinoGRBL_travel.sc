// methods used to drive motor travel automatically

+ ArduinoGRBL {

	followSerialBufXY_ { |aControlBusX, aControlBusY, driveRate, updateStateHz = 5, gui = false|

		aControlBusX ?? {"Must provide an X control bus to follow".error};
		aControlBusY ?? {"Must provide a Y control bus to follow".error};

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
			this.updateState_(true, updateStateHz);
		};

		// ensure lastDest has a value
		lastDest	?? { lastDest = wPos[0..1].asPoint };
		// forward driveRate to motorInstructionRate, which is used for waittime below
		driveRate	!? { motorInstructionRate = driveRate };

		// start the synth that forwards the driving control signal to the lang
		server ?? {server = Server.default};
		server.waitForBoot({

			followSynthXY.isNil.if(
				{
					var followDef;
					followDefXY = CtkSynthDef( \busFollowXY++id, {// make the def unique w/ id
						| followBusX, followBusY, sendRate|
						SendReply.ar(
							Impulse.ar(sendRate),
							'/busFollowXY'++id,
							[In.kr(followBusX, 1), In.kr(followBusY, 1)]
						)
					});
					server.sync;

					followSynthXY = followDefXY.note
					.followBusX_(aControlBusX)
					.followBusY_(aControlBusY)
					.sendRate_(motorInstructionRate)
					.play
				},{
					followSynthXY
					.followBusX_(aControlBusX)
					.followBusY_(aControlBusY)
					.sendRate_(motorInstructionRate)
					.run;
				}
			);
		});

		// create a responder to receive the driving control signal from the server
		followResponderXY ?? {
			followResponderXY = OSCFunc(
				{	|msg, time, addr, recvPort|
					var goTo, maxNextDist, sent, catchup = 1;
					var deltaFromWorld, deltaFromLast, nextPos, nextFeed;

					if(mode != "Alarm", {

						// the target destination from the control sig
						goTo = msg[3..4].asPoint;

						maxNextDist	= maxDegPerSec / motorInstructionRate;

						// distance from...
						deltaFromWorld	= goTo.dist(wPos[0..1].asPoint);  // the latest world position
						deltaFromLast	= goTo.dist(lastDest); // the last scheduled destination

						// is the instruction buffer starving ?
						starving = (streamBuf.size < minMoveQueue);
						this.changed(\starving, starving);

						// is it lagging too far behind the world?
						lagging = (deltaFromWorld > maxLagDist);
						this.changed(\lagging, lagging);

						if( deltaFromLast > maxNextDist,
							// is it trying to go farther than a maximum single drive instruction?
							{ 	// limit the next instruction to a max rate and distance
								var difRatio;
								difRatio = maxNextDist / deltaFromLast;

								nextPos = lastDest + (goTo - lastDest * difRatio);
								nextFeed = maxFeed;
								debug.if{"Exceeding max move - limiting next destination".postln};
							},
							{	// a regular destination and feed
								nextPos = goTo;
								nextFeed = feedSpec.map(deltaFromLast/maxNextDist);

								nextFeed = nextFeed * (1+(overDrive * (deltaFromLast/maxNextDist)));

								// slow down if the instruction list is starving
								if( starving, {
									nextFeed = nextFeed * underDrive;
									debug.if{"STARVING - under driving the feed".postln};
									}
								);

								// if( lagging,
								// 	{	// instruct to move further, bump up the next feed rate
								// 		// clipping at max feed
								// 		nextFeed = [
								// 			(nextFeed * 1.2),
								// 			maxFeed
								// 		].minItem;
								// 	},
								// 	{	// slow down if the instruction list is starving
								// 		if( starving, {
								// 			nextFeed = nextFeed * underDrive;
								// 			debug.if{"STARVING - under driving the feed".postln};
								// 			} //, { catchup = 1 }
								// 		);
								// 	}
								// );
						});

						// try to send the move, returns false if no room in buffer
						sent = this.submitMoveXY(
							nextPos.x.round(0.001),
							nextPos.y.round(0.001),
							nextFeed.round(1)
						);

						if( sent,
							{
								lastDest = nextPos;
								this.changed(\sent, 1);
							},{
								debug.if{ "skipping move".postln };
								this.changed(\sent, 0);
						});

						},{ "won't follow in ALARM mode".postln }
					);

				},
				'/busFollowXY'++id // the OSC path
			);
		}
	}

	// used by followSerialBufXY_
	submitMoveXY { |toX, toY, feed|
		var cmd, size;

		cmd 	= "G01";

		toX		!? {cmd = cmd ++ "X" ++ toX.clip(xClipLow, xClipHigh)};
		toY		!? {cmd = cmd ++ "Y" ++ toY.clip(yClipLow, yClipHigh)};
		feed	!? {cmd = cmd ++ "F" ++ feed};
		size 	= cmd.size + 1; // add 1 for the eol char added in .send

		// only send the move if the message won't
		// overflow the serial buffer buffer
		if ( (size + streamBuf.sum) < rx_buf_size,
			{ this.send(cmd); ^true },{^false}
		);

		toX.inRange(xClipLow, xClipHigh).not.if{warn("clipping the requested X position!")};
		toY.inRange(yClipLow, yClipHigh).not.if{warn("clipping the requested Y position!")};
	}


	follow_ { |ctlFade, driveRate|

		stateRoutine.isPlaying.not.if{ this.updateState_(true) };

		lastDest	?? { lastDest = wPos[0] };
		driveRate	!? { motorInstructionRate = driveRate };

		followRoutine = Routine.run( {
			var maxNextDist, catchup = 1;

			inf.do{
				if(mode != "Alarm", {

					// NOTE:	change this buffer value retrieving message to a SendReply scheme
					// 			from a running synth that polls the bus values
					// poll the control bus for a new position
					ctlFade.controlBus.get({ |busnum, goTo|
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

						if( deltaFromLast.abs > maxNextDist,
							// is it trying to go farther than a maximum single drive instruction?
							{
								// limit the next instruction to a max rate and distance
								nextPos = lastDest + (maxNextDist * deltaFromLast.sign);
								nextFeed = maxFeed;
								// "Exceeding max move - limiting next destination".postln;
							},{

								// a regular destination and feed
								nextPos = goTo;
								nextFeed = feedSpec.map(deltaFromLast.abs/maxNextDist);

								if( lagging,
									{	// instruct to move further, bump up the next feed rate,
										// clipping at max feed
										nextFeed = [(nextFeed * 1.2), maxFeed].minItem;
									},
									// slow down if the instruction list is starving
									{
										if( starving, {
											// nextFeed = nextFeed * 0.8;
											// "STARVING - slowing down the feed".postln;
											// catchup = catchup * 1.05;
										}, { catchup = 1 });
									}
								);
						});

						// [busnum, goTo].postln
						// ~az = goTo.postln;
						this.x_(nextPos.round(0.1), nextFeed.round(1));

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

	// used by follow_
	motorInstructionRate_ { |newRate|
		newRate !? {
			motorInstructionRate = newRate;
			followSynth !? {followSynth.sendRate_(motorInstructionRate)};
			followSynthXY !? {followSynthXY.sendRate_(motorInstructionRate)};
		}
	}

	// follow a control bus (ControlFade), polling it as often as is needed to keep the
	// serial buffer full
	followSerialBuf_ { |aControlBus, driveRate, updateStateHz = 5, gui = false|

		aControlBus ?? {"Must provide a control bus to follow".error};

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
			this.updateState_(true, updateStateHz);
		};

		// ensure lastDest has a value
		lastDest	?? { lastDest = wPos[0] };
		// forward driveRate to motorInstructionRate, which is used for waittime below
		driveRate	!? { motorInstructionRate = driveRate };

		// start the synth that forwards the driving control signal to the lang
		server ?? {server = Server.default};
		server.waitForBoot({

			followSynth.isNil.if(
				{
					var followDef;
					followDef = CtkSynthDef( \busFollow++id, {// make the def unique w/ id
						| followBus, sendRate|
						SendReply.ar(
							Impulse.ar(sendRate),
							'/busFollow'++id,
							In.kr(followBus, 1)
						)
					});
					server.sync;

					followSynth = followDef.note
					.followBus_(aControlBus)
					.sendRate_(motorInstructionRate)
					.play
				},{
					followSynth
					.followBus_(aControlBus)
					.sendRate_(motorInstructionRate)
					.run;
				}
			);
		});

		// create a responder to receive the driving control signal from the server
		followResponder ?? {
			followResponder = OSCFunc({
				|msg, time, addr, recvPort|

				var goTo, maxNextDist, sent, catchup = 1;
				var deltaFromWorld, deltaFromLast, nextPos, nextFeed;

				if(mode != "Alarm", {

					// the target destination from the control sig
					goTo = msg[3];

					maxNextDist	= maxDegPerSec / motorInstructionRate;

					// distance from...
					deltaFromWorld	= goTo - wPos[0];  // the latest world position
					deltaFromLast	= goTo - lastDest; // the last scheduled destination

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
					sent = this.submitMove(nextPos.round(0.001), nextFeed.round(1));

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

					},{ "won't follow in ALARM mode".postln }
				)
				},
				'/busFollow'++id // the OSC path
			);
		}
	}

	// used by followSerialBuf_
	submitMove { |toX, feed|
		var cmd, size;

		cmd 	= "G01";

		toX		!? {cmd = cmd ++ "X" ++ toX};
		// toY	!? {cmd = cmd ++ "Y" ++ toY};
		feed	!? {cmd = cmd ++ "F" ++ feed};
		size 	= cmd.size + 1; // add 1 for the eol char added in .send

		// only send the move if the message won't
		// overflow the serial buffer buffer
		if ( (size + streamBuf.sum) < rx_buf_size,
			{ this.send(cmd); ^true },{^false}
		);
	}



	unfollow {
		followSynth		!? {followSynth.pause};
		followSynthXY	!? {followSynthXY.pause};
		followRoutine	!? {followRoutine.stop};
		followView		!? {followView.free};
	}
}