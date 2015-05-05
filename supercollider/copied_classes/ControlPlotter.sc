// Dependencies: SenseWorld Quark

ControlPlotter {
	// copyArgs
	var <>busindex, <numChans, <plotLength, <refresh_rate, <plotMode;
	var <monval, <mon, <responder, <server;
	var pFunc, pLength;

	// busindex can be an array, in which case numChans is ignored
	*new { |busindex, numChans=1, plotLength = 200, refresh_rate = 100, plotMode = \points, argserver|
		^super.newCopyArgs(busindex, numChans, plotLength, refresh_rate, plotMode).init(argserver);
	}

	init { |argserver|
		server = argserver ?? Server.default;
		busindex.isKindOf(Array).if(
			{ this.initArrayOfIndices },
			{ this.initContiguousIndices }
		);
		responder.add;
		mon = SWPlotterMonitor.new(
			pFunc, pLength, numChans, refresh_rate.reciprocal, 1
		);
		mon.plotter.plotMode_(plotMode);
		// replace the Plotter's onClose method to clean me up
		mon.plotter.parent.onClose_({
			mon !? {
				mon.plotter.parent = nil; // this is in the original onClose being replaced
			};
			this.cleanup;
		})
	}

	initContiguousIndices {
		pLength = plotLength;
		monval = Array.fill(numChans, 0);
		pFunc = { server.listSendMsg( ["/c_getn", busindex, numChans] ); monval };
		responder = OSCFunc({ |msg, time, addr, recvPort|
			// "func rsponder SINGLE/CONTIGUOUS:".postln;
			// msg: [ /c_setn, busindex, numChans, bus1val, bus2val, ... ]
			monval = msg[3..];
			},
			'/c_setn', server.addr, nil,
			argTemplate: [busindex, numChans]
		);
	}

	initArrayOfIndices {
		var argTemplate;
		pLength = (plotLength / busindex.size ).asInt;
		monval = Array.fill(busindex.size, 0);
		pFunc = { server.listSendMsg( ["/c_get"]++busindex ); monval  };

		argTemplate = [busindex, Array.fill(busindex.size, nil)].lace(busindex.size*2);
		responder = OSCFunc({ |msg, time, addr, recvPort|
			// "func rsponder MULTIPLE/NON-Contiguous:".postln;
			// msg: [ /c_setn, bus1index, bus1val, bus1index, bus2val, ... ]
			monval = msg.drop(1).unlace(2).at(1);
			},
			'/c_set', server.addr, nil,
			argTemplate: argTemplate
		);
	}

	start { mon.start }
	stop { mon.stop }

	bounds_ { arg ...args; /* hi,low -or- \auto */
		(args == [\auto]).if(
			{ mon.plotter.findSpecs = true },
			{ ((args.size) == 2).if(
				{	mon.plotter.findSpecs = false;
					mon.setRange(args[0], args[1])
				},{	"bounds must be [lo, hi] or \\auto".warn
				})
			}
		)
	}

	plotMode_ { |mode|
		[\linear,\levels,\points].includes( mode ).if(
			{ mon.plotter.plotMode_( mode ) },
			{ "valid drawing modes are:  \\linear, \\levels, \\points".warn }
		)
	}

	cleanup {
		responder.remove;
		mon !? { var win;
			mon.stop;
			win = mon.plotter.parent;
			win !? { win.isClosed.not.if{win.close} };
			mon = nil;
		};
	}

	free { this.cleanup }

}