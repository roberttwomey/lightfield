#include "ofApp.h"


//--------------------------------------------------------------
// main program
//--------------------------------------------------------------

void ofApp::setup(){

    ofEnableAlphaBlending();

//    loadXMLSettings("./textures/carkeek_tile.xml");
//    loadXMLSettings("./textures/dark_trees_tile.xml");
    loadXMLSettings("./textures/mike1_tile.xml");

    loadLFImage();

    graphicsSetup();
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

    fbo.begin();
    ofClear(0, 0, 0,255);

    shader.begin();

    // aperture
    shader.setUniform2i("ap_loc", xstart, ystart);
    shader.setUniform2i("ap_size", xcount, ycount);

    // focus
    shader.setUniform1f("fscale", synScale);

    // zoom / pan
    shader.setUniform1f("zoom", zoom);
    shader.setUniform2f("roll", xoffset, yoffset);

    shader.setUniform1i("tilenum", tilenum);

    maskFbo.draw(0,0);

    shader.end();

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
    float tHeight = 160/xsubimages * ysubimages;

    // fused image size
    float height = ofGetWindowHeight();
    float width = height/subheight*subwidth;
    float xoff = (ofGetWindowWidth() - width)/2;

    ofSetColor(255);

    // draw fused image
    fbo.draw(xoff, 0, width, height);

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

    // lightfield images //
    numlftiles = xml.getNumTags("texturefile");
    for(int i=0; i < numlftiles; i++) {
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

void ofApp::loadLFImage() {
//    ofLoadImage(lfplane, lffilenames);
//
//    sourceWidth=lfplane.getWidth();
//    sourceHeight=lfplane.getHeight();
//
//    cout << "LF Texture: " << sourceWidth << ", " << sourceHeight << endl;

    for(int i=0; i < numlftiles; i++) {
        cout << "loading texture" << i << " from " << lffilenames[i] << "...";
        ofLoadImage(lfplanes[i], lffilenames[i]);
        cout << "done." << endl;
    }

    cout << "done loading textures" << endl;

}

void ofApp::graphicsSetup() {

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

    // make array of float pixels with camera position information
    float * pos = new float[numCams*3];
    for (int x = 0; x < xsubimages; x++){
        for (int y = 0; y < ysubimages; y++){
            int i = x + (y * xsubimages);

            pos[i*3 + 0] = offsets[i*2];
            pos[i*3 + 1] = offsets[i*2+1]; //y*offset;
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

    // make array of integers with texture tile number for each camera view
    tilewidth = ximagespertex * subwidth;
    tileheight = yimagespertex * subheight;

    float * tilenums = new float [numCams*3];
    float * texpixoffsets = new float [numCams*3];

    for (int y = 0; y < ysubimages; y++){
        for (int x = 0; x < xsubimages; x++){
            int i = x + (y * xsubimages);
            int x_tile = x / ximagespertex;
            int y_tile = y / yimagespertex;
            int tilenum = x_tile + y_tile * xnumtextures;

            cout << tilenum << " " << x_tile << " " << y_tile << endl;

            tilenums[i*3 + 0] = tilenum;//;//ofRandom(255.0);//128.0;//float(tilenum) * 16.0;
            tilenums[i*3 + 1] = 0;//ofRandom(255.0);//0.0;
            tilenums[i*3 + 2] = 0;//ofRandom(255.0);//0.0;

            int xpixoffset = x_tile * tilewidth;
            int ypixoffset = y_tile * tileheight;

            texpixoffsets[i*3 + 0] = xpixoffset;
            texpixoffsets[i*3 + 1] = ypixoffset;
            texpixoffsets[i*3 + 2] = 0;

//            cout << tilenum << " " << xpixoffset << " " << ypixoffset << endl;

        }
    }

    tilenum_tex.allocate(xsubimages, ysubimages, GL_RGB32F);//GL_RGB32I);
    tilenum_tex.getTextureReference().loadData(tilenums, xsubimages, ysubimages, GL_RGB);
    delete tilenums;

    tilepixoffset_tex.allocate(xsubimages, ysubimages, GL_RGB32F);//GL_RGB32I);
    tilepixoffset_tex.getTextureReference().loadData(texpixoffsets, xsubimages, ysubimages, GL_RGB);
    delete texpixoffsets;


    // setup refocus shader
    shader.setupShaderFromFile(GL_FRAGMENT_SHADER, "./shaders/refocus_tile_150.frag");
    shader.linkProgram();

    shader.begin();

    // camera images
    int i=0;

    for(i=0; i < 16; i++)
        shader.setUniformTexture("lftex["+ofToString(i)+"]", lfplanes[i], i+1);


//    shader.setUniformTexture("lftex1", lfplanes[0], 1);
//    shader.setUniformTexture("lftex2", lfplanes[1], 2);
//    shader.setUniformTexture("lftex3", lfplanes[2], 3);
//    shader.setUniformTexture("lftex4", lfplanes[3], 4);
//    shader.setUniformTexture("lftex5", lfplanes[4], 5);
//    shader.setUniformTexture("lftex6", lfplanes[5], 6);
//    shader.setUniformTexture("lftex7", lfplanes[6], 7);
//    shader.setUniformTexture("lftex8", lfplanes[7], 8);
//    shader.setUniformTexture("lftex9", lfplanes[8], 9);
//    shader.setUniformTexture("lftex10", lfplanes[9], 10);
//    shader.setUniformTexture("lftex11", lfplanes[10], 11);
//    shader.setUniformTexture("lftex12", lfplanes[11], 12);

    shader.setUniform2f("resolution", subwidth, subheight);
    shader.setUniform2i("subimages", xsubimages, ysubimages);

    shader.setUniformTexture("campos_tex", campos_tex, 17);
    shader.setUniformTexture("tilenum_tex", tilenum_tex, 18);
    shader.setUniformTexture("tilepixoffset_tex", tilepixoffset_tex, 19);

    shader.end();


//        GLint maxTextureSize;
//        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
//        std::cout <<"Max texture size: " << maxTextureSize << std::endl;

    //        GLint v_maj;
    //    glGetIntegerv(GL_MAJOR_VERSION, &v_maj);
    //        std::cout <<"gl major version: " << v_maj << std::endl;

}


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
        tilenum = (tilenum + 1) % numlftiles;
    }

}


void ofApp::process_OSC(ofxOscMessage m) {

    if( m.getAddress() == "/lf/focus" ){
        synScale = ofMap(m.getArgAsFloat(0), 0.0, 1.0, minScale, maxScale);
    }
    else if( m.getAddress() == "/lf/xStart" ){
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

    else if(m.getAddress() == "/lf/yStart"){
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

    else if(m.getAddress() == "/lf/xRange"){
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

    else if(m.getAddress() == "/lf/yRange"){
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
    for(int i=0; i < numlftiles; i++)
        file << lffilenames[i] << endl;
    file << synScale << endl;
    file << xoffset << "," << yoffset << endl;
    file << xstart << "," << ystart << endl;
    file << xcount << "," << ycount << endl;
    file << zoom << endl;

    file.close();

    snapcount++;
}

