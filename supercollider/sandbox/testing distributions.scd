(
// x = 500.collect({0.5.gaussian(0.5)})
// x = 500.collect({1.cauchy(0.1)})
// x = 500.collect({0.5.logistic(1)})
// x = 500.collect({0.0.logistic(0.0)});
x = 500.collect({0.0.logistic(0.1)});
// x = 500.collect({0.1.pareto(0.1)})

postf("[%,%]\n", x.minItem, x.maxItem);
postf("% out of bounds\n", x.select({|val| ((val > 1) or: (val < 0)) }).size);
x.plot(discrete: true, minval: -0.5, maxval: 1.5);
)

(
x = [0.1, 0.5, 1.0].collect{ |prob|
	var data = 500.collect({
		// 0.001.weibull(1, prob)
		0.betarand(1, prob)
	});

	postf("prob: %, min: %, max: %, out of bounds: %\n",
		prob, data.minItem, data.maxItem, data.select({|val| ((val > 1) or: (val < 0)) }).size
	);
	data;
}
)

(
var spread = 0.18;
var shift = 0.7;
x = 500.collect({shift.gaussian(spread)});

// x =x.wrap(0,1);
x =x.fold(0,1); // keep in range at cost of slightly altering distro

postf("[%,%]\n", x.minItem, x.maxItem);
postf("% out of bounds\n", x.select({|val| ((val > 1) or: (val < 0)) }).size);
x.plot(discrete: true, minval: 0.0, maxval: 1.0);
)


// BETA
(
// x = [[0.1, 0.1], [0.5,0.5], [1.0, 1.0]].collect{ |prob|
x = [
	[0.01, 1],	// pull hard toward min
	[1, 0.01], 	// pull hard toward max
	[1.0, 1.0]	// uniform random
].collect{ |prob|
	var data = 500.collect({
		0.betarand(1, prob[0], prob[1])
	});

	postf("prob: %, min: %, max: %, oob: %\n",
		prob, data.minItem, data.maxItem, data.select({|val| ((val > 1) or: (val < 0)) }).size
	);
	data;
};
x.plot(discrete: true, minval: -0.5, maxval: 1.5)
)


x.plot(discrete: true, minval: -0.5, maxval: 1.5)

x.do(_.plot(discrete: true, minval: -0.5, maxval: 1.5))