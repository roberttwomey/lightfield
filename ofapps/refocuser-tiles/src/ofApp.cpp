#include "ofApp.h"

//--------------------------------------------------------------
// main program
//--------------------------------------------------------------

void ofApp::setup(){
    ofEnableAlphaBlending();

    loadXMLSettings("scenes.xml");

    loadLightfieldData();

    setupGraphics();

    // OSC - listen on the given port
    cout << "listening for osc messages on port " << port << "\n";
    receiver.setup(port);

    snapcount = 0;
}

//--------------------------------------------------------------

void ofApp::update(){

    // TODO: why is this here?
    maskFbo.begin();
    ofClear(255, 0, 0,255);
    maskFbo.end();

    for(int i=0; i < numlftextures; i++) {
        refocusFbo[i].begin();
        ofClear(0, 0, 0, 255);

        shader[i].begin();

        // aperture
        shader[i].setUniform2i("ap_loc", xstart, ystart);
        shader[i].setUniform2i("ap_size", xcount, ycount);

    //    updateAperture();
        // focus
        shader[i].setUniform1f("fscale", synScale);

        // zoom / pan
        shader[i].setUniform1f("zoom", zoom);
        shader[i].setUniform2f("roll", xoffset, yoffset);

        maskFbo.draw(0,0);

        shader[i].end();

        refocusFbo[i].end();
    }


//    // TODO: why is this here?
    maskFbo.begin();
    ofClear(255, 0, 0,255);
    maskFbo.end();
//
//
    fbo.begin();
    ofClear(0, 0, 0, 255);

    combineShader.begin();

//    for(int i=0; i < numlftextures; i++) {
//        combineShader.setUniformTexture("refocustex[" + ofToString(i) + "]", refocusFbo[i].getTextureReference(), i+9);
//    }

    maskFbo.draw(0, 0);

    combineShader.end();
    fbo.end();


    ofSetWindowTitle( ofToString( ofGetFrameRate(), 2));

    // ~~~ OSC handling ~~~
    // check for waiting messages
    while(receiver.hasWaitingMessages()){
        // get the next message
        ofxOscMessage m;
        receiver.getNextMessage(&m);

        process_OSC(m);

    };
    // ~~~~ end OSC ~~~~

}

//--------------------------------------------------------------
void ofApp::draw(){
    ofBackground(ofColor::black);

    // thumbnail size
    float tWidth = 160;
    float tHeight = 160/xnumtextures * ynumtextures;

    // fused image size
    float height = ofGetWindowHeight();
    float width = height/subheight*subwidth;
    float xoff = (ofGetWindowWidth() - width)/2;

    ofSetColor(255);

    // draw fused image
    fbo.draw(xoff, 0, width, height);

//    refocusFbo[tilenum].draw(xoff, 0, width, height);

//    refocusFbo[0].draw(xoff, 0, width/2, height/2);
//    refocusFbo[1].draw(xoff+width/2, 0, width/2, height/2);
//    refocusFbo[2].draw(xoff, 0+height/2, width/2, height/2);
//    refocusFbo[3].draw(xoff+width/2, 0+height/2, width/2, height/2);

//    for(int i=0; i < numlftextures; i++)
//        refocusFbo[i].draw(xoff,0, width, height);

    // draw thumbnail with indicator
    if(bShowThumbnail == true) {
        ofSetColor(255);

        // draw separate textures
        int tSubWidth = tWidth / xnumtextures;
        int tSubHeight = tHeight / ynumtextures;

        for (int x = 0; x < xnumtextures; x++){
            for (int y = 0; y < ynumtextures; y++){
                int i = x + y * xnumtextures;
                lfplanes[i].draw(5 + tSubWidth * x ,5 + tSubWidth * y, tSubWidth, tSubHeight);
            }
        }

        ofSetColor(255, 0, 0);
        ofNoFill();
        float xunit = float(tSubWidth) / float(ximagespertex);
        float yunit = float(tSubHeight) / float(yimagespertex);
        ofRect(5+xstart*xunit, 5+ystart*yunit, xcount*xunit, ycount*yunit);
    }

    if(bDebug == true) {
        // display text about refocusing
        ofSetColor(255);
        ofTranslate(10, ofGetHeight()-90);
//        ofDrawBitmapString("tilenum:  \t"+ofToString(tilenum), 0, -15);
        ofDrawBitmapString("scale:    \t"+ofToString(synScale), 0, 0);
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

        // load first scene
        loadXMLScene(scenefiles[0]);
    } else {
        cout << "No scenes in file" << settingsfile << ". Exiting." << endl;
        ofExit();
    }

}

void ofApp::loadXMLScene(string scenefile) {
    ofxXmlSettings xml;

    xml.loadFile(scenefile);

    // lightfield images //
    numlftextures = xml.getNumTags("texturefile");
    for(int i=0; i < numlftextures; i++) {
        lffilenames[i] = xml.getValue("texturefile", "nofile.jpg", i);
    }

    // number of large textures
    xnumtextures = xml.getValue("xnumtextures", -1);
    ynumtextures = xml.getValue("ynumtextures", -1);
    ximagespertex = xml.getValue("ximagespertex", -1);
    yimagespertex = xml.getValue("yimagespertex", -1);

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

    synScale = xml.getValue("scale", 0);
    zoom = xml.getValue("zoom", 1.0);
    xoffset = 0;
    yoffset = 0;

    // debug information (text, mouse, thumbnail) //
    bShowThumbnail = (xml.getValue("drawthumbnail", 0) > 0);
    bHideCursor = (xml.getValue("hidecursor", 0) > 0);
    bDebug = (xml.getValue("debug", 0) > 0);

    // osc receiving
    port = xml.getValue("oscport", 12345);

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

    for(int i=0; i < numlftextures; i++) {
        ofLoadImage(lfplanes[i], lffilenames[i]);
        ofLog(OF_LOG_NOTICE, "loaded texture "+ ofToString(i) + " from " + lffilenames[i]);
//        lfplanes[i].setTextureWrap(GL_CLAMP_TO_BORDER, GL_CLAMP_TO_BORDER);//GL_REPEAT, GL_REPEAT);//
//        GLfloat border[4]={0, 1, 0, 0};
//        glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, border);
        //lfplanes[i].setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);//NEAREST, GL_NEAREST);
    }

    ofLog(OF_LOG_NOTICE, "done loading textures.");
}

void ofApp::setupGraphics() {

    fbo.allocate(subwidth,subheight);
    maskFbo.allocate(subwidth,subheight);

    // Lets clear the FBOs
    // otherwise it will bring some junk with it from the memory
    fbo.begin();
    ofClear(0,0,0,255);
    fbo.end();

    maskFbo.begin();
    ofClear(0,0,0,255);
    maskFbo.end();

    // load camera positions into texture
    int numCams = xsubimages * ysubimages;

    for(int i=0; i < numlftextures; i++) {
        ofLog(OF_LOG_NOTICE, "allocating refocus fbo " + ofToString(i));

        refocusFbo[i].allocate(subwidth,subheight);
        refocusFbo[i].begin();
        ofClear(0,0,0,255);
        refocusFbo[i].end();
    }

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


    // setup refocus shader per tile texture
    int tn = 1;

    for(int y = 0; y < ynumtextures; y++) {
        for(int x = 0; x < xnumtextures; x++) {
            int i = x + y * xnumtextures;

            // initialize shader
            ofLog(OF_LOG_NOTICE, "initializing shader " + ofToString(i));
            shader[i].setupShaderFromFile(GL_FRAGMENT_SHADER, "./shaders/refocus_per_tile_150.frag");
            shader[i].linkProgram();

            shader[i].begin();

            shader[i].setUniformTexture("lftex", lfplanes[i], tn++);

            // data textures for shader
        //    shader[0].setUniformTexture("aperture_mask_tex", aperture_mask_tex, i++);
            shader[i].setUniformTexture("campos_tex", campos_tex, tn++);

            // set texture pixel offsets to index from virtual, large texture atlas
            // to individual tile coords
            float xtilepixoffset = x * lfplanes[i].getWidth();
            float ytilepixoffset = y * lfplanes[i].getHeight();

            shader[i].setUniform2f("tilepixoffset", xtilepixoffset, ytilepixoffset );//[i], tn++);

            // one-time data setparameters
            shader[i].setUniform2f("resolution", subwidth, subheight);
            shader[i].setUniform2i("subimages", xsubimages, ysubimages);

            shader[i].end();

            ofLog(OF_LOG_NOTICE, "shader end " + ofToString(i));
        }
    }

    // set up shader to combine the four refocus fbos
    ofLog(OF_LOG_NOTICE, "initializing combine shader ");
    combineShader.setupShaderFromFile(GL_FRAGMENT_SHADER, "./shaders/blend_per_tile_150.frag");
    combineShader.linkProgram();

    combineShader.begin();
    combineShader.setUniform1i("numtextures", numlftextures);

    // TODO: uncommenting this prevents refocusFbo from working

    for(int i=0; i < numlftextures; i++)
        combineShader.setUniformTexture("refocustex[" + ofToString(i) + "]", refocusFbo[i].getTextureReference(), tn++);

    combineShader.end();

    ofLog(OF_LOG_NOTICE, "combine shader end");


//        GLint maxTextureSize;
//        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
//        std::cout <<"Max texture size: " << maxTextureSize << std::endl;

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
        doSnapshot();
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
        synScale = ofMap(mouseX, 0, ofGetWindowWidth(), minScale, maxScale);
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

    if(key == '+') {
        tilenum = (tilenum + 1) % numlftextures;
    }

}


void ofApp::process_OSC(ofxOscMessage m) {

    if( m.getAddress() == "/focus" ){
        synScale = m.getArgAsFloat(0);//ofMap(m.getArgAsFloat(0), 0.0, 1.0, minScale, maxScale);
    }
    else if( m.getAddress() == "/xstart" ){
//        xstart = m.getArgAsInt32(0);

        int startRequested, constrainByRange, xAvail;

        startRequested = m.getArgAsInt32(0);
        if ( m.getNumArgs() == 2 ){
            constrainByRange = m.getArgAsInt32(1);
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
//        ystart = m.getArgAsInt32(0);

        int startRequested, constrainByRange, yAvail;

        startRequested = m.getArgAsInt32(0);
        if ( m.getNumArgs() == 2 ){
            constrainByRange = m.getArgAsInt32(1);
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
//        xcount = m.getArgAsInt32(0);

        int rangeRequested, constrainByXStart, xAvail;
        rangeRequested = m.getArgAsInt32(0);
        if ( m.getNumArgs() == 2 ){
            constrainByXStart = m.getArgAsInt32(1);
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
//            ycount = m.getArgAsInt32(0);

        int rangeRequested, constrainByYStart, yAvail;
        rangeRequested = m.getArgAsInt32(0);
        if ( m.getNumArgs() == 2 ){
            constrainByYStart = m.getArgAsInt32(1);
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
        xoffset = m.getArgAsFloat(0);
    }

    else if(m.getAddress() == "/yscroll"){
        yoffset = m.getArgAsFloat(0);
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
                msg_string += ofToString(m.getArgAsInt32(i));
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

void ofApp::doSnapshot() {
    string timestamp, imgfilename, paramfilename;

    // save time-stamped image to data folder
    timestamp = "./snapshots/"+ofGetTimestampString("%Y%m%d%H%M%S") + "_" + ofToString(snapcount, 4, '0');
    imgfilename = timestamp + ".jpg";
    paramfilename = timestamp + ".txt";

    // save fbo to file
    // from http://forum.openframeworks.cc/t/ofxfenster-addon-to-handle-multiple-windows-rewrite/6499/61
    int w = fbo.getWidth();
    int h = fbo.getHeight();
    unsigned char* pixels = new unsigned char[w*h*3];  ;
    ofImage screenGrab;
    screenGrab.allocate(w,h,OF_IMAGE_COLOR);
    screenGrab.setUseTexture(false);

    //copy the pixels from FBO to the pixel array; then set the normal ofImage from those pixels; and use the save method of ofImage
    fbo.begin();
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, fbo.getWidth(), fbo.getHeight(), GL_RGB, GL_UNSIGNED_BYTE, pixels);
    screenGrab.setFromPixels(pixels, fbo.getWidth(), fbo.getHeight(), OF_IMAGE_COLOR);
    screenGrab.saveImage(imgfilename, OF_IMAGE_QUALITY_BEST);
    fbo.end();
    ofLog(OF_LOG_VERBOSE, "[DiskOut]  saved frame " + imgfilename );

    // save refocusing parameters to companion text file
    ofFile file(paramfilename, ofFile::WriteOnly);

    // add additional parameters below
    for(int i=0; i < numlftextures; i++)
        file << lffilenames[i] << endl;
    file << synScale << endl;
    file << xoffset << "," << yoffset << endl;
    file << xstart << "," << ystart << endl;
    file << xcount << "," << ycount << endl;
    file << zoom << endl;

    file.close();

    snapcount++;
}
