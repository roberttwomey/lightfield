# Rover
This is a digital arts project using structure from motion, computational photography, and machine listening to create a dreamlike exploration of space
## Setup

### Supercollider setup

1. Download and install supercollider (tested with 3.10):
[https://supercollider.github.io/download](https://supercollider.github.io/download) 

2. Download and install **sc3-plugins** extensions: 
[https://github.com/supercollider/sc3-plugins/releases/tag/Version-3.10.0](https://github.com/supercollider/sc3-plugins/releases/tag/Version-3.10.0)

3. Using Quarks gui install KMeans quark. In supercollider: 
```
QuarksGui.new
```

Install the following quarks: 
- KMeans. Edit KMeans.quark and remove the `UnitTesting` dependency.
- SenseWorld
- Ctk
- arduino
- MathLib
- FileLog

4. Install ATK (cause it wasn't working out of the box with sc3-plugins as I had hoped):
```
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
```
  - Install ATK kernels, matrices, and sound files: [http://www.ambisonictoolkit.net/download/supercollider/](http://www.ambisonictoolkit.net/download/supercollider/)
  
5. Download and install mtm extensions: 
[https://github.com/mtmccrea/mtm-sc-extensions](https://github.com/mtmccrea/mtm-sc-extensions)

6. Recompile class library. 

