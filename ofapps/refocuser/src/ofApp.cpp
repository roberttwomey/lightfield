#include "ofApp.h"


//--------------------------------------------------------------
// main program
//--------------------------------------------------------------

void ofApp::setup(){

    ofEnableAlphaBlending();

    loadXMLSettings("settings.xml");

    loadLightfieldData();

    setupGraphics();

    // OSC - listen on the given port
    receiver.setup(port);
    ofLog(OF_LOG_NOTICE, "listening for osc messages on port " + ofToString(port));

    snapcount = 0;
    bSuspendRender = false;
}

//--------------------------------------------------------------

void ofApp::update(){

    if(!bSuspendRender) {

        // TODO: why is this here?
        maskFbo->begin();
        ofClear(255, 0, 0,255);
        maskFbo->end();

		fbo->begin();
		ofClear(0, 0, 0,255);

		shader.begin();

		// aperture
		shader.setUniform2i("ap_loc", xstart, ystart);
		shader.setUniform2i("ap_size", xcount, ycount);

		// focus
		shader.setUniform1f("fscale", focus);

		// zoom / pan
		shader.setUniform1f("zoom", zoom);
		shader.setUniform2f("roll", xoffset, yoffset);

		maskFbo->draw(0,0);

		shader.end();

		fbo->end();
	}

    ofSetWindowTitle( ofToString( ofGetFrameRate(), 2));

	// check for waiting OSC messages
    while(receiver.hasWaitingMessages()){
        // get the next message
        ofxOscMessage m;
        receiver.getNextMessage(&m);

        process_OSC(m);

    };
}

//--------------------------------------------------------------
void ofApp::draw(){
    ofBackground(ofColor::black);

    // fused image size
    float height = ofGetWindowHeight();
    float width = height/subheight*subwidth;
    float xoff = (ofGetWindowWidth() - width)/2;

    // draw with transparency to fade
    ofSetColor(255, fade);

    // draw fused image
    fbo->draw(xoff, 0, width, height);

    // crop to 50 x 55 screen size
    float cwidth = height / SCREEN_HEIGHT * SCREEN_WIDTH;
    float bar = (width-cwidth)/2.0;
    ofSetColor(0);
    ofFill();
    ofRect(0, 0, bar, height);
    ofRect(width-bar, 0, width, height);
    
    // draw thumbnail with indicator
    if(bShowThumbnail == true) {


		// thumbnail size
		float tWidth = 160;
		float tHeight = 160/xsubimages * ysubimages;
        float xunit = tWidth/xsubimages;
        float yunit = tHeight/ysubimages;

        ofSetColor(255);
        lfplane.draw(5,5,tWidth,tHeight);

        ofSetColor(255, 0, 0);
        ofNoFill();

        ofRect(5+xstart*xunit, 5+ystart*yunit, xcount*xunit, ycount*yunit);
    }

    if(bDebug == true) {
        // display text about refocusing
        ofSetColor(255);
        ofTranslate(10, ofGetHeight()-90);
//        ofDrawBitmapString("tilenum:  \t"+ofToString(tilenum), 0, -15);
        ofDrawBitmapString("fade:     \t"+ofToString(fade), 0, -15);
        ofDrawBitmapString("scale:    \t"+ofToString(focus), 0, 0);
        ofDrawBitmapString("roll:     \t"+ofToString(xoffset)+" "+ofToString(yoffset), 0, 15);
        ofDrawBitmapString("ap_loc:   \t"+ofToString(xstart)+" "+ofToString(ystart) +" ("+ofToString(xstart + ystart * xsubimages)+")", 0, 30);
        ofDrawBitmapString("ap_size:  \t"+ofToString(xcount)+" "+ofToString(ycount), 0, 45);
        ofDrawBitmapString("zoom:     \t"+ofToString(zoom), 0, 60);
        ofDrawBitmapString("framerate:\t"+ofToString(ofGetFrameRate(), 2), 0, 75);
    }
}


//--------------------------------------------------------------
// setup
//--------------------------------------------------------------

void ofApp::loadXMLSettings(string settingsfile) {
    ofxXmlSettings xml;

    xml.loadFile(settingsfile);
    int numscenes = xml.getNumTags("scene");

    if(numscenes > 0 ) {
        // store filenames
        for(int i=0; i < numscenes; i++) {
            string scenefile = xml.getValue("scene", "nofile.jpg", i);
            scenefiles.push_back(scenefile);
        }

        // debug information (text, mouse, thumbnail) //
        bShowThumbnail = (xml.getValue("drawthumbnail", 0) > 0);
        bHideCursor = (xml.getValue("hidecursor", 0) > 0);
        bDebug = (xml.getValue("debug", 0) > 0);
        bool bFullscreen = (xml.getValue("fullscreen", 0) > 0);
        ofSetFullscreen(bFullscreen);

        // osc receiving
        port = xml.getValue("oscport", 12345);

        // load first scene
        loadXMLScene(scenefiles[0]);
    } else {
        ofLog(OF_LOG_WARNING, "No scenes in file " +ofToString(settingsfile)+", exiting.");
        ofExit();
    }

}

void ofApp::loadXMLScene(string scenefile) {

    ofLog(OF_LOG_NOTICE, "loading scene " + scenefile);

    ofxXmlSettings xml;

    xml.loadFile(scenefile);

    // lightfield images //
    lffilename = xml.getValue("texturefile", "nofile.jpg");

    // image layout
    subwidth = xml.getValue("subimagewidth", 0);
    subheight = xml.getValue("subimageheight", 0);
    xsubimages = xml.getValue("numxsubimages", 0);
    ysubimages = xml.getValue("numysubimages", 0);

    // refocusing params //
    minScale = xml.getValue("minscale", 0);
    maxScale = xml.getValue("maxscale", 0);

    // rendering state //
    xstart = xml.getValue("xstart", 0);
    ystart = xml.getValue("ystart", 0);
    xcount = xml.getValue("xcount", xsubimages);
    ycount = xml.getValue("ycount", ysubimages);

    focus = xml.getValue("scale", 0);
    zoom = xml.getValue("zoom", 1.0);
    xoffset = 0;
    yoffset = 0;

    // read camera positions
    xml.pushTag("cameras");
    for(int i = 0; i < xml.getNumTags("cam"); i++) {
        xml.pushTag("cam", i);
        float xoff = xml.getValue("x", 0.0);
        float yoff = xml.getValue("y", 0.0);
        // store in array for OpenGL
        offsets[i*2] = xoff;
        offsets[i*2 + 1] = -yoff;
        xml.popTag();
    }
    xml.popTag();

}

void ofApp::loadLightfieldData() {

	ofLoadImage(lfplane, lffilename);
}

void ofApp::freeLightfieldData() {

    lfplane.clear();
    ofLog(OF_LOG_NOTICE, "cleared texture 0");
        //  lfplanes[i].setTextureWrap(GL_CLAMP_TO_BORDER, GL_CLAMP_TO_BORDER);//GL_REPEAT, GL_REPEAT);//
//        GLfloat border[4]={0, 1, 0, 0};
//        glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, border);
        //lfplanes[i].setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);//NEAREST, GL_NEAREST);
}


void ofApp::setupGraphics() {
    // fade
    fade = 255.0;

    // allocate fbos
    fbo = ofPtr<ofFbo>(new ofFbo());
    fbo->allocate(subwidth,subheight);
    if(fbo->isAllocated())
        cout << "fbo is Allocated" << endl;

    maskFbo = ofPtr<ofFbo>(new ofFbo());
    maskFbo->allocate(subwidth,subheight);
    if(fbo->isAllocated())
        cout << "maskFbo is Allocated" << endl;

    // clear the fbos
    fbo->begin();
    ofClear(0,0,0,255);
    fbo->end();

    maskFbo->begin();
    ofClear(0,0,0,255);
    maskFbo->end();

    // load camera positions into texture
    int numCams = xsubimages * ysubimages;

    // make array of float pixels with camera position information
    float * pos = new float[numCams*3];
    for (int x = 0; x < xsubimages; x++){
        for (int y = 0; y < ysubimages; y++){
            int i = x + (y * xsubimages);

            pos[i*3 + 0] = offsets[i*2];
            pos[i*3 + 1] = offsets[i*2+1];
            pos[i*3 + 2] = 0.0;
        }
    }

    campos_tex.allocate(xsubimages, ysubimages, GL_RGB32F);
    campos_tex.getTextureReference().loadData(pos, xsubimages, ysubimages, GL_RGB);
    delete pos;

    // TODO: implement subimage corners as texture to optimize?
    //    // make array of float pixels with camera position information
//    unsigned char * corners = new unsigned char [numCams*3];
//    for (int x = 0; x < xsubimages; x++){
//        for (int y = 0; y < ysubimages; y++){
//            int i = x + (y * xsubimages);
//
//            corners[i*3 + 0] = x * subwidth;
//            corners[i*3 + 1] = y * subheight;
//            corners[i*3 + 2] = 0.0;
//        }
//    }
//
//    subimg_corner_tex.allocate(xsubimages, ysubimages, GL_RGB32I);
//    subimg_corner_tex.getTextureReference().loadData(corners, xsubimages, ysubimages, GL_RGB);
//    delete corners;

//    // initialize aperture mask to zero (no images used)
//    aperture_mask = new float [numCams * 3];
//
//    for (int i=0; i < numCams *3; i++)
//        aperture_mask[i] = 0.0;
//
//    aperture_mask_tex.allocate(xsubimages, ysubimages, GL_RGB32F);
//    aperture_mask_tex.getTextureReference().loadData(aperture_mask, xsubimages, ysubimages, GL_RGB);
//
//    updateAperture();

    // setup refocus shader
    shader.setupShaderFromFile(GL_FRAGMENT_SHADER, "./shaders/refocus.frag");
    shader.linkProgram();


    shader.begin();

    // camera images
    shader.setUniformTexture("lftex", lfplane, 1);

    shader.setUniform2f("resolution", subwidth, subheight);
    shader.setUniform2i("subimages", xsubimages, ysubimages);

    shader.setUniformTexture("campos_tex", campos_tex, 2);
//    shader.setUniformTexture("subimg_corner_tex", subimg_corner_tex, 3);
    shader.end();


    //    GLint maxTextureSize;
    //    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    //    std::cout <<"Max texture size: " << maxTextureSize << std::endl;

    //        GLint v_maj;
    //    glGetIntegerv(GL_MAJOR_VERSION, &v_maj);
    //        std::cout <<"gl major version: " << v_maj << std::endl;

}

//void ofApp::updateAperture() {
//
//    // set pixels to 1.0 for used, 0.0 for not used
//    for (int x=0; x < xsubimages; x++) {
//        for(int y=0; y < ysubimages; y++) {
//            int i = x + y * xsubimages;
//            if(ofInRange(x, xstart, xcount) && ofInRange(y, ystart, ycount)) {
//                aperture_mask[i*3] = 1.0;
//            } else {
//                aperture_mask[i*3] = 0.0;
//            }
//        }
//    }
//
//    // update aperture on graphics card
//    aperture_mask_tex.getTextureReference().loadData(aperture_mask, xsubimages, ysubimages, GL_RGB);
//}

//--------------------------------------------------------------
//  keyboard interaction / osc control
//--------------------------------------------------------------

void ofApp::keyPressed(int key){
    //    cout << bShowThumbnail << " " << bHideCursor << " " << bDebug << endl;
    if(key=='s') {
        snapshot();
    }
    if(key=='f')
        ofToggleFullscreen();
    if(key=='b') {
        // zoom
        zoom = ofMap(mouseX, 0, ofGetWindowWidth(), 4.0, 0.01);
    }
    if(key=='z') {
        // parallax
        xstart = ofMap(mouseX, 0, ofGetWindowWidth(), 0, xsubimages-xcount+1);
        ystart = ofMap(mouseY, 0, ofGetWindowHeight(), 0, ysubimages-ycount+1);
    }
    if(key=='x') {
        // number of subimages in resynthesis
        xcount = ofMap(mouseX, 0, ofGetWindowWidth(), 0, xsubimages);
        ycount = ofMap(mouseY, 0, ofGetWindowHeight(), 0, ysubimages);
        if(xcount+xstart > xsubimages)
            xstart = xsubimages - xcount;
        if(ycount + ystart > ysubimages)
            ystart = ysubimages - ycount;
    }
    if(key == 'v') {
        // offsets
        xoffset = ofMap(mouseX, 0, ofGetWindowWidth(), -subwidth, subwidth);
        yoffset = ofMap(mouseY, 0, ofGetWindowHeight(), -subheight, subheight);
    }
    if(key == 'c')
        // focus
        focus = ofMap(mouseX, 0, ofGetWindowWidth(), minScale, maxScale);
    if(key == 't') {
        bShowThumbnail = (bShowThumbnail == 0);
        cout << "t " << bShowThumbnail << endl;
    }
    if(key == 'm') {
        bHideCursor = !bHideCursor;
        if (bHideCursor) {
            ofHideCursor();
        } else {
            ofShowCursor();
        };
    }

    if(key == 'd') {
        bDebug = (bDebug == 0) ;
        cout << "d " << bDebug << endl;
    }
}


void ofApp::process_OSC(ofxOscMessage m) {

    if( m.getAddress() == "/focus" ){
        focus = subwidth * m.getArgAsFloat(0);
    }
    else if( m.getAddress() == "/loadScene") {
        string scenefile = m.getArgAsString(0);

        ofFile file(scenefile);

        if(file.doesFileExist(scenefile)) {
            // suspend render
            bSuspendRender = true;

            freeLightfieldData();

            // TODO: I think this vector of scene files is unnecessary
            scenefiles.clear();
            scenefiles.push_back(scenefile);

            loadXMLScene(scenefile);

            loadLightfieldData();

            setupGraphics();

            bSuspendRender = false;
        } else {
            ofLog(OF_LOG_WARNING, "requested file " + scenefile + " does not exist.");
        }
    }
    else if( m.getAddress() == "/fade") {
        fade = m.getArgAsFloat(0);
    }
    else if( m.getAddress() == "/xstart" ){
//        xstart = m.getArgAsFloat(0);

        int startRequested, constrainByRange, xAvail;

        startRequested = m.getArgAsFloat(0);
        if ( m.getNumArgs() == 2 ){
            constrainByRange = m.getArgAsFloat(1);
        } else {
            constrainByRange = 0; // default to unconstrained
        };
        xAvail = xsubimages - xstart;

        if( (startRequested + xcount) <= xsubimages ){
            xstart = startRequested;
        }
        else if( constrainByRange == 1 ){
            xstart = xsubimages - xcount;
        }
        // can shrink range to acheive requested start
        else{
            xstart = min( startRequested, xsubimages);
            xcount = xsubimages - xstart;
        }
    }

    else if(m.getAddress() == "/ystart"){
//        ystart = m.getArgAsFloat(0);

        int startRequested, constrainByRange, yAvail;

        startRequested = m.getArgAsFloat(0);
        if ( m.getNumArgs() == 2 ){
            constrainByRange = m.getArgAsFloat(1);
        } else {
            constrainByRange = 0; // default to unconstrained
        };
        yAvail = ysubimages - ystart;

        if( (startRequested + ycount) <= ysubimages ){
            ystart = startRequested;
        }
        else if( constrainByRange == 1 ){
            ystart = ysubimages - ycount;
        }
        // can shrink range to acheive requested start
        else{
            ystart = min( startRequested, ysubimages);
            ycount = ysubimages - ystart;
        }
    }

    else if(m.getAddress() == "/xcount"){
//        xcount = m.getArgAsFloat(0);

        int rangeRequested, constrainByXStart, xAvail;
        rangeRequested = m.getArgAsFloat(0);
        if ( m.getNumArgs() == 2 ){
            constrainByXStart = m.getArgAsFloat(1);
        } else {
            constrainByXStart = 0; // default to unconstrained
        };
        xAvail = xsubimages - xstart;

        if( rangeRequested <= xAvail ){
            xcount = rangeRequested;
        }
        else if( constrainByXStart == 1 ){
            xcount = xAvail;
        }
        // can grow by moving xstart
        else{
            int xshift;
            xshift = rangeRequested - xAvail;
            xstart = max( xstart - xshift, 0);
            xcount = xsubimages - xstart;
        }
    }

    else if(m.getAddress() == "/ycount"){
//            ycount = m.getArgAsFloat(0);

        int rangeRequested, constrainByYStart, yAvail;
        rangeRequested = m.getArgAsFloat(0);
        if ( m.getNumArgs() == 2 ){
            constrainByYStart = m.getArgAsFloat(1);
        } else {
            constrainByYStart = 0; // default to unconstrained
        };
        yAvail = ysubimages - ystart;

        if( rangeRequested <= yAvail ){
            ycount = rangeRequested;
        }
        else if( constrainByYStart == 1 ){
            ycount = yAvail;
        }
        // can grow by moving ystart
        else{
            int yshift;
            yshift = rangeRequested - yAvail;
            ystart = max( ystart - yshift, 0);
            ycount = ysubimages - ystart;
        }
    }

    else if(m.getAddress() == "/xscroll"){
        xoffset = subwidth * m.getArgAsFloat(0);
    }

    else if(m.getAddress() == "/yscroll"){
        yoffset = subheight * m.getArgAsFloat(0);
    }

    else if(m.getAddress() == "/zoom"){
        zoom = m.getArgAsFloat(0);
    }

    else {
        // unrecognized message: display on the bottom of the screen
        string msg_string;
        msg_string += "Unknown OSC msg: ";
        msg_string += m.getAddress();
        msg_string += ": ";
        for(int i = 0; i < m.getNumArgs(); i++){
            // get the argument type
            msg_string += m.getArgTypeName(i);
            msg_string += ": ";
            // display the argument - make sure we get the right type
            if(m.getArgType(i) == OFXOSC_TYPE_INT32){
                msg_string += ofToString(m.getArgAsFloat(i));
            }
            else if(m.getArgType(i) == OFXOSC_TYPE_FLOAT){
                msg_string += ofToString(m.getArgAsFloat(i));
            }
            else if(m.getArgType(i) == OFXOSC_TYPE_STRING){
                msg_string += m.getArgAsString(i);
            }
            else{
                msg_string += "unknownType";
            }
        }
        // post the uknown message
        cout << msg_string << endl;
        }

}


//--------------------------------------------------------------
// snapshot
//--------------------------------------------------------------

void ofApp::snapshot() {
    string timestamp, imgfilename, paramfilename;

    // save sequential snapshot image to data folder
    bool done = false;

    snapcount = 0;
    while(!done) {
        ofFile file(scenefiles[0]);
        string filename = file.getBaseName();
//        timestamp = "./snapshots/"+filename+ "_" +ofGetTimestampString("%m%d%H%M")+"_" + ofToString(snapcount, 4, '0');
        timestamp = "./snapshots/"+filename+"_" + ofToString(snapcount, 4, '0');
        imgfilename = timestamp + ".jpg";
        paramfilename = timestamp + ".txt";
        ofFile test;
        if(!test.doesFileExist(imgfilename))
            done = true;
        snapcount++;
    }

    // fbo pixels
    int w = fbo->getWidth();
    int h = fbo->getHeight();
    unsigned char* fbo_pixels = new unsigned char[w*h*3];

    // crop to projection size
    int crop_w = h / SCREEN_HEIGHT * SCREEN_WIDTH;
    int edge = (w-crop_w)/2.0;

    // output images
    ofImage screenGrab;
    unsigned char* img_pixels = new unsigned char[crop_w*h*3];

    screenGrab.allocate(crop_w,h,OF_IMAGE_COLOR);
    screenGrab.setUseTexture(false);

    //copy the pixels from FBO to the pixel array; then set the normal ofImage from those pixels; and use the save method of ofImage
    fbo->begin();
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, fbo->getWidth(), fbo->getHeight(), GL_RGB, GL_UNSIGNED_BYTE, fbo_pixels);

    // copy cropped window from fbo to screengrab pixels
    for(int x=edge; x<edge+crop_w; x++) {
        for(int y=0; y<h; y++) {
            int fbo_i = (x+y*w) * 3;
            int img_i = ((x-edge) + y*crop_w) * 3;
            img_pixels[img_i]=fbo_pixels[fbo_i];
            img_pixels[img_i+1]=fbo_pixels[fbo_i+1];
            img_pixels[img_i+2]=fbo_pixels[fbo_i+2];
        }
    }
    
    screenGrab.setFromPixels(img_pixels, crop_w, h, OF_IMAGE_COLOR);
    screenGrab.saveImage(imgfilename, OF_IMAGE_QUALITY_BEST);
    
    fbo->end();
    ofLog(OF_LOG_VERBOSE, "[DiskOut]  saved frame " + imgfilename );

    // save refocusing parameters to companion text file
    ofFile file(paramfilename, ofFile::WriteOnly);

    file << scenefiles[0] << endl;
    file << focus/float(subwidth) << endl;
    file << xoffset/float(subwidth) << "," << yoffset/float(subheight) << endl;
    file << xstart << "," << ystart << endl;
    file << xcount << "," << ycount << endl;
    file << zoom << endl;

    file.close();
}

