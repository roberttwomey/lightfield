// Mixing control busses - sandbox

// each
b = s.controlBusAllocator.alloc(1);
c = ControlFade(busnum: b)
d = ControlFade(busnum: b)

c.lfo_(SinOsc, 0.3)
d.value_(2)
d.lfo_(LFDNoise0, 0.4, -2, 7)

c.plot


(
var busnum, ratePeriodSpec, oscTag, ctlFades, outVal;
var win, msgTxt, broadcastChk, updateBx, outValTxt;
var nBoxWidth = 30, validLFOs, addPlotter, addCtl, cltLayout, plotterAdded = false;
var broadcastAddr, broadcastBus, broadcastRate, broadcastWaittime, broadcastTag, pollTask, broadcasting=false;

broadcastRate = 10;
broadcastWaittime = broadcastRate.reciprocal;
broadcastAddr = NetAddr("localhost", 57120);
broadcastTag = "/myMessage";

ctlFades = [];
busnum = s.controlBusAllocator.alloc(1);
// create a ctk bus to read from for broadcasting, with the same busnum that the ControlFades write to
broadcastBus = CtkControl(1, 0, 0, busnum);

validLFOs = [
	'static', SinOsc, LFPar, LFTri, LFCub, LFDNoise0, LFDNoise1, LFDNoise3
].collect(_.asSymbol);

ratePeriodSpec = ControlSpec(15.reciprocal, 15, -2.5, default: 3);

pollTask = Task({
	inf.do{
		broadcastBus.get({|busnum, val|
			outVal = val;
			defer{ outValTxt.string_(val.round(0.001)) };
		});

		broadcasting.if{
			broadcastAddr.sendMsg(broadcastTag, outVal)
		};

		broadcastWaittime.wait
	}
});

pollTask.play;

~addCtl = {
	var ctl, view, min, max, sclSpec, offsSpec, updateOffset;
	var minBx, maxBx, rateBx, rateSl, rateTxt, periodChk, mixBx, valBx, mixKnb, sigPUp, rmvBut, sclBx, sclKnb, offsBx, offsKnb;

	min = 0;
	max = 1;


	sclSpec = ControlSpec(0, 2, 'lin', default: 1);
	offsSpec = ControlSpec(max.neg, max, 'lin', default: 0);

	ctl = ControlFade(fadeTime: 0.0, initVal: 0, busnum: busnum, server: s);

	ctlFades = ctlFades.add(ctl);

	view = View().background_(Color.rand).maxHeight_(125)
	.layout_(
		VLayout(

			HLayout(
				[ VLayout(
					StaticText().string_("min"),
					minBx = NumberBox().fixedWidth_(nBoxWidth)
				).spacing_(0), a: \left ],
				[ VLayout(
					StaticText().string_("max"),
					maxBx = NumberBox().fixedWidth_(nBoxWidth)
				).spacing_(0), a: \left ],
				[ VLayout(
					StaticText().string_("Signal"),
					sigPUp = PopUpMenu().maxWidth_(125)
				).spacing_(0), a: \left ],
				nil,
				[ VLayout(
					StaticText().string_("Rate"),
					rateBx = NumberBox().fixedWidth_(nBoxWidth*1.5),
				).spacing_(0), a: \left ],
				[ VLayout(
					StaticText().string_(""),
					rateTxt = StaticText().string_("Sec").maxWidth_(30),
				).spacing_(0), a: \left ],
				[ VLayout(
					StaticText().string_(""),
					HLayout(
						periodChk = CheckBox().fixedWidth_(15),
						StaticText().string_("period").align_(\left),
					)
				).spacing_(0), a: \left ],

				nil,
				[ VLayout(
					[ rmvBut = Button().states_([["X", Color.black, Color.red]]).fixedWidth_(nBoxWidth/2).fixedHeight_(nBoxWidth/2), a: \topRight],
					HLayout(
						StaticText().string_("Val").align_(\right),
						valBx = NumberBox().fixedWidth_(nBoxWidth*1.5)
					).spacing_(5),
				).spacing_(5), a: \right ],
			),
			HLayout(
				VLayout(
					rateSl = Slider().orientation_(\horizontal).maxHeight_(25).minWidth_(120),
					HLayout(
						VLayout(
							StaticText().string_("scale").align_(\center),
							sclBx = NumberBox().fixedWidth_(nBoxWidth).maxWidth_(50),
						).spacing_(0),
						sclKnb = Knob().mode_(\vert).centered_(true),
						VLayout(
							StaticText().string_("offset").align_(\center),
							offsBx = NumberBox().fixedWidth_(nBoxWidth).maxWidth_(50),
						).spacing_(0),
						offsKnb = Knob().mode_(\vert).centered_(true),
						nil,
						StaticText().string_("mix").align_(\right).fixedWidth_(nBoxWidth),
						mixBx = NumberBox().fixedWidth_(nBoxWidth).maxWidth_(50),
						mixKnb = Knob(),
					)
				),
			)
		)
	);

	cltLayout.add( view );

	updateOffset = {
		var range;
		range = ctl.high - ctl.low;
		offsSpec.minval_(range.half);
		offsSpec.maxval_(range.half.neg);
	};

	// define the actions

	minBx.action_({ |bx|
		ctl.low_(bx.value);
		max = bx.value;
		updateOffset.();
	}).value_(min);

	maxBx.action_({ |bx|
		ctl.high_(bx.value);
		max = bx.value;
		updateOffset.();
	}).value_(max);

	sigPUp.items_(validLFOs).action_({|sl|
		if( sl.item.asSymbol != 'static' )
		{
			var rateHz;
			rateHz = ratePeriodSpec.map(rateSl.value).reciprocal;
			ctl.lfo_( sl.item.asSymbol, rateHz, minBx.value, maxBx.value)

		}
		{ ctl.value_( valBx.value ) };
	});

	valBx.action_({ |bx| ctl.value_(bx.value); sigPUp.value_(0)});

	rateSl.action_({ |sl|
		var rateSec, rateHz;

		rateSec = ratePeriodSpec.map(sl.value);
		rateHz = ratePeriodSpec.map(sl.value).reciprocal;

		ctl.freq_( rateHz );
		rateBx.value_( periodChk.value.asBoolean.if({rateSec},{rateHz}) );
	}).value_(ratePeriodSpec.unmap(ratePeriodSpec.default));

	rateBx.action_({ |bx|
		var rateSec, rateHz;

		if( periodChk.value.asBoolean,
			{	rateHz = bx.value.reciprocal;
				rateSec = bx.value;
			},
			{	rateHz = bx.value;
				rateSec = bx.value.reciprocal;
			}
		);
		ctl.freq_( rateHz );

		rateSl.value_( ratePeriodSpec.unmap(rateSec) );
	});

	periodChk.action_({ |chk|
		var bool, curRateBx;
		bool = chk.value.asBoolean;
		curRateBx = rateBx.value;
		rateBx.value_(curRateBx.reciprocal);
		bool.if({ rateTxt.string_("sec") },{ rateTxt.string_("Hz") });
	}).value_(true);

	offsBx.action_({|bx|
		ctl.offset_(bx.value);
		offsKnb.value_(offsSpec.unmap(bx.value));
	}).value_(offsSpec.default);

	offsKnb.action_({|knb|
		var val = offsSpec.map(knb.value);
		ctl.offset_(val);
		offsBx.value_(val);
	}).value_(offsSpec.unmap(offsSpec.default));

	sclBx.action_({|bx|
		ctl.scale_(bx.value);
		sclKnb.value_(sclSpec.unmap(bx.value));

	}).value_(sclSpec.default);

	sclKnb.action_({|knb| var val = sclSpec.map(knb.value);
		ctl.scale_(val);
		sclBx.value_(val);
	}).value_(sclSpec.unmap(sclSpec.default));


	plotterAdded.not.if{ addPlotter.(ctl) };

	rmvBut.action_({
		var vHeight = view.bounds.height;
		ctl.release(0.3, freeBus: false); // leave the bus running if others are writing to it
		block{ |break| ctlFades.do{ |cFade, i| if(cFade === ctl){ctlFades.removeAt(i); "removing a ctl".postln; break.()} } };
		{
			view.remove;
			0.1.wait;
			// win.view.resizeTo(
			win.setInnerExtent(
				win.view.bounds.width, win.view.bounds.height - vHeight );
		}.fork(AppClock)
	})
};

addPlotter = { |ctl|
	var view;
	ctl.plot(75, 45);
	view = ctl.plotter.mon.plotter.parent.view;
	// view.bounds_(view.bounds.height_(height));
	win.layout.add( view.minHeight_(view.bounds.height) );//.minHeight_(height) );

	plotterAdded = true;
	c = ctl;
};


win = Window(broadcastTag.asString, Rect(0,0,470,100)).layout_(
	VLayout(
		cltLayout = VLayout(
			View().background_(Color.rand).layout_(
				HLayout(
					[ msgTxt = TextField().string_(broadcastTag.asString).minWidth_(100), a: \left],
					nil,
					outValTxt = StaticText().string_("broadcast").align_(\left),
					nil,

					[ StaticText().string_("broadcast").align_(\right), a: \right],
					[ broadcastChk = CheckBox().fixedWidth_(15), a: \right],
					[ StaticText().string_("Update Hz").align_(\right), a: \right],
					[ updateBx = NumberBox().fixedWidth_(nBoxWidth), a: \right],
				)
			).maxHeight_(45),
		),
		Button().states_([["+"]]).action_({~addCtl.()})
	)
).onClose_({
	ctlFades.do(_.free);
	broadcastBus.free;
	pollTask !? { pollTask.stop.clock.clear };
});

msgTxt.action_({|txt|
	broadcastTag = (txt.value.asSymbol);
});

broadcastChk.action_({|chk| broadcasting = chk.value.asBoolean });


updateBx.action_({ |bx|
	broadcastRate = bx.value;
	broadcastWaittime = broadcastRate.reciprocal;
}).value_(broadcastRate);

win.front;

~addCtl.();

w = win;

)

~addCtl.();

OSCdef(\test, {|msg, time, addr, recvPort| msg.postln}, '/myMy', n); // def style