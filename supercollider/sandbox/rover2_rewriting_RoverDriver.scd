(
var motorSeparation; // dist between cable axis points
var canvasW, canvasH, yOff;
var poH, poW;  // pulloff height/width
var pulloff; // motor pulloff after finding limit
var machx, machy; // the destination, in machine space, defined by limits
var macha, machb; // length a and b, in machine space
var destx, desty; // x,y destination sent to grbl
var limOffset; // distance between pivot point and rover tie point when retracted to limit point

e = (
	init: {{
		|mSeparation, limitOffset=0, width, height, yOffset|

		motorSeparation = mSeparation;
		// motorSeparation = mSeparation - limitSeparation;
		if (width >= (motorSeparation-(2*limitOffset))) {"width must be less than [motorSeparation - (2*limitOffset)]".throw};

		canvasW = width;
		canvasH = height;
		yOff = yOffset;
		limOffset = limitOffset;

		poH = height + yOffset;
		poW = motorSeparation/2;
		pulloff = (poH.squared + poW.squared).sqrt - limOffset;
		if (pulloff < (motorSeparation - (2*limOffset))) {
			postf("(pulloff + limOffset) : %\nmotorSeparation : %\n", (pulloff + limOffset), motorSeparation);
			(
				"Pulloff must be larger than the motor separation. " ++
				"Consider lowering the bottom bound of the canvas or bringing the motors closer together."
			).throw
		};
	}},
	goto: {{
		|gox, goy|
		machx = gox + ((motorSeparation-canvasW)/2);
		machy = goy + yOff;

		macha = (machx.squared + machy.squared).sqrt;
		machb = ((motorSeparation-machx).squared + machy.squared).sqrt;

		destx = macha - pulloff + limOffset;
		desty = machb - pulloff + limOffset;

		e.sendmsg.(destx, desty)
	}},
	sendmsg: {{
		|x,y|
		postf("Going to: [%, %]\n", x, y);
		// grbl.goTo_(x,y)
	}}
);
)

e.init.( mSeparation:15, width:10, height:6, yOffset: 8 )
// goto is in canvas coordinates
e.goto.( 5+2, 3 )
e.goto.( 5-2, 3 ) 