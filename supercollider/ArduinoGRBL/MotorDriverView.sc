MotorDriverView {

	// copyArgs
	var driver, grbl, fr, historySecs;

	var scrn, scrnW, scrnH, <win, <userView, <ctlView;
	var <specs, <controls;
	var leftWidth, baseColor, titleHeight = 25, internalMargins = 3, internalSpacing = 2;

	*new { |aMotorDriver, anArduinoGRBL, fr = 5, historySecs = 3|
		^ super.newCopyArgs(aMotorDriver, anArduinoGRBL, fr, historySecs).init;
	}

	init {

		driver.addDependant(this);
		grbl.addDependant(this);

		grbl.updateState_(true);

		baseColor = Color.hsv(0.08952380952381, 0.94086021505376, 0.72941176470588, 1);

		specs = IdentityDictionary(know:true).putPairs([

			\center, IdentityDictionary(know:true).putPairs([
				\pan,	ControlSpec(grbl.xBoundHigh-2, grbl.xBoundLow+2,  default: 0),
				\tilt,	ControlSpec(grbl.yBoundHigh-2, grbl.yBoundLow+2,  default: 50),
			]),

			\range, IdentityDictionary(know:true).putPairs([
				\pan,	ControlSpec(0, grbl.xBoundHigh.abs*2, 5, 1, default: 15),
				\tilt,	ControlSpec(0, grbl.yBoundHigh.abs*2, 5, 1, default: 5),
			]),
			\basePeriod,	ControlSpec(2, 60, 3, default: 12),
			\numBasePeriodDivs,	ControlSpec(1, 8, step: 1, default: 1),
			\randPeriod,	ControlSpec(1, 10, default: 3),
		]);


		controls = IdentityDictionary(know: true).putPairs([

			\center,
			IdentityDictionary(know: true).putPairs([
				\pan,	IdentityDictionary(know: true).putPairs([

					\numBox, NumberBox()
					.action_({ |bx|
						driver.centerX_(bx.value);
					}).value_(driver.centerX),

					\slider, Slider()
					.action_({ |sl|
						driver.centerX_(specs.center.pan.map(sl.value));
					}).value_(specs.center.pan.unmap(driver.centerX)),
				]),

				\tilt,	IdentityDictionary(know: true).putPairs([

					\numBox, NumberBox()
					.action_({ |bx|
						driver.centerY_(bx.value);
					}).value_(driver.centerY),

					\slider, Slider()
					.action_({ |sl|
						driver.centerY_(specs.center.tilt.map(sl.value));
					}).value_(specs.center.tilt.unmap(driver.centerY)),
				]),
			]),

			\range,
			IdentityDictionary(know: true).putPairs([

				\pan,
				IdentityDictionary(know: true).putPairs([

					\numBox, NumberBox()
					.action_({ |bx|
						driver.rangeX_(bx.value);
					}).value_(driver.rangeX),

					\slider, Slider()
					.action_({ |sl|
						driver.rangeX_(specs.range.pan.map(sl.value));
					}).value_(specs.range.pan.unmap(driver.rangeX)),
				]),

				\tilt,
				IdentityDictionary(know: true).putPairs([

					\numBox, NumberBox()
					.action_({ |bx|
						driver.rangeY_(bx.value);
					}).value_(driver.rangeY),

					\slider, Slider()
					.action_({ |sl|
						driver.rangeY_(specs.range.tilt.map(sl.value));
					}).value_(specs.range.tilt.unmap(driver.rangeY)),
				]),
			]),

			\basePeriod,
			IdentityDictionary(know: true).putPairs([

				\numBox, NumberBox()
				.action_({ |bx|
					driver.basePeriod_(bx.value);
				}).value_(driver.basePeriod),

				\slider, Slider()
				.action_({ |sl|
					driver.basePeriod_(specs.basePeriod.map(sl.value));
				}).value_(specs.basePeriod.unmap(driver.basePeriod)),

				\checkBox, IdentityDictionary(know: true).putPairs([
					\pan, CheckBox().action_({|cb|
						cb.value.if{ driver.baseAxis_(0) };
					}).value_(driver.slowAxis == 0),
					\tilt, CheckBox().action_({|cb|
						cb.value.if{ driver.baseAxis_(1) };
					}).value_(driver.slowAxis == 1),
				]),
			]),

			\numBasePeriodDivs,
			IdentityDictionary(know: true).putPairs([

				\numBox, NumberBox()
				.action_({ |bx|
					driver.numBasePeriodDivs_(bx.value);
				}).value_(driver.numBasePeriodDivs),

				\slider, Slider()
				.action_({ |sl|
					driver.numBasePeriodDivs_(specs.numBasePeriodDivs.map(sl.value));
				}).value_(specs.numBasePeriodDivs.unmap(driver.numBasePeriodDivs)),

			]),

			\randPeriod,
			IdentityDictionary(know: true).putPairs([

				\numBox, NumberBox()
				.action_({ |bx|
					driver.randPeriod_(bx.value);
				}).value_(driver.randPeriod),

				\slider, Slider()
				.action_({ |sl|
					driver.randPeriod_(specs.randPeriod.map(sl.value).round(0.01));
				}).value_(specs.randPeriod.unmap(driver.randPeriod)),

			]),

			\driveMode,
			IdentityDictionary(know: true).putPairs([

				\random,	Button()
				.states_([["Random", Color.black],["Random", Color.blue]])
				.action_({ |but|
					(but.value == 1).if{driver.driveRandom};
				})
				.value_( switch(driver.driveMode, 'random', {1}, 'periodic', {0}) ),

				\periodic,	Button()
				.states_([["Periodic", Color.black],["Periodic", Color.blue]])
				.action_({ |but|
					(but.value == 1).if{driver.drivePeriodic};
				})
				.value_( switch(driver.driveMode, 'random', {0}, 'periodic', {1}) ),
			]),

			\goTo,
			IdentityDictionary(know: true).putPairs([

				\pan,	NumberBox().value_(0),
				\tilt,	NumberBox().value_(0),
				\feedTime,	NumberBox().value_(6),

				\go,	Button()
				.states_([["< Go >", Color.black]])
				.action_({ |but|
					var toX, toY, wPos, distX, distY, maxDist, feedRate;

					driver.driving.if{ driver.stop };

					toX = controls.goTo.pan.value;
					toY = controls.goTo.tilt.value;
					wPos = grbl.wPos;
					distX = (toX - wPos[0]).abs;
					distY = (toY - wPos[1]).abs;
					maxDist = max(distX, distY);
					feedRate = maxDist / controls.goTo.feedTime.value;

					grbl.goTo_( toX, toY,
						driver.feedRateEnv.at(feedRate.clip(1, 40))
					)
				})
			]),

			\end,
			Button().states_([["End", Color.gray],["End", Color.red]])
			.action_({ |but|
				(but.value == 1).if{driver.stop};
			}),
			\run,
			Button().states_([["Run", Color.gray],["Run", Color.blue]])
			.action_({ |but|
				(but.value == 1).if{driver.drive};
			}),

			\motorState,
			StaticText().string_("Unknown").stringColor_(Color.gray)
			.align_('center').background_(Color.gray.alpha(0.25)),

			\cyclePeriod,
			StaticText().string_("Cycle Period: ").background_(Color.yellow.alpha_(0.3)),

			\multPeriod,
			StaticText().string_(
				format("% secs", (driver.basePeriod / driver.numBasePeriodDivs).round(0.1))
			).align_(\left),

			\maxRate,
			StaticText().string_(format("Current max possible rate:\n% of %", nil, driver.motorMaxRate.round(0.1)))
			.background_(Color.yellow.alpha_(0.3)),

			\status,
			StaticText().string_("Status."),

			\unlock,
			Button().states_([["Unlock", Color.gray]])
			.action_({
				// controls.status.string_("Unlocked... confirm real world position with display.")
				grbl.unlock;
			}),

			\halt,
			Button().states_([["Halt", Color.gray]])
			.action_({
				driver.stop;
				grbl.pause;
				// controls.status.string_("Halted... automatic movements have been stopped.")
			}),

			\resume,
			Button().states_([["Resume", Color.gray]])
			.action_({
				grbl.resume;
				// controls.status.string_("Resuming scheduled movements.")
			}),

			\resetGRBL,
			Button().states_([["Hardware Reset", Color.gray]])
			.action_({
				driver.stop;
				grbl.reset;
				// controls.status.string_("Reset... confirm real world position with display.")
			}),

			\home,
			Button().states_([["Home Routine", Color.gray]])
			.action_({
				driver.stop;
				grbl.home;
				// controls.status.string_("HOMING... Observe the array and confirm behavior.")
			}),
		]);

		this.makeMotorDisplay;

		this.makeWindow;

		win.refresh;
	}

	getCtlLayout { |spec, numBox, slider, color, string|

		^View().background_(color ?? Color.gray.alpha_(0.1)).layout_(
			VLayout(
				HLayout(
					[StaticText().string_(spec.minval).align_('left')
					.stringColor_( Color.black.alpha_(0.5) )
					.fixedWidth_(35), a: \bottomLeft],
					35, numBox.fixedWidth_(35),
					string.notNil.if(
						{
							string.isKindOf(QStaticText).if(
								{string},
								{StaticText().string_(string).align_(\left).fixedWidth_(35)}
							)
						},
						{35}),
					[StaticText().string_(spec.maxval).align_('right')
					.stringColor_( Color.black.alpha_(0.5) )
					.fixedWidth_(35), a: \bottomRight],
				),
				slider.orientation_('horizontal')
			).margins_(internalMargins).spacing_(internalSpacing)
		)
	}

	getColor { |huescl = 0.05, offset = 1 |
		^Color.hsv(*baseColor.asHSV
			.put(0, (baseColor.asHSV[0] + huescl).clip(0,1))
			.put(1, baseColor.asHSV[1] * offset )
		)
	}

	makeWindow {

		scrn = Window.screenBounds;
		scrnW = scrn.width;
		scrnH = scrn.height;
		win = Window("Motor Driver", Rect(2*scrnW/3, 0, scrnW/3, 2*scrnH/3)).front;
		win.onClose_({this.free});

		leftWidth = 60;

		ctlView = View().layout_(
			VLayout(
				View()//.maxHeight_(win.view.bounds.height - win.view.bounds.width)
				.layout_(
					VLayout(
						View().layout_(
							HLayout(
								VLayout(
									StaticText().string_("Pan").align_('left'),
									HLayout( controls.goTo.pan,
										StaticText().string_("Deg").align_('left') )
								).margins_(internalMargins),
								VLayout(
									StaticText().string_("Tilt").align_('left'),
									HLayout( controls.goTo.tilt,
										StaticText().string_("Deg").align_('left'))
								).margins_(internalMargins),
								VLayout(
									StaticText().string_("Travel Time").align_('left'),
									HLayout( controls.goTo.feedTime,
										StaticText().string_("Sec").align_('left'))
								).margins_(internalMargins),
								controls.goTo.go
							).margins_(internalMargins),
						).background_(this.getColor(0.02)),
						HLayout(
							leftWidth,
							[StaticText().string_("Pan").fixedHeight_(titleHeight), a: 'center'],
							[StaticText().string_("Tilt").fixedHeight_(titleHeight), a: 'center'],
						),
						HLayout(
							StaticText().string_("Center").fixedWidth_(leftWidth)
							.stringColor_(Color.black.alpha_(0.8))
							.align_(\center).background_(this.getColor(0.05, 0.4)),
							this.getCtlLayout( specs.center.pan,
								controls.center.pan.numBox,
								controls.center.pan.slider,
								this.getColor(0.05), "deg"
							),
							this.getCtlLayout( specs.center.tilt,
								controls.center.tilt.numBox,
								controls.center.tilt.slider,
								this.getColor(0.05), "deg"
							),
						),
						HLayout(
							StaticText().string_("Range").fixedWidth_(leftWidth)
							.stringColor_(Color.black.alpha_(0.8))
							.align_(\center).background_(this.getColor(0.08, 0.4)),
							this.getCtlLayout( specs.range.pan,
								controls.range.pan.numBox,
								controls.range.pan.slider,
								this.getColor(0.08), "deg"
							),
							this.getCtlLayout( specs.range.tilt,
								controls.range.tilt.numBox,
								controls.range.tilt.slider,
								this.getColor(0.08), "deg"
							)
						),
						15,

						// Driving time controls
						HLayout(
							// Periodic
							View().layout_(
								VLayout(
									controls.driveMode.periodic,
									HLayout(
										View().layout_(
											HLayout(
												controls.basePeriod.checkBox.pan,
												StaticText().string_("Pan"),
												controls.basePeriod.checkBox.tilt,
												StaticText().string_("Tilt"),
											).margins_(internalMargins)
										)
										.fixedHeight_(titleHeight)
										.maxWidth_(100)
										.background_(this.getColor(0.11, 0.4)),

										[StaticText().string_("Base Period")
											.fixedHeight_(titleHeight).minWidth_(120)
											.align_('left'), a: 'left'],
										25
									),

									this.getCtlLayout( specs.basePeriod,
										controls.basePeriod.numBox,
										controls.basePeriod.slider,
										this.getColor(0.11), "secs"
									),

									[StaticText().string_("Period Multiple").fixedHeight_(titleHeight), a: 'center'],

									this.getCtlLayout( specs.numBasePeriodDivs,
										controls.numBasePeriodDivs.numBox,
										controls.numBasePeriodDivs.slider,
										this.getColor(0.11), controls.multPeriod
									)
								)
							).background_(this.getColor(0.11, 1.3)),

							// Random
							View().layout_(
								VLayout(
									controls.driveMode.random,
									[StaticText().string_("Random Sample Period (> 1)").fixedHeight_(titleHeight).minWidth_(175).align_('center'), a: 'center'],

									this.getCtlLayout( specs.randPeriod,
										controls.randPeriod.numBox,
										controls.randPeriod.slider,
										this.getColor(0.11), "secs"
									),
									nil,
									controls.cyclePeriod,
									controls.maxRate
								)
							).background_(this.getColor(0.11, 1.3)),
						),

						// Status, stop, run, reset, home
						HLayout(controls.motorState, controls.end, controls.run),
						controls.status,
						HLayout(controls.unlock, controls[\halt], controls.resume, controls.resetGRBL, controls.home)
					).margins_(internalMargins)
				).background_(Color.gray.alpha_(0.1))
			).margins_(0)
		);

		win.layout_(VLayout(userView, ctlView));
		win.refresh;
	}

	makeMotorDisplay {
		var elPast, azPast, traceColor, arrayColors;

		traceColor = Color.red;
		arrayColors = [Color.fromHexString("4F71A2"),Color.fromHexString("9CC4FF"), Color.fromHexString("13243E")];

		elPast = Array.fill(fr * historySecs, {0});
		azPast = Array.fill(fr * historySecs, {0});


		userView = UserView().animate_(true).frameRate_(fr).resize_(5)
		.minWidth_(300).minHeight_(300); //.background_(Color.gray.alpha_(0.3));

		userView.drawFunc_{ |view|
			var azNegRad, elRad, minDim, r, d, cen, arcH;
			var arrHeight, wPos, rangeBoundsRad;
			var circleViewRatio, maxMinStr, dirPnt, azLineClr;
			var azPnt, drawPnt, omniRad, omniDiam, diam, gainColor, gainPnt, ovalRect;

			wPos = grbl.wPos;
			azNegRad = wPos[0].neg.degrad; // optimize for drawing coords
			elRad = wPos[1].degrad;

			azPast = azPast.rotate(1);
			azPast[0] = azNegRad;

			elPast = elPast.rotate(1);
			elPast[0] = elRad;

			minDim = [userView.bounds.width, userView.bounds.height].minItem;

			r = minDim/2 * 0.025;
			d = r*2;
			circleViewRatio = 0.8;
			arcH = minDim * circleViewRatio / 2;	// height of the "fan" arc
			diam = 2 * arcH;

			cen = view.bounds.center; // center drawing origin

			Pen.translate(cen.x, cen.y);

			Pen.addAnnularWedge( 0@0, 5, arcH, 0, 2pi );
			Pen.fillColor_(Color.gray(0.9)).fill;

			// background circles
			Pen.strokeColor_(Color.gray.alpha_(0.2));
			3.do{|i|
				var val;
				val = (i+1 / 3);
				Pen.strokeOval( Rect(
					(arcH * val).neg, (arcH * val).neg,
					diam*val, diam*val
				));
			};

			Pen.push;
			Pen.rotate(azNegRad);
			// draw "array" with outline
			arrHeight = diam * ((0.5pi-elRad.abs) / (0.5pi));

			ovalRect = Rect(
				0 - arcH,
				0 - (arrHeight / 2),
				diam, arrHeight);
			Pen.addOval( ovalRect );
			Pen.fillAxialGradient( ovalRect.bounds.leftBottom, ovalRect.bounds.leftTop,
				arrayColors[0].blend(arrayColors[1], elRad / 1.5707963267949),
				arrayColors[0].blend(arrayColors[2], elRad / 1.5707963267949)
			);

			Pen.strokeColor_(arrayColors[2]);
			Pen.strokeOval( Rect(
				0 - arcH,
				0 - (arrHeight / 2),
				diam, arrHeight)
			);

			// trajectory direction point
			dirPnt = Polar(
				sin( elRad ).neg,
				0/*azNegRad*/
			).asPoint
			.rotate(0.5pi)	// convert ambi to screen coords
			* arcH;			// scale normalized points to arcH

			// draw azimuth point w/o perspective
			azPnt = Polar(-1, 0/*azNegRad*/).asPoint.rotate(0.5pi) * arcH;
			Pen.fillColor_(Color.yellow);
			Pen.fillOval( Rect(azPnt.x-r, azPnt.y-r, d, d) );
			QPen.stringCenteredIn(
				wPos[0].round(0.1).asString,
				Rect(azPnt.x-(r*10), azPnt.y-(r*15), d*10, d*10)
			);

			// line to trajectory point
			Pen.strokeColor_(Color.fromHexString("87B7FD"));
			Pen.line(dirPnt, 0@0).stroke;
			Pen.pop;

			// draw range
			Pen.push;
			// arg center, innerRadius, outerRadius, startAngle, sweepLength;
			rangeBoundsRad = driver.getBounds.degrad;
			Pen.rotate( driver.centerX.neg.degrad - (pi/2));
			Pen.addAnnularWedge( 0@0,
				sin(rangeBoundsRad[1][0]) * arcH,
				sin(rangeBoundsRad[1][1]) * arcH,
				driver.rangeX.half.degrad, driver.rangeX.neg.degrad
			);
			Pen.fillColor_( Color.yellow.alpha_(0.3) ).fill;
			Pen.pop;

			// draw history trace
			azPast.size.do{ |i|
				var color, pnt;
				Pen.push;
				color = traceColor.alpha_( (1 - ((i+1)/(azPast.size))) * 0.5);
				Pen.fillColor_( color );
				Pen.rotate(azPast[i]);
				Pen.fillOval( Rect(r.neg, sin(elPast[i]).neg * arcH-r, d, d) );
				Pen.pop;
			};

			Pen.push;
			Pen.rotate(azNegRad);
			// draw elevations with perspective
			Pen.fillColor_(traceColor);
			Pen.fillOval( Rect(dirPnt.x-r, dirPnt.y-r, d, d) );
			Pen.pop;
		}
	}

	free {
		win !? {win.close};
		driver.removeDependant(this);
		grbl.removeDependant(this);
		driver.free;
	}

	update {
		| who, what ... args |
		// we're only paying attention to one thing, but just in case we check to see what it is
		if( who == driver, {
			switch ( what,

				\centerX, {
					controls.center.pan.numBox.value = args[0];
					controls.center.pan.slider.value = specs.center.pan.unmap(args[0]);
				},
				\centerY, {
					controls.center.tilt.numBox.value = args[0];
					controls.center.tilt.slider.value = specs.center.tilt.unmap(args[0]);
				},

				\rangeX, {
					controls.range.pan.numBox.value = args[0];
					controls.range.pan.slider.value = specs.range.pan.unmap(args[0]);
				},

				\rangeY, {
					controls.range.tilt.numBox.value = args[0];
					controls.range.tilt.slider.value = specs.range.tilt.unmap(args[0]);
				},

				\basePeriod, {
					controls.basePeriod.numBox.value_(args[0]);
					controls.basePeriod.slider.value_(
						specs.basePeriod.unmap(args[0])
					);
					controls.multPeriod.string_(
						format("% secs", (args[0] / driver.numBasePeriodDivs).round(0.1) )
					);
				},
				\numBasePeriodDivs, {
					controls.numBasePeriodDivs.numBox.value_(args[0]);
					controls.numBasePeriodDivs.slider.value_(
						specs.numBasePeriodDivs.unmap(args[0])
					);
				},
				\baseAxis, {
					controls.basePeriod.checkBox.pan.value = (args[0]==0);
					controls.basePeriod.checkBox.tilt.value = (args[0]==1);
				},
				\driveMode, {
					switch( args[0],
						'random',	{
							controls.driveMode.random.value_(1); controls.driveMode.periodic.value_(0); },
						'periodic',	{
							controls.driveMode.random.value_(0); controls.driveMode.periodic.value_(1); },
					);
				},

				\status, {
					controls.status.string_(Date.getDate.format("%I:%M  ") ++ args[0])
				},

				\driving, {
					if(args[0],
						{ controls.run.value_(1); controls.end.value_(0); },
						{ controls.run.value_(0); controls.end.value_(1); }
					);
				},
				\cyclePeriod, {
					controls.cyclePeriod.string_( format("Cycle Period: %", args[0].round(0.01)) )
				},
				\randPeriod, {
					controls.randPeriod.numBox.value_(args[0]);
					controls.randPeriod.slider.value_(
						specs.randPeriod.unmap(args[0])
					);
				},
				\maxRate, {
					controls.maxRate.string_(format("Current max possible rate:\n% of %", args[0].round(0.1), driver.motorMaxRate.round(0.1)))
				}
			)
		});

		if( who == grbl, {
			switch ( what,

				\mode, {
					var color;
					color = switch(args[0],
						"Run", {Color.green},
						"Idle", {Color.gray},
						"Alarm", {Color.red},
						"Home", {Color.yellow},
					);
					defer{
						// try in case window is already closed
						try {
							controls.motorState.string_(args[0]).stringColor_(color ?? Color.gray);
						}
					};
					(args[0] == "Alarm").if{
						defer{ controls.status.string_("Alarm mode. Unlock (if safe) or run homing routine.") };
					};
				},
				\error, {
					defer{ controls.status.string_(args[0]) }
				},
				\status, {
					defer{ controls.status.string_(args[0]) }
				}
			);
		});
	}
}