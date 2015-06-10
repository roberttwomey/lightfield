presetGUI { |numCol=1|
	var presetsClumped, ftBox, varBox, msg_Txt, presetLayouts, maxRows;
	maxRows = (this.presets.size / numCol).ceil.asInt;

	presetsClumped = this.presets.keys.asArray.sort.clump(maxRows);

	presetLayouts = presetsClumped.collect({ |presetGroup|
		VLayout(
			*presetGroup.extend(maxRows,nil).collect({ |name, i|
				var lay;
				name.notNil.if({
					lay = HLayout(
						[ Button().states_([[name]])
							.action_({
								this.recallPreset(name.asSymbol, ftBox.value);
								msg_Txt.string_(format(
									"preset % updated.", name.asSymbol)).stringColor_(Color.black);
						}), a: \top]
					)
				},{
					nil
				})
			})
		)
	});

	presetWin = Window("Presets", Rect(0,0,100, 100)).view.layout_(
		VLayout(
			[ Button().states_([
				["Play", Color.black, Color.grey],
				["Release", Color.white, Color.red]

			]).action_({ |but|
				switch( but.value,
					0, {this.play},
					1, {this.release}
				)
			}).maxWidth_(70).fixedHeight_(35), a: \right],
			HLayout(
				nil,
				StaticText().string_("Fade Time").align_(\right).fixedHeight_(25),
				ftBox = NumberBox().value_(1.0).maxWidth_(35).fixedHeight_(25)
			),
			HLayout(
				msg_Txt = StaticText().string_("Select a preset to recall.").fixedHeight_(35),
				Button().states_([["Update Preset"]]).action_({this.updatePreset}).fixedWidth_(95)
			),
			HLayout( *presetLayouts )
		)
	).front;
}