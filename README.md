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
- Atk
- arduino
- MathLib
- FileLog

3. Download and install mtm extensions: 
[https://github.com/mtmccrea/mtm-sc-extensions](https://github.com/mtmccrea/mtm-sc-extensions)

4. Recompile class library. 

