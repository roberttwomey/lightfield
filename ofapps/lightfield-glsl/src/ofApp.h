#pragma once

#include "ofxXmlSettings.h"
#include "ofMain.h"
#include "ofxOsc.h"

// listen on port 12345
#define PORT 12345


class ofApp : public ofBaseApp{
public:
    
    void setup();
    void update();
    void draw();
    
    void loadXMLSettings();
    void loadLFImage();
    void graphicsSetup();
    
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
    
    //vector<ofImage>     lfstack;
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
    
    int xcount, ycount, xstart, ystart;
    int xsubimages, ysubimages, subwidth, subheight;
    float minScale, maxScale;
    
    bool bDrawThumbnail;
    bool bHideCursor;
    bool bDebug;
    
};
