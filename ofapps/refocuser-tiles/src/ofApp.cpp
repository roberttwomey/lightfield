#include "ofApp.h"


//--------------------------------------------------------------
void ofApp::setup(){

    ofEnableAlphaBlending();
    loadXMLSettings("./textures/carkeek_tile.xml");

    loadLFImage();

    graphicsSetup();

    // OSC - listen on the given port
    cout << "listening for osc messages on port " << port << "\n";
    receiver.setup(port);
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

    shader.setUniform2i("ap_loc", xstart, ystart);
    shader.setUniform2i("ap_size", xcount, ycount);

    // focus
    shader.setUniform1f("fscale", synScale);

    // zoom / pan
    shader.setUniform1f("zoom", zoom);
    shader.setUniform2f("roll", xoffset, yoffset);

    maskFbo.draw(0,0);

    shader.end();

    fbo.end();

    ofSetWindowTitle( ofToString( ofGetFrameRate()));

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
    float tWidth = 160;//320;
    float tHeight = 160/xsubimages * ysubimages; //90;//180;

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
        lfplane1.draw(5,5,tWidth,tHeight);
        ofSetColor(255, 0, 0);
        ofNoFill();
        float xunit = tWidth/xsubimages;//29.;
        float yunit = tHeight/ysubimages;//20.0;
        ofRect(5+xstart*xunit, 5+ystart*yunit, xcount*xunit, ycount*yunit);
    }

    if(bDebug == true) {
        // display text about refocusing
        ofSetColor(255);
        ofTranslate(10, ofGetHeight()-75);
        ofDrawBitmapString("scale:   \t"+ofToString(synScale), 0, 0);
        ofDrawBitmapString("roll:    \t"+ofToString(xoffset)+" "+ofToString(yoffset), 0, 15);
        ofDrawBitmapString("ap_loc:  \t"+ofToString(xstart)+" "+ofToString(ystart) +" ("+ofToString(xstart + ystart * xsubimages)+")", 0, 30);
        ofDrawBitmapString("ap_size: \t"+ofToString(xcount)+" "+ofToString(ycount), 0, 45);
        ofDrawBitmapString("zoom:    \t"+ofToString(zoom), 0, 60);
//        cout << bDebug << bShowThumbnail << endl;
    }
}

//--------------------------------------------------------------
// settings
//--------------------------------------------------------------

void ofApp::loadXMLSettings(string settingsfile) {
    ofxXmlSettings xml;

    xml.loadFile(settingsfile);

    // lightfield images //
    lfimage_filename = xml.getValue("texturefile", "nofile.jpg");

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
    //lfplane.loadImage(lfimage_filename);
//    cout << "loading texture1...";
//    ofLoadImage(lfplane1, "./textures/tunnel_tex_lgt-0.jpg");
//    cout << "done." << endl << "loading texture2...";
//    ofLoadImage(lfplane2, "./textures/tunnel_tex_lgt-1.jpg");
//    cout << "done." << endl << "loading texture3...";
//    ofLoadImage(lfplane3, "./textures/tunnel_tex_lgt-2.jpg");
//    cout << "done." << endl << "loading texture4...";
//    ofLoadImage(lfplane4, "./textures/tunnel_tex_lgt-3.jpg");

    cout << "loading texture1...";
    ofLoadImage(lfplane1, "./textures/carkeek_tile-0.jpg");
    cout << "done." << endl << "loading texture2...";
    ofLoadImage(lfplane2, "./textures/carkeek_tile-1.jpg");
    cout << "done." << endl << "loading texture3...";
    ofLoadImage(lfplane3, "./textures/carkeek_tile-2.jpg");
    cout << "done." << endl << "loading texture4...";
    ofLoadImage(lfplane4, "./textures/carkeek_tile-3.jpg");

    cout << "done loading textures" << endl;
//    sourceWidth=lfplane.getWidth();
//    sourceHeight=lfplane.getHeight();
//
//    cout << "LF Texture: " << sourceWidth << ", " << sourceHeight << endl;

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


    // setup refocus shader
    //  shader.load("test.vert", "test.frag");
    shader.setupShaderFromFile(GL_FRAGMENT_SHADER, "refocus_tile.frag");
    shader.linkProgram();


    shader.begin();

    // camera images
    shader.setUniformTexture("lftex1", lfplane1, 1);
    shader.setUniformTexture("lftex2", lfplane2, 2);
    shader.setUniformTexture("lftex3", lfplane3, 3);
    shader.setUniformTexture("lftex4", lfplane4, 4);

    shader.setUniform2f("resolution", subwidth, subheight);
    shader.setUniform2i("subimages", xsubimages, ysubimages);

    shader.setUniformTexture("campos_tex", campos_tex, 5);
    shader.end();


//        GLint maxTextureSize;
//        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
//        std::cout <<"Max texture size: " << maxTextureSize << std::endl;

    //        GLint v_maj;
    //    glGetIntegerv(GL_MAJOR_VERSION, &v_maj);
    //        std::cout <<"gl major version: " << v_maj << std::endl;

}

//--------------------------------------------------------------
void ofApp::keyPressed(int key){
    //    cout << bShowThumbnail << " " << bHideCursor << " " << bDebug << endl;
    if(key=='f')
        ofToggleFullscreen();
    if(key=='b') {
        // zoom
        zoom = ofMap(mouseX, 0, ofGetWindowWidth(), 1.0, 0.01);
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

}


void ofApp::process_OSC(ofxOscMessage m) {

    if( m.getAddress() == "/lf/focus" ){
        synScale = m.getArgAsFloat(0);
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
