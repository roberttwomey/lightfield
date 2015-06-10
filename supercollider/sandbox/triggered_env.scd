x = { |auxLag=3, auxOnsetCurve = 1, t_auxOnset = 0|
Out.kr( 0, EnvGen.kr(
				Env([0,0,1, 0.5, 0],[0,auxLag, auxLag/2, auxLag/3], auxOnsetCurve, loopNode: 0),
				t_auxOnset, doneAction: 0
			)
	)
	}.play

x.set(\t_auxOnset, 1)
x.set(\t_auxOnset, 0)

x.set(\auxLag, 13)
x.set(\t_auxOnset, 1)

x.set(\auxOnsetCurve, -4)
x.set(\t_auxOnset, 1)
