n = NetAddr("rover.local", 9000)

// using raspifastcamd
n.sendMsg("/camera", "start")
n.sendMsg("/camera", "stop")
n.sendMsg("/camera", "snap");


// acquire a series of calibration images with raspistill //
c=0
(
r = Routine{
	inf.do {
		// n.sendMsg("/camera", "snap");
		"ready...".postln;
		1.0.wait;
		p = format("-t 1 -o /home/pi/lfimages/frame_%.jpg", c);
		n.sendMsg("/camera", "paramsnap", p);
		c = c+1;
		2.0.wait;
	}
}
)

r.play
r.stop
n.sendMsg("/camera", "exit")


// alternate method with raspistill and command line args
(
p = format("-t 0.1 -o /home/pi/lfimages/frame_%_%.jpg", rrand(0, 10.0).round(0.01), rrand(0, 10.0).round(0.01));
n.sendMsg("/camera", "paramsnap", p)
)


c = 0;
(
p = format("-t 1 -o /home/pi/lfimages/frame_%.jpg", c);
n.sendMsg("/camera", "paramsnap", p);
c = c+1;
)


n.sendMsg("/camera", "exit")

// copy files
// "scp pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/data/string1".unixCmd

"rsync -az pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/data/".unixCmd
