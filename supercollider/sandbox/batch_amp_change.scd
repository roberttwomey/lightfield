GrainScanner1.presets.keysValuesDo{|k,v|
	v.params.do{|dict| var oldval = dict[\amp]; dict[\amp] = (oldval.ampdb - 12).dbamp; }
}

GrainScanner2.presets.keysValuesDo{|k,v|
	v.params.do{|dict|
		// dict[\amp].postln
		var oldval = dict[\amp]; dict[\amp] = (oldval.ampdb - 12).dbamp;

	}
}