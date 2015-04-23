RoverDriver {
	var <arduino, <>camAddr;
	var <>mSeparation, <>x0, <>y0, <>cOffset = 2.5;
	var <>numCols, <>numRows, <>spanX, <>spanY;
	var <captureTask, <camPts;
	var <posTxtList;

	*new { |anArduinoGRBL, cameraNetAddr|
		^super.newCopyArgs( anArduinoGRBL, cameraNetAddr );
	}

		// all args in inches
	// motorSeparation: distance between motors (or pulleys)
	// originX, originY: offset from the rig's limit to set the capture canvas's origin 0,0
	// camOffset: offset from the end of the cable at the rover to the camera's center
	rigDimensions_ { | motorSeparation, originInsetX, originInsetY, camOffset |
		motorSeparation !? { mSeparation = motorSeparation };
		originInsetX !? { x0 = originInsetX };
		originInsetY !? { y0 = originInsetY };
		camOffset !? { cOffset = camOffset };
	}

	captureDimensions_ { |nCols, nRows, spanx, spany|
		nCols !? { numCols = nCols };
		nRows !? { numRows = nRows };
		spanx !? { spanX = spanx };
		spany !? { spanY = spany };
	}

	// Returns a 2D array of of rows capture points for subsequent processing.
	// The points are indices into the grid, i.e. Point(3,7) col 3, row 7.
	// These points are then reordered in order of execution for captureTask.
	getCamPointRows {
		^numRows.collect{|r|
			numCols.collect{|c|
				(c % numCols)@(r % numRows) // the index Point
		}}
	}

	gridCapture { arg rowsFirst=true, leftToRight=true, topDown=true, wrap=false, displayPath=true;

		this.checkCaptureDimInit;

		camPts = this.getCamPointRows;

		rowsFirst.if({
			topDown.not.if{ camPts = camPts.reverse };
			leftToRight.not.if{
				camPts = camPts.collect(_.reverse)
			};
			wrap.if{ camPts = camPts.collect{ |row, i| i.even.if({row},{row.reverse})  } }
		},{
			camPts = camPts.flop;
			leftToRight.not.if{ camPts = camPts.reverse };
			topDown.not.if{
				camPts = camPts.collect(_.reverse)
			};
			wrap.if{ camPts = camPts.collect{ |row, i| i.even.if({row},{row.reverse})  } };
		});

		camPts = camPts.flat;

		displayPath.if{ this.displayPath };
	}

	randomPathCapture { arg displayPath=true;

		this.checkCaptureDimInit;

		camPts = this.getCamPointRows.flat.scramble;
		displayPath.if{ this.displayPath };
	}


	customPathCapture { arg pointArray, displayPath=true;
		var testRect;

		this.checkCaptureDimInit;

		(pointArray.size != (numCols*numRows)).if{
			warn("pointArray provided doesn't match the number of capture points on the grid!") };

		// check points are within bounds of capture plane
		testRect = Rect(0,0,numCols,numRows);
		pointArray.do{ |pt|
			if( testRect.containsPoint(pt).not ){
				format("Point % is not within the bounds of the capture grid!", pt).throw }
		};

		camPts = pointArray;
		displayPath.if{ this.displayPath };
	}

	checkCaptureDimInit {

		[numCols, numRows, spanX, spanY].includes(nil).if{
			format(
				"Not all capture dimensions are defined:\n\tnumCols %\n\tnumRows %\n\tspanX %\n\tspanY %\nUse .captureDimensions to set all of these values.", numCols, numRows, spanX, spanY
		).throw };

	}

	goTo { |xPos, yPos, feed|
		arduino.goTo_(*this.xy2ab(xPos, yPos));
	}

	initCapture { | autoAdvance=true, stepWait=5, waitToSettle=1.0, waitAfterPhoto=1.0, travelTimeOut=30, stateCheckRate=5 |

		captureTask !? { captureTask.stop.clock.clear };
		arduino.state; // update internal ArduinoGRBL state bookkeeping

		// postf("This capture will take approximately % minutes.\n", );

		captureTask = Task({
			var xStep, yStep, stateCheckWait;

			xStep = spanX/(numCols-1);
			yStep = spanY/(numRows-1);
			stateCheckWait = stateCheckRate.reciprocal;

			camPts.do{ |indexPoint, i|
				var moveStart, now;
				moveStart = Main.elapsedTime;
				now  = Main.elapsedTime - moveStart;

				postf( "Travelling to index [%, %] ([%, %])\n",
					indexPoint.x, indexPoint.y, indexPoint.x * xStep, indexPoint.y * yStep);

				this.goTo( indexPoint.x * xStep, indexPoint.y * yStep );

				// update the GUI if it was made
				posTxtList !? { { posTxtList.at(i).background_(Color.yellow) }.defer };

				autoAdvance.if(
					{
						// let the motor get going, GRBLE state will be "Run"
						0.3.wait;
						// wait for the motore to reach it's destination
						while( { (arduino.mode != "Idle") and: ( now < travelTimeOut ) },{
							stateCheckWait.wait;
							now  = Main.elapsedTime - moveStart;
						});

						// check for timeout
						(now >= travelTimeOut).if{
							"Travel timed out! Check the status of your capture. Capture Routine is paused".error;
							this.pause; };
					},{
						// or wait a fixed amount of time
						stepWait.wait;
					}
				);

				// let the camera settle after moving
				waitToSettle.wait;

				// take the photo
				camAddr.sendMsg("/camera", "snap"); " SNAP".postln;
				posTxtList !? { { posTxtList.at(i).background_(Color.green) }.defer };
				// give the photo time to complete capture (incase of lag) before moving on
				waitAfterPhoto.wait;
			};

			"Capture Finished!".postln;
		});
	}

	stop { captureTask !? { captureTask.stop } }
	play { captureTask !? { captureTask.play } }
	pause { this.stop }
	run { this.play }
	reset { captureTask !? { captureTask.stop.reset } }


	// return to the origin of the grid
	goHome { this.goTo(0,0) }


	displayPath {

		posTxtList !? { posTxtList.clear };
		posTxtList = Order(numCols * numRows);

		Window("Capture Order").layout_(
			VLayout(
				*numRows.collect({ |row|
					HLayout(
						*numCols.collect({ |col|
							var txt, dex;
							camPts.do{|pnt, i|
								if((pnt.x == col) and: (pnt.y == row)) { dex = i }
							};

							txt = StaticText().string_(dex)
							.stringColor_(Color.white)
							.background_(Color.black.alpha_( (dex+1 / (numCols*numRows) * 0.8) ));

							posTxtList.put(dex, txt);

							txt
						})
					)

				})
			)
		).front;

	}


	// convert image capture coordinates to the rig coordinates
	xy2ab { |inX,inY|
		^[
			sqrt( (x0 + inX).pow(2) +  (y0 + inY).pow(2) ) - cOffset,
			sqrt( (mSeparation - (x0 + inX)).pow(2) +  (y0 + inY).pow(2) - cOffset )
		]
	}

}