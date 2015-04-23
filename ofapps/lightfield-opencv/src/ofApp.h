#pragma once

#include "ofMain.h"
#include "ofxCvColorImage.h"
#include "ofxOpenCv.h"
#include "cv.h"

#define MAXIMAGES 200
#define minMult -10000
#define maxMult 0

class lfImage : public ofImage {
	public:
		void setUV(float _u, float _v) { u=_u, v=_v; };
	float getU() { return u; };
	float getV() { return v; };
	
	float u, v;
};

class ofApp : public ofBaseApp {
	
	public:
		void reset();

		void setup();
		void update();
		void draw();
		
		void keyPressed(int key);
		void keyReleased(int key);
		void mouseMoved(int x, int y );
		void mouseDragged(int x, int y, int button);
		void mousePressed(int x, int y, int button);
		void mouseReleased(int x, int y, int button);
		void windowResized(int w, int h);
		void dragEvent(ofDragInfo dragInfo);
		void gotMessage(ofMessage msg);		
		
		void preloadImages();
	
		void drawLightField();

		void remapLightField(float aperture);
	
		// we will have a dynamic number of images, based on the content of a directory:
		ofDirectory dir;
		//vector<ofImage> images;
		vector<lfImage> images;

		// for doing fast-ish (opencv) image shifting and averaging
		ofxCvColorImage	warpedImageOpenCV;
		ofxCvColorImage unwarpedImageOpenCV;
		ofxCvFloatImage srcxArrayOpenCV; 
		ofxCvFloatImage srcyArrayOpenCV; 
		ofxCvColorImage sumImageOpenCv;

		int sourceWidth, sourceHeight;
	
		int   interpMethod;   
		CvScalar blackOpenCV;
    
        bool drawThumbnails;
        
        float aperture;
        float calculated;
};
