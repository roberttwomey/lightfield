var numRows =15, numCols=8, camPts;
var rowsFirst = true;
var leftToRight = true;
var wrap =true;
var topDown = false;


// collect into rows
camPts = numRows.collect{|r|
	numCols.collect{|c|
		var x, y;
		x = c % numCols;
		y = r % numRows;
		x@y
	}
};

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

camPts.do(_.postln);

camPts = camPts.flat;

Window("Capture Order").layout_(
	VLayout(
		*numRows.collect({ |row|
			HLayout(
			*numCols.collect({ |col|
				var txt;
				camPts.do{|pnt, i|
						if((pnt.x == col) and: (pnt.y == row)) {txt = i; }
					};
					StaticText().string_(txt)
					.stringColor_(Color.white)
					.background_(Color.black.alpha_( (txt+1 / (numCols*numRows) * 0.8) ))
				})
			)

		})
	)
).front