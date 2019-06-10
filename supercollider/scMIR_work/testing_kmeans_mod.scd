// Create an instance. This one will have 3 clusters.
k = KMeans.new(3)
k = KMeansMod.new(3)

// Feed it a single data point:
k.add([15,32]);
// The data is stored internally, and some initial centroid positions and assignments are generated:
k.data
k.centroids
k.assignments
// Feed it some more:
k.add([7,13]);
k.add([1,11]);
k.add([5,2]);
k.add([1,1]);
k.data
k.centroids
k.assignments

k.cenDistances // unique to KMeansMod - mtm added


// When you have AT LEAST k points stored (k.centroids.size == k.k), you can run the learning step:
k.update;
// After update, the centroids should have moved to reflect the data better:
k.data
k.centroids
k.assignments
k.cenDistances // unique to KMeansMod - mtm added

// Here's how we add a whole batch of data points -
// here we'll deliberately generate data clustered around three points.
// We add all the data points in a batch, before performing an update.
// For on-the-fly learning you can update after each datum, if you like.
(
var datum;
1000.do{
    // The deliberately-designed centres are these three pairs of co-ordinates:
    datum = [[5,2], [7,3], [1,1]].choose + [1.0.sum3rand, 1.0.sum3rand];
    k.add(datum);
};
k.update;
"The classifier's centroids are:".postln;
k.centroids.do(_.postln);
"How nicely do they match the deliberately-designed centres?";

w = Window.new("Data", Rect(40,40, 500, 500)).front;
a = ScatterView2(w, Rect(10,10, 450, 450), k.data, [0, 8].asSpec);

// w = Window.new("Centroids", Rect(40,40, 500, 500)).front;
// a = ScatterView2(w, Rect(10,10, 450, 450), k.centroids, [0, 8].asSpec);
)

// If you notice that the result of the above is too strongly affected by the first few data points
// (which define the initialisations for the centroids), you can .reset and recalculate:
(
k.reset.update;
"The classifier's centroids are:".postln;
k.centroids.do(_.postln);
"How nicely do they match the deliberately-designed centres?";

// w = Window.new("New Centroids", Rect(40,40, 500, 500)).front;
// a = ScatterView2(w, Rect(10,10, 450, 450), k.centroids, [0, 8].asSpec);

)

// add the centroids into the plot and select them
a.data_(k.data ++ k.centroids);
a.select(k.data.size + 3 - [1,2,3]);
a.itemSize_(5).refresh;