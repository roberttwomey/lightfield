#pragma once

#include "ofxXmlSettings.h"
#include "ofMain.h"
#include "ofxOsc.h"

#define MAX_SUBIMAGES 600
#define MAX_OFFSETS 1200

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

    ofImage lfplane;
    ofFbo campos_tex;

    ofDirectory dir;

    ofImage     logoImg;
    ofImage     multimaskImg;
    ofVideoPlayer 		fingerMovie;
    ofVideoGrabber 		vidGrabber;

    ofFbo fbo;
    ofFbo       maskFbo;
    ofShader    shader;

    string lfimage_filename;
    
    float sourceWidth, sourceHeight;
    float synScale;
    float zoom;
    int xcount, ycount, xstart, ystart;
    int xsubimages, ysubimages, subwidth, subheight;
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
