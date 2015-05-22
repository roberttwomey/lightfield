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
    void loadLFImage();
    void graphicsSetup();

    void doSnapshot();

    void process_OSC(ofxOscMessage m);
    void keyPressed  (int key);

    ofxOscReceiver receiver;
    int port;


    ofTexture lfplanes[MAX_LF_TILES];
    string lffilenames[MAX_LF_TILES];
    int numlftiles;
    ofFbo campos_tex;
    ofFbo tilenum_tex;
    ofFbo tilepixoffset_tex;
    ofFbo subimg_corner_tex;

    ofDirectory dir;

    ofFbo fbo;
    ofFbo maskFbo;
    ofShader shader;

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
