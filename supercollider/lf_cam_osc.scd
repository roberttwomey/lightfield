n = NetAddr("169.254.0.2", 9000)

// using raspifastcamd
n.sendMsg("/camera", "start")
n.sendMsg("/camera", "stop")
n.sendMsg("/camera", "snap")
n.sendMsg("/camera", "exit")


// alternate method with raspistill and command line args
(
p = format("-t 1 -o /home/pi/lfimages/frame_%_%.jpg", rrand(0, 10.0).round(0.01), rrand(0, 10.0).round(0.01));
n.sendMsg("/camera", "paramsnap", p)
)

n.sendMsg("/camera", "exit")

// copy files
"scp pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/data/string1".unixCmd

"rsync -az pi@rover.local:/home/pi/lfimages/* /Volumes/Work/Projects/lightfield/data/".unixCmd
