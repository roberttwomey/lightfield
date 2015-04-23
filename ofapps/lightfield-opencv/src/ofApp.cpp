#include "ofApp.h"
#include <iostream>
#include <fstream>


//--------------------------------------------------------------
void ofApp::setup() {
	preloadImages();	
		
	//ofEnableAlphaBlending();
	
	aperture=1.0;
    drawThumbnails=false;
}

void ofApp::preloadImages() {
	
	// load camera position
	string line;
	ifstream myfile;
	
	vector<ofVec2f> uvcoords;

	ifstream camerafile; //declare a file stream  
	
    //camerafile.open("/Users/rtwomey/code/pytwomey/lightfield/stitcher/results/row2/cameras_cor.txt");
    //camerafile.open("/Volumes/Cistern/Pictures/lightfield/results/home3_row1/cameras_cor.txt");
    //camerafile.open("/Volumes/Cistern/Pictures/lightfield/home/home3_row1/cameras_cor.txt");
//    camerafile.open("/Volumes/Work/Projects/lightfield/data/set2/cameras_cor.txt");
//    camerafile.open("/Volumes/Work/Projects/lightfield/data/set2/camera_pos2.txt");
    camerafile.open("/Volumes/Work/Projects/lightfield/data/precise/camera_pos.txt");
    
    //camerafile.open("/Users/rtwomey/code/pytwomey/lightfield/stitcher/results/grid/cameras_cor.txt");
    //camerafile.open( "/Users/rtwomey/code/lightfield/data/lightfield.stanford.edu/data/outdoors/cameras.pos"); //open your text file
	//camerafile.open( "/Users/rtwomey/code /lightfield/data/lightfield.stanford.edu/data/still/cameras.pos"); //open your text file
	
	while(camerafile!=NULL) //as long as theres still text to be read  
	{  
		string str; //declare a string for storage  
		getline(camerafile, str); //get a line from the file, put it in the string  
		cout << str << endl;
		vector<string> results = ofSplitString(str, " ", true, true);
		if(results.size()>=3) {
			ofVec2f temp;
            temp.x = ofToFloat(results[1]) / 10.;
			temp.y = ofToFloat(results[2]) / 10.;
            uvcoords.push_back(temp);
			cout << "u,v " << temp.x << "," << temp.y << endl;
		}
	} 
	camerafile.close();
	
	cout << uvcoords.size() << " coordinates " << endl;
	// load images
    dir.listDir("/Volumes/Work/Projects/lightfield/data/precise/warped");
    //    dir.listDir("/Volumes/Work/Projects/lightfield/data/set2/vsfmundistorted");
//    dir.listDir("/Volumes/Work/Projects/lightfield/data/set2/vsfmwarped");
//    dir.listDir("/Volumes/Cistern/Pictures/lightfield/home/home3_row1/warped/");
    //dir.listDir("/Volumes/Cistern/Pictures/lightfield/results/home3_row1/recentered/");
    //dir.listDir("/Volumes/Cistern/Pictures/lightfield/results/home3_row1/recenteredKey/");
    //dir.listDir("/Users/rtwomey/code/pytwomey/lightfield/stitcher/results/row2/recentered/");
    //dir.listDir("/Users/rtwomey/code/pytwomey/lightfield/stitcher/results/grid/recentered/");
    //dir.listDir("/Volumes/Cistern/Pictures/lightfield/data/lightfield.stanford.edu/data/outdoors/students-keyst/");
	//dir.listDir("/Users/rtwomey/code/lightfield/data/lightfield.stanford.edu/data/still/still-keyst/");
	dir.sort(); // in linux the file system doesn't return file lists ordered in alphabetical order
	

	//allocate the vector to have as many ofImages as files
	if( dir.size() ){
		images.assign(dir.size(), lfImage());
	}
	// you can now iterate through the files and load them into the ofImage vector
	int count=0;
	for(int i = 0; i < (int)dir.size(); i++){
		
		images[i].loadImage(dir.getPath(i));
        //cout << dir.getPath(i) << endl;
		images[i].setUV(uvcoords[i].x, uvcoords[i].y);
		count ++;
	}	

	cout << images.size() << " images" << count << endl;

	sourceWidth=images[0].getWidth();
	sourceHeight=images[0].getHeight();
		
	cout << "IMAGE WIDTHS " << sourceWidth << ", " << sourceHeight << endl;

	blackOpenCV = cvScalarAll(0);  
	
	/* Interpolation method:  
	 
	 http://opencv.willowgarage.com/documentation/cpp/geometric_image_transformations.html#cv-resize 
	 
	 CV_INTER_NEAREST nearest-neighbor interpolation 
	 CV_INTER_LINEAR bilinear interpolation (used by default) 
	 CV_INTER_AREA resampling using pixel area relation. It may be the 
	 preferred method for image decimation, as it gives moire-free results. 
	 But when the image is zoomed, it is similar to the INTER_NEAREST method 
	 CV_INTER_CUBIC bicubic interpolation over 4x4 pixel neighborhood 
	 CV_INTER_LANCZOS4 Lanczos interpolation over 8x8 pixel neighborhood 
	 
	 */  
	
	interpMethod = CV_INTER_LINEAR;//CV_INTER_CUBIC; // CV_INTER_LANCZOS4;
	
	/* from: 
	 http://stackoverflow.com/questions/3596385/can-anybody-explain-cvremap-with-a-code-using-cvremap-in-opencv 
	 
	 I use cvRemap to apply distortion correction. The map_x part is in 
	 image resolution and stores for each pixel the x-offset to be applied, 
	 while map_y part is the same for the y-offset. 
	 
	 in case of undistortion 
	 
	 # create map_x/map_y 
	 self.map_x = cvCreateImage(cvGetSize(self.image), IPL_DEPTH_32F, 1) 
	 self.map_y = cvCreateImage(cvGetSize(self.image), IPL_DEPTH_32F, 1) 
	 # I know the camera intrisic already so create a distortion map out 
	 # of it for each image pixel 
	 # this defined where each pixel has to go so the image is no longer 
	 # distorded 
	 cvInitUndistortMap(self.intrinsic, self.distortion, self.map_x, 
	 self.map_y) 
	 # later in the code: 
	 # "image_raw" is the distorted image, i want to store the 
	 undistorted into 
	 # "self.image" 
	 cvRemap(image_raw, self.image, self.map_x, self.map_y) 
	 
	 Therefore: map_x/map_y are floating point values and in image 
	 resolution, like two images in 1024x768. What happens in cvRemap is 
	 basicly something like 
	 
	 orig_pixel = input_image[x,y] 
	 new_x = map_x[x,y] 
	 new_y = map_y[x,y] 
	 output_image[new_x,new_y] = orig_pixel 
	 */  
	
	/* so lets make a map that just moves all the pixels down 100.4f 
	 pixels */  
	
	//float verticalDistanceToMove = 100.4f;  
		
	// also allocate cv image types for shifting
	unwarpedImageOpenCV.allocate(sourceWidth, sourceHeight);
	warpedImageOpenCV.allocate(sourceWidth, sourceHeight);
	srcxArrayOpenCV.allocate(sourceWidth, sourceHeight);
	srcyArrayOpenCV.allocate(sourceWidth, sourceHeight);
	sumImageOpenCv.allocate(sourceWidth, sourceHeight);

	remapLightField(-1296);
}



//--------------------------------------------------------------
void ofApp::reset() {

}

//--------------------------------------------------------------
void ofApp::update() {

}

//--------------------------------------------------------------
void ofApp::draw() {
    float sf = ofGetWindowHeight() / sumImageOpenCv.getHeight();
    
    ofSetColor(0);
    ofRect(0, 0, ofGetWindowWidth(), ofGetWindowHeight());
    ofPushMatrix();
    ofTranslate((ofGetWindowWidth() - sumImageOpenCv.getWidth()*sf)/2, 0);
    ofScale(sf, sf);
    ofSetColor(255);
	//drawLightField();
	sumImageOpenCv.draw(0,0);
    if(drawThumbnails) {
        unwarpedImageOpenCV.draw(0, 500, 320, 240);
        warpedImageOpenCV.draw(300,500, 320, 240);
    }
    ofPopMatrix();
    
    ofSetColor(255);
	ofDrawBitmapString("CURRENT OFFSET: "+ofToString(calculated), 10, 10);
    ofSetColor(128);
	ofDrawBitmapString(ofToString(ofMap(ofGetMouseX(), 0, ofGetWindowWidth(), minMult, maxMult)), 10, ofGetHeight()-30);
}

void ofApp::drawLightField() {
	//images[i].draw(10-images[i].u*aperture, 10-images[i].u*aperture);
//	images[i].draw(float(ofGetWindowWidth()/2)-images[i].u*aperture, float(ofGetWindowHeight()/2)-images[i].v*aperture);
//	i++;
//	if(i>images.size()-1)i=0;
		
}

void ofApp::remapLightField(float aperture) {

	float beta = 1.0/images.size();
	float alpha = 1.0;
	sumImageOpenCv.set(0);
    calculated = aperture;
    
	//IplImage results[images.size();
	
	for(int i=0; i<images.size(); i++) {		

//		float* srcX = srcxArrayOpenCV.getPixelsAsFloats();   
//		float* srcY = srcyArrayOpenCV.getPixelsAsFloats();  
		
		float xoff=aperture*images[i].u;
		float yoff=aperture*images[i].v;
		//cout << "pixel offsets " << xoff << ", " << yoff << endl;
		
//		for(int k=0; k < sourceHeight; k++){  
//			for(int j=0; j< sourceWidth; j++){  
//				int positionInArray = k*sourceWidth + j;  
//				//cout << images[i].u << " " << images[i].v << endl;
//				srcX[positionInArray] = float(j)-xoff;
//				srcY[positionInArray] = float(k)-yoff;
//			}  
//		}
		
//		unwarpedImageOpenCV.setFromPixels(images[i].getPixels(),sourceWidth, sourceHeight);
		
//		cvRemap(unwarpedImageOpenCV.getCvImage(),  
//				warpedImageOpenCV.getCvImage(),  
//				srcxArrayOpenCV.getCvImage(),   
//				srcyArrayOpenCV.getCvImage(),   
//				interpMethod | CV_WARP_FILL_OUTLIERS, blackOpenCV );  
//
//		unwarpedImageOpenCV.flagImageChanged();  

        
        warpedImageOpenCV.setFromPixels(images[i].getPixels(),sourceWidth, sourceHeight);
        warpedImageOpenCV.translate(xoff, yoff);
        warpedImageOpenCV.flagImageChanged();
		
//		results[i]=warpedImageOpenCV.getCvImage();
		
		cvAddWeighted(sumImageOpenCv.getCvImage(), alpha, warpedImageOpenCV.getCvImage(), beta, 0.0, sumImageOpenCv.getCvImage());
        //cvAdd(sumImageOpenCv.getCvImage(), warpedImageOpenCV.getCvImage(), sumImageOpenCv.getCvImage());
        //cvAcc(warpedImageOpenCV.getCvImage(), sumImageOpenCv.getCvImage());
        
		sumImageOpenCv.flagImageChanged();
        
        
	}

    // flip b/c my images are upside down
    //sumImageOpenCv.mirror(true, true);
    //sumImageOpenCv.flagImageChanged();
	//cvNormalize(sumImageOpenCv.getCvImage(), sumImageOpenCv.getCvImage(), 0.0, 255.0);
    //sumImageOpenCv.getCvImage() = sumImageOpenCv / float(images.size());
    
//	calcCovarMatrix(results, images.size(),
	cout << "remapped " << images.size() << " images" << endl;
}


//--------------------------------------------------------------
void ofApp::keyPressed  (int key){
    if(key == 't')
        drawThumbnails = !drawThumbnails;
    if(key == 'f')
        ofToggleFullscreen();
    if(key==OF_KEY_LEFT) {
        aperture-=0.05;
        remapLightField(aperture);
    }
    if(key==OF_KEY_RIGHT) {
        aperture+=0.05;
        remapLightField(aperture);
    }
    
}

//--------------------------------------------------------------
void ofApp::keyReleased  (int key){

}

//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y ){
}


//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button){
    aperture=ofMap(ofGetMouseX(), 0, ofGetWindowWidth(), minMult, maxMult); //20, 20);
	cout << ofGetMouseX() << " " << aperture << endl;
	remapLightField(aperture);
}

//--------------------------------------------------------------
void ofApp::mouseReleased(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h){

}

//--------------------------------------------------------------
void ofApp::gotMessage(ofMessage msg){

}

//--------------------------------------------------------------
void ofApp::dragEvent(ofDragInfo dragInfo){

}
