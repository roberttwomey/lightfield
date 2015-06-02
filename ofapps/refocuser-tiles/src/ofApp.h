#pragma once

#include "ofxXmlSettings.h"
#include "ofMain.h"
#include "ofxOsc.h"

#define MAX_SUBIMAGES 600
#define MAX_OFFSETS 1200
#define MAX_LF_TILES 20

#define SCREEN_WIDTH 55.0
#define SCREEN_HEIGHT 50.0

class ofApp : public ofBaseApp{
public:

    void setup();
    void update();
    void draw();

    void loadXMLSettings(string settingsfile);
    void loadXMLScene(string scenefile);
    vector<string> scenefiles;

    void loadLightfieldData();
    void freeLightfieldData();
    void setupGraphics();

//    void updateAperture();
//   ofFbo aperture_mask_tex;
//    float *aperture_mask;

    void snapshot();

    void keyPressed  (int key);
    void keyReleased(int key);
    int mouseXStart, mouseYStart;
    float xoffsetStart, yoffsetStart;
    float focusStart, zoomStart;
    int xcountStart, ycountStart;
    int xstartStart, ystartStart;
    bool bPressed;

    void process_OSC(ofxOscMessage m);

    ofxOscReceiver receiver;
    int port;

    // lf texture files
    ofTexture lfplanes[MAX_LF_TILES];
    string lffilenames[MAX_LF_TILES];
    int numlftextures;

	// data textures for shader
    ofFbo campos_tex;
    ofFbo subimg_corner_tex;

	// data textures for tiles
    ofFbo tilenum_tex;
    ofFbo tilepixoffset_tex;

    // render fbos as pointers
    ofPtr <ofFbo> fbo;
    vector <ofPtr <ofFbo> > refocusFbo;
    ofPtr <ofFbo> maskFbo;

	// refocus shaders
    ofShader shader[MAX_LF_TILES];

    ofShader combineShader;

	// refocus parameters
    float focus;
    float zoom;
    int xcount, ycount, xstart, ystart;

    float minScale, maxScale;
    float xoffset, yoffset;

    float fade;

    // camera images
    int xsubimages, ysubimages, subwidth, subheight;

    float offsets[MAX_OFFSETS];

    // params for tiled dataset
    int ximagespertex, yimagespertex, tilewidth, tileheight;
    int xnumtextures, ynumtextures;
    int tilenum;

    // snapshot
    int snapcount;

    // onscreen display
    bool bShowThumbnail;
    bool bHideCursor;
    bool bDebug;

    // physical setup
    float screen_width;
    float screen_height;



	// rendering control
    bool bSuspendRender;

};
