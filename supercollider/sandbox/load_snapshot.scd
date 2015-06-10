(
~loadSnapshot = { |filePath|
	var f, zoom, xcount, ycount, xstart, ystart, xscroll, yscroll, focus, textures;
	File.exists(filePath).not.if{warn("could not find the file... check the path")};

	f = FileReader.read(filePath).reverse;

	f.do(_.postln);

	#zoom, xcount, ycount, xstart, ystart, xscroll, yscroll, focus = 5.collect({|i| f[i][0].split($,).asFloat}).flat;

	textures = f[5..].reverse.collect(_.at(0));

	postf("Found these parameters:\n\tzoom, %\n\txcount, %\n\tycount, %\n\txstart, %\n\tystart, %\n\txscroll, %\n\tyscroll, %\n\tfocus %\n\ttextures %\n",zoom, xcount, ycount, xstart, ystart, xscroll, yscroll, focus, textures);
	nil
}
)
texture1
texture2
...
textureN
focus
xscroll,yscroll
xstart,ystart
xcount,ycount
zoom

~loadSnapshot.("/Users/admin/Downloads/loadsnapshotparamsintocontrolmixer/20150522111823_0003.txt")