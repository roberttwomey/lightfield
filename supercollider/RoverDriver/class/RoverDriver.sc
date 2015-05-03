// TODO: when on a fixed-advance routine, how to anticipate long moves across the capture plane?
// workaround - use gridCapture and be sure wrap = true so the steps are small

RoverDriver {
	var <arduino, <>camAddr;
	var <>mSeparation, <>x0, <>y0, <>cOffset = 2.5;
	var <>numCols, <>numRows, <>spanX, <>spanY, <xStep, <yStep, <lenA, <lenB;
	var <pulloffHome;
	var <captureTask, <camPts;
	var <posTxtList, <photoTaken = false, <handshakeResponder;
	var rigDimDefined = false, capDimDefined = false;
	var <dataFile, <captureData, <dataDir;

	*new { |anArduinoGRBL, cameraNetAddr|
		^super.newCopyArgs( anArduinoGRBL, cameraNetAddr );
	}

	// all args in inches
	// motorSeparation: distance between motors (or pulleys)
	// MachineX/Y:	after homing and pulling off, MachineX/Y machine coordinates (usually negative)
	// lengthA/B:	after homing and pulling off, lengthA and lengthB are the distance from the pulley to the middle Rover's width (where the cables would intersect if they extended)
	// camOffset:	offset from the end of the cable at the rover to the camera's center
	rigDimensions_ { | motorSeparation, machineX, machineY, lengthA, lengthB | //, camOffset |
		// set the arduino world offset from the machine coordinate space
		arduino.worldOffset_( (lengthA.neg + machineX),  (lengthB.neg + machineY));
		motorSeparation !? { mSeparation = motorSeparation };
		// camOffset !? { cOffset = camOffset };
		pulloffHome = lengthA@lengthB;
		lenA = lengthA;
		lenB = lengthB;
		rigDimDefined = true;
	}

	// all args in inches
	// captureSpanX: width of the capture plane
	// captureSpanY: height of the capture plane
	// insetY: vertical offset from the rig's pulley height to the 0,0 camera capture position
	// nCols, nRows: number of rows and columns of subimages to capture
	captureDimensions_ { |captureSpanX, captureSpanY, insetY, nCols, nRows |
		var insetX;

		rigDimDefined.not.if{ error("rig dimensions are not yet defined!") };

		captureSpanX !? { spanX = captureSpanX };
		captureSpanY !? { spanY = captureSpanY };

		insetX = mSeparation - spanX / 2;
		x0 = insetX;
		insetY !? { y0 = insetY };

		nCols !? { numCols = nCols };
		nRows !? { numRows = nRows };

		xStep = spanX / (numCols-1);
		yStep = spanY / (numRows-1);

		this.checkCornerExtents;

		capDimDefined = true;
	}

	checkCornerExtents {
		var widthLim, hypotLim;

		widthLim = spanX + ((mSeparation - spanX) / 2);
		hypotLim = hypot(spanX + x0, spanY + y0);

		if( (lenA < widthLim) or: (lenB < widthLim) ){
			warn( "Rover will not reach the top corners at the specified X span"; );
		};

		if( (lenA < hypotLim) or: (lenB < hypotLim) ){
			warn( "Rover will not reach the bottom corners at the specified capture dimensions"; );
		};

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

	goTo_ { |xPos, yPos, feed|
		arduino.goTo_(*this.xy2ab(xPos, yPos));
	}

	initCapture { | autoAdvance=true, handShake=false, stepWait=5, waitToSettle=1.0, waitAfterPhoto=1.0, travelTimeOut=30, stateCheckRate=5, writePosData=true, dataDirectory, fileName |

		// this Order corresponds to capture points in GRID (not capture) order
		// rows L>R, Top>Bottom
		captureData = Order(numRows*numCols);

		captureTask !? { captureTask.stop.clock.clear };
		arduino.state; // update internal ArduinoGRBL state bookkeeping

		// only send start if using raspifastcamd
		//camAddr.sendMsg("/camera", "start"); // make sure Rover is ready to take photos

		(handShake and: handshakeResponder.isNil).if{ this.prCreateHandshakeResponder };

		// TODO postf("This capture will take approximately % minutes.\n", );

		captureTask = Task({
			var stateCheckWait, advanceFunc, now = 0.0;

			photoTaken = false;
			stateCheckWait = stateCheckRate.reciprocal;

			advanceFunc = handShake.if(
				{{ (arduino.mode != "Idle") and: ( now < travelTimeOut ) and: (photoTaken == true) }},
				{{ (arduino.mode != "Idle") and: ( now < travelTimeOut ) }}
			);



			camPts.do{ |indexPoint, i|
				var moveStart, gridDest;
				var camParams; // camera parameters for paramsnap
				moveStart = Main.elapsedTime;
				now  = Main.elapsedTime - moveStart;
				gridDest = indexPoint * (xStep@yStep);

				postf( "Travelling to index [%, %] ([%, %])\n",
					indexPoint.x, indexPoint.y, gridDest.x, gridDest.y);

				this.goTo_( gridDest.x, gridDest.y );

				// update the GUI if it was made
				posTxtList !? { { posTxtList.at(i).background_(Color.yellow) }.defer };

				autoAdvance.if(
					{
						// let the motor get going, GRBLE state will be "Run"
						0.2.wait;
						arduino.state; // update the state
						0.2.wait;

						// looping to wait for the motore to have reached it's destination and
						// to have taken the last photo (if handshaking)
						while( advanceFunc, {
							(stateCheckWait/2).wait;
							arduino.state;
							(stateCheckWait/2).wait;
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

				photoTaken = false;

				// let the camera settle after moving
				waitToSettle.wait;

				// take the photo with raspicamfastd
				// camAddr.sendMsg("/camera", "snap"); "\tSNAP".postln;

				// take photo with raspistill, custom file-naming:
				camParams = format("-t 1 -o /home/pi/lfimages/frame_%.jpg", i);
				camAddr.sendMsg("/camera", "paramsnap", camParams);

				// log it for the dataFile
				captureData.put(
					(numCols * indexPoint.y + indexPoint.x).asInt, // order in the grid
					// image index, gridDexX, gridDexY, gridPosX, gridPosY
					[ i, indexPoint.x, indexPoint.y, gridDest.x, gridDest.y ]
				);

				// update the GUI
				posTxtList !? { { posTxtList.at(i).background_(Color.green) }.defer };

				// give the photo time to complete capture (incase of lag) before moving on
				waitAfterPhoto.wait;
			};

			writePosData.if{ this.writeDataToFile( dataDirectory, fileName ) };
			"Capture Finished!".postln;
		});
	}

	writeDataToFile { |dataDirectory, fileName|
		var name;

		// prepare a data file to write capture data to
		dataDir = if( dataDirectory.isNil,
			{ dataDir ?? "~/Desktop/".standardizePath },
			{ File.exists(dataDirectory).not.if(
				{	warn("specified data directory doesn't exist, writing to desktop.");
					"~/Desktop/".standardizePath;
				},{ dataDirectory }
			)
			}
		);
		(dataDir.last == $/).not.if{dataDir = dataDir ++ "/"};

		name = fileName !? { fileName.contains(".txt").if({ fileName }, {fileName ++ ".txt"}) };
		name ?? { name = Date.getDate.stamp ++ ".txt" };

		dataFile !? {dataFile.close};  // close any formerly open files
		dataFile = File(dataDir++name,"w");

		captureData.do{|capturePointData|
			// image index, gridDexX, gridDexY, gridPosX(inches), gridPosY(inches)
			capturePointData.do{|val|
				dataFile.putString( val.asString ++ "\n")
			};
		};

		dataFile.close;
	}

	readDataFile { |path, postResults = true|
		this.class.readDataFile( path, postResults )
	}

	*readDataFile { |path, postResults = true|
		var data;

		data = FileReader.readInterpret( path, skipEmptyLines: true, delimiter: $\n).at(0).clump(5);

		postResults.if{
			"| image index | gridDexX | gridDexY | gridPosX(inches) | gridPosY(inches) |".postln;
			data.do(_.postln);
		};
	}

	stop { captureTask !? { captureTask.stop } }
	play { captureTask !? { captureTask.play } }
	pause { this.stop }
	run { this.play }
	reset { captureTask !? { captureTask.stop.reset } }


	// return to the location Rover is after pulloff (to check no slippage)
	goTopulloffHome { arduino.goTo_(pulloffHome.x, pulloffHome.y) }

	goToFirstCapturePoint {this.goTo_( camPts[0].x * xStep, camPts[0].y * yStep ); }

	prCreateHandshakeResponder {
		handshakeResponder = OSCdef(\cameraHandshake, {
			"Rover snapped a photo".postln;
			photoTaken = true;
		}, '/cameraSnapped');
	}

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

							txt = StaticText().string_(dex).align_('center')
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
	xy2ab { | captureX, captureY |
		var gridX, gridY, a, b;

		gridX = captureX+x0;
		gridY = captureY+y0;

		a = hypot( gridX, gridY );
		b = hypot( mSeparation - gridX, gridY);

		^[a,b]
	}

	// // convert image capture coordinates to the rig coordinates
	// xy2ab { |inX,inY|
	// 	^[
	// 		sqrt( (x0 + inX).pow(2) +  (y0 + inY).pow(2) ) - cOffset,
	// 		sqrt( (mSeparation - (x0 + inX)).pow(2) +  (y0 + inY).pow(2) - cOffset )
	// 	]
	// }

}