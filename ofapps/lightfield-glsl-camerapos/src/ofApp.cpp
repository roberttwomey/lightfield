#include "ofApp.h"

// make string
#define STRINGIFY(A) #A

// process other macros then make string
#define EXPAND_AND_QUOTE(A) STRINGIFY(A)


//--------------------------------------------------------------
void ofApp::setup(){

    ofEnableAlphaBlending();
    
//    loadXMLSettings("./textures/dark_trees_calib.xml");
    loadXMLSettings("./textures/yellowcliff_sm.xml");
//    loadXMLSettings("./textures/cliffside.xml");
    
    loadLFImage();  

    graphicsSetup();
    
    // initialize refocus shader
    shader.begin();
    
    shader.setUniformTexture("lfplane", lfplane, 1);
    shader.setUniform1f("xres", subwidth);//562);
    shader.setUniform1f("yres", subheight);//316);
    
    int count = xsubimages * ysubimages;
    
    shader.setUniform2fv("offsets", offsets, count);
    shader.setUniform1i("xsubimages", xsubimages);
    shader.setUniform1i("ysubimages", ysubimages);
    
    shader.end();
    
    // OSC - listen on the given port
    cout << "listening for osc messages on port " << port << "\n";
    receiver.setup(port);
}

//--------------------------------------------------------------
void ofApp::update(){
    
    // why is this here?
    maskFbo.begin();
    ofClear(255, 0, 0,255);
    maskFbo.end();
    
    fbo.begin();
    ofClear(0, 0, 0,255);
    
    shader.begin();
    
    shader.setUniform1f("scale", synScale);
    shader.setUniform1i("xstart", xstart);
    shader.setUniform1i("ystart", ystart);
    shader.setUniform1i("xcount", xcount);//lfstack.size());
    shader.setUniform1i("ycount", ycount);
    shader.setUniform1f("xoffset", xoffset);
    shader.setUniform1f("yoffset", yoffset);
    shader.setUniform1f("zoom", zoom);
    
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
        lfplane.draw(5,5,tWidth,tHeight);
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
    
    // cameras
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
    lfplane.loadImage(lfimage_filename);
    
    sourceWidth=lfplane.getWidth();
    sourceHeight=lfplane.getHeight();
    
    cout << "LF Texture: " << sourceWidth << ", " << sourceHeight << endl;
    
}

void ofApp::graphicsSetup() {
    
    fbo.allocate(subwidth,subheight);
    maskFbo.allocate(subwidth,subheight);
    
    string shaderProgram = EXPAND_AND_QUOTE(
                                     uniform sampler2DRect lfplane;
                                     uniform sampler2DRect lfplane2;
                                     
                                     uniform float xres;
                                     uniform float yres;
                                     uniform int xsubimages;
                                     uniform int ysubimages;
                                     uniform int xcount;
                                     uniform int ycount;
                                     uniform int xstart;
                                     uniform int ystart;
                                     uniform float scale;
                                     uniform float zoom;
                                     uniform float xoffset;
                                     uniform float yoffset;
                                     uniform int count;
                                     uniform vec2 offsets[MAX_SUBIMAGES];
                                     
                                     void main (void){
                                         vec2 roll = vec2(xoffset, yoffset);
                                         vec2 pixelpos = (gl_TexCoord[0].st - roll) * zoom;
                                         
                                         vec4 color = vec4(0,0,0,0);
                                         float halfxcount = float(xcount) / 2.0;
                                         float halfycount = float(ycount) / 2.0;
                                         
                                         // grab color from each subimage in arrayed texture
                                         for (int x=xstart; x<xstart+xcount; x++){
                                             for (int y=ystart; y<ystart+ycount; y++) {
                                                 vec2 subimg_corner = vec2(float(x)*xres, float(y)*yres);
                                                 vec2 shift = scale * offsets[x + (y* xsubimages)];
                                                 
                                                 color += texture2DRect(lfplane, subimg_corner + pixelpos - shift);
                                                 
                                                 //                                                 color += texture2DRect(lfplane, subpos + vec2( (1.0 * scale*(float(x) - halfxcount-float(xstart)+0.5)), (1.0*scale*(float(y)-halfycount-float(ystart)+0.5))));
                                                 
                                                 // the old way
                                                 //                                                 color += texture2DRect(lfplane, subpos+vec2( (1.0 * scale*(float(x) - halfxcount)) -xoffset, (1.0*scale*(float(y)-halfycount))-yoffset));
                                                 
                                             }
                                         }
                                         
                                         color = color / float(xcount*ycount);
                                         gl_FragColor = color;
                                     }
                                     );
    
    shader.setupShaderFromSource(GL_FRAGMENT_SHADER, shaderProgram);
    shader.linkProgram();
    
    // LetÇs clear the FBOÇs
    // otherwise it will bring some junk with it from the memory
    fbo.begin();
    ofClear(0,0,0,255);
    fbo.end();
    
    maskFbo.begin();
    ofClear(0,0,0,255);
    maskFbo.end();
    
    //    GLint maxTextureSize;
    //    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    //    std::cout <<"Max texture size: " << maxTextureSize << std::endl;

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
void ofApp::keyReleased(int key){
    
}

//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y ){
    
}

//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button){
    
}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button){
    
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