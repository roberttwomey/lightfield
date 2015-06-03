x = { |auxLag=5, auxOnsetCurve = 1, t_auxOnset = 0|
Out.kr( 0, EnvGen.kr(
				Env([0,0,1],[0,auxLag], auxOnsetCurve, releaseNode:1, loopNode: 0),
				t_auxOnset, doneAction: 0
			)
	)
	}.play

x.set(\t_auxOnset, 1)

x.set(\auxLag, 3)
x.set(\t_auxOnset, 1)

x.set(\auxOnsetCurve, -4)
x.set(\t_auxOnset, 1)
