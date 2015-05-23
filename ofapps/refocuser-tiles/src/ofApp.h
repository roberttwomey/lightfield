#pragma once

#include "ofxXmlSettings.h"
#include "ofMain.h"
#include "ofxOsc.h"

#define MAX_SUBIMAGES 600
#define MAX_OFFSETS 1200

#define MAX_LF_TILES 20

class ofApp : public ofBaseApp{
public:

    void setup();
    void update();
    void draw();

    void loadXMLSettings(string settingsfile);
    void loadXMLScene(string scenefile);
    vector<string> scenefiles;

    void loadLightfieldData();
    void setupGraphics();

//    void updateAperture();
//   ofFbo aperture_mask_tex;
//    float *aperture_mask;
//
    void doSnapshot();

    void keyPressed  (int key);
    void process_OSC(ofxOscMessage m);

    ofxOscReceiver receiver;
    int port;

    // lf texture files
    ofTexture lfplanes[MAX_LF_TILES];
    string lffilenames[MAX_LF_TILES];
    int numlftextures;

    // data textures for shader
    ofFbo campos_tex;
    ofFbo tilenum_tex;
    ofFbo tilepixoffset_tex;//[MAX_LF_TILES];
    ofFbo subimg_corner_tex;
    ofDirectory dir;

    // render buffers
    ofFbo fbo;
    ofFbo refocusFbo[MAX_LF_TILES];

    ofFbo maskFbo;
    ofShader shader[MAX_LF_TILES];
    ofShader combineShader;

    float sourceWidth, sourceHeight;
    float synScale;
    float zoom;
    int xcount, ycount, xstart, ystart;

    // camera images
    int xsubimages, ysubimages, subwidth, subheight;

    // whole set of textures
    int ximagespertex, yimagespertex, tilewidth, tileheight;
    int xnumtextures, ynumtextures;
    int tilenum;

    float minScale, maxScale;
    float xoffset, yoffset;

    float offsets[MAX_OFFSETS];

    // snapshot
    int snapcount;

    // onscreen display
    bool bShowThumbnail;
    bool bHideCursor;
    bool bDebug;
};
