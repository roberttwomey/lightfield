#version 150

uniform sampler2DRect lfplane;

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

in vec2 texCoordVarying;

out vec4 fragColor;

uniform vec2 camoffsets[200];

void main (void){
    vec2 roll = vec2(xoffset, yoffset);
    vec2 pixelpos = (texCoordVarying.st);// - roll) * zoom;
    vec4 color = vec4(0,0,0,0);
    float halfxcount = float(xcount) / 2.0;
    float halfycount = float(ycount) / 2.0;

    // grab color from each subimage in arrayed texture
    for (int x=xstart; x<xstart+xcount; x++){
        for (int y=ystart; y<ystart+ycount; y++) {
            vec2 subimg_corner = vec2(float(x)*xres, float(y)*yres);
            vec2 shift = scale * camoffsets[x + (y* xsubimages)];

            color += texture2DRect(lfplane, subimg_corner+ pixelpos);// - shift);
        }
    }

    color = color / float(xcount*ycount);
    fragColor = color;
}

