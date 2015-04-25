#include "ofApp.h"

#define STRINGIFY(A) #A


void ofApp::loadXMLSettings() {
    ofxXmlSettings xml;
    xml.loadFile("textures/settings_tivon1.xml");
    
    // lightfield data //
    lfimage_filename = xml.getValue("texturefile", "test.jpg");
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
    
    // debug information (text, mouse, thumbnail) //
    bDrawThumbnail = xml.getValue("drawthunbnail", 0) > 0;
    bHideCursor = xml.getValue("hidecursor", 0) > 0;
    bDebug = xml.getValue("debug", 0) > 0;
}

void ofApp::loadLFImage() {
    lfplane.loadImage(lfimage_filename);
    
    sourceWidth=lfplane.getWidth();
    sourceHeight=lfplane.getHeight();
    
    cout << "IMAGE WIDTHS " << sourceWidth << ", " << sourceHeight << endl;

}


void ofApp::graphicsSetup() {
    
    fbo.allocate(subwidth,subheight);
    maskFbo.allocate(subwidth,subheight);
    
    string shaderProgram = STRINGIFY(
                                     uniform sampler2DRect lfplane;
                                     uniform sampler2DRect lfplane2;
                                     uniform sampler2DRect maskTex;
                                     
                                     uniform float xres;
                                     uniform float yres;
                                     uniform int xcount;
                                     uniform int ycount;
                                     uniform int xstart;
                                     uniform int ystart;
                                     uniform float scale;
                                     uniform float offset;
                                     uniform int count;
                                     
                                     void main (void){
                                         vec2 pos = gl_TexCoord[0].st;
                                         
                                         vec4 mask = texture2DRect(maskTex, pos);
                                         
                                         vec4 color = vec4(0,0,0,0);
                                         float halfxcount = float(xcount) / 2.0;
                                         float halfycount = float(ycount) / 2.0;
                                         for (int x=xstart; x<xstart+xcount; x++){		// For each microimage in
                                             for (int y=ystart; y<ystart+ycount; y++) {
                                                 
                                                 //                                                 vec2 subpos = pos + vec2(float(x)*xres, float(y)*yres) + vec2(scale * 4.0, scale * -4.0);
                                                 vec2 subpos = pos + vec2(float(x)*xres, float(y)*yres);
                                                 
                                                 color += texture2DRect(lfplane, subpos+vec2( (1.0+(offset/xres)) * scale*(float(x) - halfxcount), (1.0+(offset/yres))*scale*(float(y)-halfycount)));
                                                 
                                                 // 0.562
                                                 //color += texture2DRect(textures[i], pos+vec2(scale*float(i), 0)) * weight;
                                             }
                                         }
                                         
                                         //color = (rTxt + gTxt + bTxt) / 3.0;
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
    
    shader.begin();
    
    shader.setUniformTexture("lfplane", lfplane, 1);
    
    shader.end();
    
    GLint maxTextureSize;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    std::cout <<"Max texture size: " << maxTextureSize << std::endl;
    
}
//--------------------------------------------------------------
void ofApp::setup(){

    // OSC
    // listen on the given port
    cout << "listening for osc messages on port " << PORT << "\n";
    receiver.setup(PORT);
    
    
    ofEnableAlphaBlending();
    
    loadXMLSettings();
    
    loadLFImage();

    graphicsSetup();
}

//--------------------------------------------------------------
void ofApp::update(){
    
    // This just
    maskFbo.begin();
    ofClear(255, 0, 0,255);
    //    multimaskImg.draw( mouseX-multimaskImg.getWidth()*0.5, 0 );
    maskFbo.end();
    
    // MULTITEXTURE MIXING FBO

    fbo.begin();
    ofClear(0, 0, 0,255);
    shader.begin();
    
//    shader.setUniformTexture("lfplane", lfplane, 1);
    
    shader.setUniform1f("scale", synScale);
    shader.setUniform1i("xstart", xstart);
    shader.setUniform1i("ystart", ystart);
    shader.setUniform1i("xcount", xcount);//lfstack.size());
    shader.setUniform1i("ycount", ycount);
    shader.setUniform1f("xres", subwidth);//562);
    shader.setUniform1f("yres", subheight);//316);
    shader.setUniform1f("offset", 0.0);
    
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
        
    };
    // ~~~~ end OSC ~~~~
    
}

//--------------------------------------------------------------
void ofApp::draw(){
    ofBackground(ofColor::black);
    
    // thumbnail size
    float tWidth = 160;//320;
    float tHeight = 90;//180;
    
    // fused image size
    float height = ofGetWindowHeight();
    float width = height*(sourceWidth/sourceHeight);
    
    ofSetColor(255);
    
    // draw fused image
    fbo.draw(0, 0, width, height);

    // draw thumbnail with indicator
    if(bDrawThumbnail) {
        ofSetColor(255);
        lfplane.draw(5,5,tWidth,tHeight);
        ofSetColor(255, 0, 0);
        ofNoFill();
        float xunit = tWidth/xsubimages;//29.;
        float yunit = tHeight/ysubimages;//20.0;
        ofRect(5+xstart*xunit, 5+ystart*yunit, xcount*xunit, ycount*yunit);
    }
    
    if(bDebug) {
        ofSetColor(255);
        ofDrawBitmapString(ofToString(synScale), 10, ofGetHeight() - 10);
    }
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key){
    if(key=='f')
        ofToggleFullscreen();
    if(key=='z') {
        xstart = ofMap(mouseX, 0, ofGetWindowWidth(), 0, xsubimages-xcount+1);
        ystart = ofMap(mouseY, 0, ofGetWindowHeight(), 0, ysubimages-ycount+1);
    }
    if(key=='x') {
        xcount = ofMap(mouseX, 0, ofGetWindowWidth(), 0, xsubimages);
        ycount = ofMap(mouseY, 0, ofGetWindowHeight(), 0, ysubimages);
        if(xcount+xstart > xsubimages)
            xstart = xsubimages - xcount;
        if(ycount + ystart > ysubimages)
            ystart = ysubimages - ycount;
    }
    if(key == 'c')
        synScale = ofMap(mouseX, 0, ofGetWindowWidth(), minScale, maxScale);//, -2.5);
    if(key == 't')
        bDrawThumbnail = !bDrawThumbnail;
    if(key == 'm') {
        bHideCursor = !bHideCursor;
        if (bHideCursor) {
            ofHideCursor();
        } else {
            ofShowCursor();
        };
    }
    if(key == 'd')
        bDebug = !bDebug;
    
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