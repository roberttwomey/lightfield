(
f = File("~/Desktop/test.txt".standardizePath,"w");
100.do{|i|
	// var str = "";
	var str = rrand(0.0,i).asString ++ "\n";
	// 4.do({str = str ++ rrand(0.0,i).asString ++ " "});
	f.putString( str );
};
f.close;
)
f.close

x = FileReader.readInterpret("~/Desktop/test.txt".standardizePath, skipEmptyLines: true, delimiter: $\n)
x[0].size
x[0][1]
x[0][31].class

(
var h, k;
h = File("~/Desktop/test.txt".standardizePath, "wb");
h.inspect;
h.write( FloatArray[1.1, 2.2, 3.3, pi, 3.sqrt] );
h.write( 16.collect({|i| i.rand}) );
h.close;

k = File("~/Desktop/test.txt".standardizePath, "rb");
(k.length div: 4).do({ k.getFloat.postln; });
k.close;
)


(
var f, g;
f = File("~/Desktop/test.txt".standardizePath,"w");
100.do({ f.putChar([$a, $b, $c, $d, $e, $\n].choose); });
f.close;

g = File("~/Desktop/test.txt".standardizePath,"r");
g.readAllString.postln;
g.close;

g = File("~/Desktop/test.txt".standardizePath,"r");
g.getLine(1024).postln;
"*".postln;
g.getLine(1024).postln;
"**".postln;
g.getLine(1024).postln;
"***".postln;
g.getLine(1024).postln;
"****".postln;
g.close;
)

x = FileReader.readInterpret( "/Users/admin/Desktop/test2.txt", skipEmptyLines: true, delimiter: $\n)
x[0].clump(5)
x[0].clump(5).do(_.postln)