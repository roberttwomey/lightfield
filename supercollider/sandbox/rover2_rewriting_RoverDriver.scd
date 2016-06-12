(
var motorSeparation, canvasW, canvasH, yOff;
var poH, poW;  // pulloff height/width
var pulloff; // motor pulloff after finding limit
var machx, machy; // the destination, in machine space, defined by limits
var macha, machb; // length a and b, in machine space
var destx, desty; // x,y destination sent to grbl

e = (
	init: {{
		|mSeparation, width, height, yOffset|
		if (width >= mSeparation) {"width must be less than motorSeparation".throw};
		motorSeparation = mSeparation;
		canvasW = width;
		canvasH = height;
		yOff = yOffset;
		poH = height + yOffset;
		poW = motorSeparation/2;
		pulloff = (poH.squared + poW.squared).sqrt;
	}},
	goto: {{
		|gox, goy|
		machx = gox + ((motorSeparation-canvasW)/2);
		machy = goy + yOff;
		macha = (machx.squared + machy.squared).sqrt;
		machb = ((motorSeparation-machx).squared + machy.squared).sqrt;
		destx = macha - pulloff;
		desty = machb - pulloff;
		e.sendmsg.(destx, desty)
	}},
	sendmsg: {{
		|x,y|
		postf("Going to: [%, %]\n", x, y);
		// grbl.goTo_(x,y)
	}}
);
)

e.init.( 15, 10, 5, 3 )
// goto is in canvas coordinates
e.goto.( 3, 3 ) 