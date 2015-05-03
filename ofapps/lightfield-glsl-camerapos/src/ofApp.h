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
    void process_OSC(ofxOscMessage m);
    
    void keyPressed  (int key);
    void keyReleased(int key);
    void mouseMoved(int x, int y );
    void mouseDragged(int x, int y, int button);
    void mousePressed(int x, int y, int button);
    void mouseReleased(int x, int y, int button);
    void windowResized(int w, int h);
    void dragEvent(ofDragInfo dragInfo);
    void gotMessage(ofMessage msg);
    
    ofxOscReceiver receiver;
    int port;
    
    ofImage lfplane;
    
    ofDirectory dir;
    
    ofImage     logoImg;
    ofImage     multimaskImg;
    ofVideoPlayer 		fingerMovie;
    ofVideoGrabber 		vidGrabber;
    
    ofFbo       fbo;
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
    
    bool bShowThumbnail;
    bool bHideCursor;
    bool bDebug;
};
