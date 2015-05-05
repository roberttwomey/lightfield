//// fragment shader
//#version 150
//
//// this is how we receive the texture
//uniform sampler2DRect lftex;
//in vec2 texCoordV;
//out vec4 outputColor;
//
//void main()
//{
//     vec2 pos = texCoordV;//gl_TexCoord[0].st;
//
//     vec4 rTxt = texture2DRect(lftex, pos);
////     vec4 gTxt = texture2DRect(tex1, pos);
////     vec4 bTxt = texture2DRect(tex2, pos);
////     vec4 mask = texture2DRect(maskTex, pos);
//
//     vec4 color = rTxt;
//
//     outputColor = color;//texture(rTxt, texCoordV);
//}

#version 120
uniform sampler2DRect lftex;

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
uniform vec2 offsets[600];

void main (void){
    vec2 roll = vec2(xoffset, yoffset);
    vec2 pos = (gl_TexCoord[0].st - roll) * zoom;
    vec4 color = vec4(0,0,0,0);

    // grab color from each subimage in arrayed texture
    for (int x=xstart; x<xstart+xcount; x++){
        for (int y=ystart; y<ystart+ycount; y++) {
            vec2 subimg_corner = vec2(float(x)*xres, float(y)*yres);
            vec2 shift = scale * offsets[x + (y* xsubimages)];

            color += texture2DRect(lftex, subimg_corner + pos - shift);
        }
    }

    color = color / (xcount*ycount);

    gl_FragColor = color ;
}
