// RoverDriver2 is to replace RoverDriver once tested
// This uses a new coordinate calculation, for the second generation
// of the suspended rover capture mechanism

// TODO: when on a fixed-advance routine, how to anticipate long moves across the capture plane?
// workaround - use gridCapture and be sure wrap = true so the steps are small

RoverDriver2 {
	var <grbl, <>camAddr;

	var <machSpan; // dist between cable axis points
	var <pulloff; // grbl pulloff after finding limit
	var <capWidth, <capHeight; // width and height of capture area
	var <yOffset; // offset between the height of the axis points and the top of the capture area
	var <limOffset; // distance between pivot point and rover tie point when retracted to limit point
	var <tetherSep; // distance between 2 tether points on the camera mount


	var <>mSeparation, <>x0, <>y0, <>cOffset = 2.5;
	var <>numCols, <>numRows, <xStep, <yStep;
	var <captureTask, <camPts;
	var <posTxtList, <photoTaken = false, <handshakeResponder;
	var rigDimDefined = false, capDimDefined = false;
	var <dataFile, <captureData, <dataDir;

	// raspstill camera parameters
	var <>sharpen = 25, <>meter = "average", <>whiteBalance = "auto";
	var <>shutter; // specified in microseconds, max 6000000 (6s)

	*new { |aGrbl, cameraNetAddr|
		^super.newCopyArgs( aGrbl, cameraNetAddr );
	}

	printOn { arg stream;
		// not a compileable string
		stream << this.class.name
		<< "\nmachSpan\t" << machSpan
		<< "\ncapWidth\t" << capWidth
		<< "\ncapHeight\t" << capHeight
		<< "\nyOffset\t" << yOffset
		<< "\nlimOffset\t" << limOffset
		<< "\npulloff\t"<< pulloff
		<< "\ntetherSeparation\t"<< tetherSep;
	}
	/*
	// All args in inches.
	// -machineSpan: dist between cable axis points
	// -limitOffset: dist between axis point and camera tether point (0 if camera contacts limit directly)
	// -captureWidth, captureHeight: width and height of capture area
	// -captureYoffset: offset between the height of the axis points and the top of the capture area
	*/
	rigDimensions_ { |machineSpan, limitOffset=0, tetherSeparation=0, captureWidth, captureHeight, captureYoffset|
		var mSpan, poH, poW, po;

		mSpan = machineSpan - tetherSeparation;

		if (captureWidth >= (machineSpan-(2*limitOffset))) {
			Error("width must be less than [motorSeparation - (2*limitOffset)]").throw
		};

		poH = captureHeight + captureYoffset;
		poW = mSpan/2;
		po = (poH.squared + poW.squared).sqrt - limitOffset;

		[poH, poW, po].postln;

		if (po < (machineSpan - (2*limitOffset))) {
			postf("(pulloff + limOffset) : %\nmotorSeparation : %\n", (po + limitOffset), machineSpan);
			Error(
				"Pulloff must be larger than the motor separation. " ++
				"Consider lowering the bottom bound of the canvas or bringing the motors closer together."
			).throw
		};
		"here".postln;
		// after error checks, set instance vars
		machSpan = mSpan;
		capWidth = captureWidth;
		capHeight = captureHeight;
		yOffset = captureYoffset;
		limOffset = limitOffset;
		pulloff = po;
		tetherSep = tetherSeparation;

		// set grbl pulloff
		grbl.homingPullOff_(pulloff);

		rigDimDefined = true;
	}

	// all args in inches
	// nCols, nRows: number of rows and columns of subimages to capture
	captureDimensions_ { |nCols, nRows |

		rigDimDefined.not.if{ Error("rig dimensions are not yet defined!").throw };
		nCols ?? { Error("Number of columns is undefined.").throw };
		nRows ?? { Error("Number of rows is undefined.").throw };

		numCols = nCols;
		numRows = nRows;

		xStep = capWidth / (numCols-1);
		yStep = capHeight / (numRows-1);

		capDimDefined = true;
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

		[numCols, numRows, capWidth, capHeight].includes(nil).if{
			format(
				"Not all capture dimensions are defined:\n\tnumCols %\n\tnumRows %\n\tcapWidth %\n\tcapHeight %\nUse .captureDimensions to set all of these values.", numCols, numRows, capWidth, capHeight
		).throw };

	}

	// xPos, yPos: x and y coords, in capture area space
	// [0,0] is the top left of the capture area
	goTo_ { |xPos, yPos, feed|
		var grblx, grbly;
		#grblx, grbly = this.captureToMachineCoords(xPos, yPos);
		if (feed.notNil) {
			grbl.goTo_(grblx, grbly, feed);
		} {
			grbl.goTo_(grblx, grbly);
		};
	}

	initCapture { | autoAdvance=true, handShake=false, stepWait=5, waitToSettle=1.0, waitAfterPhoto=1.0, travelTimeOut=30, stateCheckRate=5, writePosData=true, dataDirectory, fileName |

		// this Order corresponds to capture points in GRID (not capture) order
		// rows L>R, Top>Bottom
		captureData = Order(numRows*numCols);

		captureTask !? { captureTask.stop.clock.clear };
		grbl.state; // update internal ArduinoGRBL state bookkeeping

		// only send start if using raspifastcamd
		//camAddr.sendMsg("/camera", "start"); // make sure Rover is ready to take photos

		(handShake and: handshakeResponder.isNil).if{ this.prCreateHandshakeResponder };

		// TODO postf("This capture will take approximately % minutes.\n", );

		captureTask = Task({
			var stateCheckWait, advanceFunc, now = 0.0;

			photoTaken = false;
			stateCheckWait = stateCheckRate.reciprocal;

			advanceFunc = handShake.if(
				{{ (grbl.mode != "Idle") and: ( now < travelTimeOut ) and: (photoTaken == true) }},
				{{ (grbl.mode != "Idle") and: ( now < travelTimeOut ) }}
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
						grbl.state; // update the state
						0.2.wait;

						// looping to wait for the motore to have reached it's destination and
						// to have taken the last photo (if handshaking)
						while( advanceFunc, {
							(stateCheckWait/2).wait;
							grbl.state;
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

				// take photo with raspistill, custom file-naming, params settable externally, see top of this class for defaults/setters:
				camParams = format(
					"-t 1 -o /home/pi/lfimages/frame_%.jpg", i.asString.padLeft(4, "0"));
				/* -n -sh % -mm % -awb %",
					i.asString.padLeft(4, "0"), sharpen, meter, whiteBalance ); */
				shutter !? { camParams = camParams ++ format(" -ss %", shutter) }; // add shutter control if specified
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

			writePosData.if{

				this.writeDataToFile( dataDirectory, fileName )
			};
			"Capture Finished!".postln;
		});
	}

	// take a test shot with the current camera exposure settings
	testShot { |fileName|
		var camParams, fName;
		fName = fileName ?? {Date.getDate.rawSeconds};
		camParams = format(
			"-t 1 -o /home/pi/lfimages/testShot_%.jpg", fName);
		// camParams = format(
		// 	"-t 1 -o /home/pi/lfimages/_testShot_%.jpg -n -sh % -mm % -awb %",
		// fName, sharpen, meter, whiteBalance );
		// shutter !? { camParams = camParams ++ format(" -ss %", shutter) }; // add shutter control if specified
		camAddr.sendMsg("/camera", "paramsnap", camParams);
	}

	writeDataToFile { |dataDirectory, fileName|
		var name;

		// prepare a data file to write capture data to
		dataDir = if( dataDirectory.isNil,
			{ dataDir ?? "~/Desktop/".standardizePath },
			{ File.exists(dataDirectory).not.if(
				{	warn("Specified data directory doesn't exist, writing to desktop.");
					"~/Desktop/".standardizePath;
				},{ dataDirectory }
			)
			}
		);
		(dataDir.last == $/).not.if{dataDir = dataDir ++ "/"};

		name = fileName !? { fileName.contains(".txt").if({ fileName }, {fileName ++ ".txt"}) };
		name ?? { name = "RoverCaptureData_" ++ Date.getDate.stamp ++ ".txt" };

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
	goTopulloffHome { grbl.goTo_(0,0) } // note use of grbl goTo, not this.goTo

	goToFirstCapturePoint { this.goTo_( camPts[0].x * xStep, camPts[0].y * yStep ); }
	goToTopLeft			{ this.goTo_(0,0) }
	goToTopRight		{ this.goTo_(capWidth,0) }
	goToBottomLeft	{ this.goTo_(0,capHeight) }
	goToBottomRight	{ this.goTo_(capWidth, capHeight) }
	goToTop				{ this.goTo_(capWidth/2,0) }
	goToRight				{ this.goTo_(capWidth,capHeight/2) }
	goToLeft				{ this.goTo_(0,capHeight/2) }
	goToBottom			{ this.goTo_(capWidth/2,capHeight) }

	feed_ {|rate| grbl.feed_(rate) }

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
	// gox, goy: x and y coords, in capture area space
	// [0,0] is the top left of the capture area
	captureToMachineCoords { | captureX, captureY |
		var machx, machy;	// the destination, in machine space, defined by limits
		var macha, machb;	// length a and b (cable lengths from axis points)
		var destx, desty;		// x,y destination sent to grbl
		var offsetx, offsety;  // offset applied to machine x and y on account of tilted camera mount

		machx = captureX + ((machSpan-capWidth)/2);
		machy = captureY + yOffset;

		// macha = (machx.squared + machy.squared).sqrt;
		// machb = ((machSpan-machx).squared + machy.squared).sqrt;

		// turn machine xy position into cable lengths A and B
		#macha, machb = this.getMachineAB( machx, machy );

		// compensate for the tilt in the camera mount
		// #offsetx, offsety = this.addTiltOffset(macha, machb);
		// // recalc with new x and y machine coords
		// // note this isn't totally accurate but should help some...
		// #macha, machb = this.getMachineAB( machx+offsetx, machy+offsety);

		destx = macha - pulloff + limOffset;
		desty = machb - pulloff + limOffset;

		^[destx, desty]
	}

	getMachineAB { |machx, machy|
		var macha, machb;
		macha = (machx.squared + machy.squared).sqrt;
		machb = ((machSpan-machx).squared + machy.squared).sqrt;
		^[macha, machb]
	}

	// this hasn't been properly worked out...
	addTiltOffset {|lenA, lenB|
		var a,b,c; // angles
		var sideA, sideB, sideC; // sides
		var sideA_sqr, sideB_sqr, sideC_sqr; // sides
		var macha, machb; // resulting cable lengths
		var tilt; // tilt from vertical
		var tiltleft; // bool if tilt is to left
		var sideX, sideY, sideH; // sides of the tilt offset triangle
		var shiftup, shiftright;
		var abRatio;

		/* establish amount of tilt */
		sideA = lenA;
		sideB = lenB;
		sideC = machSpan - tetherSep;

		#sideA_sqr, sideB_sqr, sideC_sqr = [sideA, sideB, sideC].collect(_.squared);

		a = acos( (sideB_sqr + sideC_sqr - sideA_sqr) / (2*sideB*sideC));
		b = acos( (sideC_sqr + sideA_sqr - sideB_sqr) / (2*sideC*sideA));
		// a = acos( (sideB_sqr + sideC_sqr − sideA_sqr) / (2*sideB*sideC) );
		// b = acos( sideC_sqr + sideA_sqr − sideB_sqr / (2*sideC*sideA) );
		c = pi - (a+b);

		tilt = c.half + b - (pi/2);
		tiltleft = tilt.isNegative;

		postf("[a,b,c]: %\n[sideA, sideB, sideC]: %\ntilting left: %: %\n", [a,b,c].raddeg, [sideA, sideB, sideC], tiltleft, tilt.raddeg);

		/* calc offset */
		sideH = tetherSep/2; // div by 2 because reference is center of tetherSep
		sideX = cos(tilt)*sideH;
		sideY = sin(tilt.abs)*sideH;

		abRatio = lenA/lenB;
		if (tiltleft.not) { abRatio = abRatio.reciprocal };
		// shiftup = ((sideC - sideA) * abRatio);
		// shiftright = sideB * abRatio;
		shiftup = sideY * abRatio;
		shiftright = (sideH - sideX) * abRatio;
		if (tiltleft) { shiftright = shiftright.neg };
		postf("abRatio: %\n", abRatio);
		"shifting coords: ".post; [shiftright, shiftup.neg].postln;

		^[shiftright, shiftup.neg]
	}
}