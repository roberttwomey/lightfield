#version 120
//#extension GL_ARB_texture_rectangle : enable

// lightfield data
uniform sampler2DRect lftex1;
uniform sampler2DRect lftex2;
uniform sampler2DRect lftex3;
uniform sampler2DRect lftex4;
uniform sampler2DRect lftex5;
uniform sampler2DRect lftex6;
uniform sampler2DRect lftex7;
uniform sampler2DRect lftex8;
uniform sampler2DRect lftex9;
uniform sampler2DRect lftex10;
uniform sampler2DRect lftex11;
uniform sampler2DRect lftex12;

uniform vec2 resolution;
uniform ivec2 subimages;

// refocusing aperture
uniform ivec2 ap_size;
uniform ivec2 ap_loc;

// refocusing zoom, pixel roll
uniform float fscale;
uniform float zoom;
uniform vec2 roll;

//uniform int tilenum;

// camera_positions
uniform sampler2DRect campos_tex;

// tile numbers where individual cam images are stored
uniform sampler2DRect tilenum_tex;
uniform sampler2DRect tilepixoffset_tex;


void main (void){
    // keep zoom contered around middle of texture
    vec2 halfres = resolution/2;
    vec2 pixelpos = (gl_TexCoord[0].st - halfres) * zoom - roll + halfres;

    vec4 color = vec4(0,0,0,0);

    int halfx = subimages.x / 2;
    int halfy = subimages.y / 2;

    // aperture center, used to keep refocused image centered
    vec2 ap_center = ap_loc + ap_size/2;

    // grab color from each subimage in arrayed texture
    for (int x=ap_loc.x; x <(ap_loc.x+ap_size.x); x++){
        for (int y=ap_loc.y; y<(ap_loc.y+ap_size.y); y++) {
            vec2 subimg_corner = vec2(float(x)*resolution.x, float(y)*resolution.y);

            vec2 cam_num = vec2(x, y);

            // keep refocused image centered, offset by camera position minus aperture center
            vec2 offset = texture2DRect(campos_tex, cam_num).xy - texture2DRect(campos_tex, ap_center).xy;
            vec2 shift = fscale * offset;

            vec2 pos = subimg_corner + pixelpos - shift;

            int tilenum = int(texture2DRect(tilenum_tex, cam_num).x);
            vec2 tilepixoffset = texture2DRect(tilepixoffset_tex, cam_num).xy;

            if(tilenum ==0)
                color += texture2DRect(lftex1, pos - tilepixoffset);
            if(tilenum ==1)
                color += texture2DRect(lftex2, pos - tilepixoffset);
            if(tilenum ==2)
                color += texture2DRect(lftex3, pos - tilepixoffset);
            if(tilenum ==3)
                color += texture2DRect(lftex4, pos - tilepixoffset);
            if(tilenum ==4)
                color += texture2DRect(lftex5, pos - tilepixoffset);
            if(tilenum ==5)
                color += texture2DRect(lftex6, pos - tilepixoffset);
            if(tilenum ==6)
                color += texture2DRect(lftex7, pos - tilepixoffset);
            if(tilenum ==7)
                color += texture2DRect(lftex8, pos - tilepixoffset);

//            switch(tilenum) {
//                case 0:
//                    color += texture2DRect(lftex1, pos - tilepixoffset);
//                    break;
//                case 1:
//                    color += texture2DRect(lftex2, pos - tilepixoffset);
//                    break;
//                case 2:
//                    color += texture2DRect(lftex3, pos - tilepixoffset);
//                    break;
//                case 3:
//                    color += texture2DRect(lftex4, pos - tilepixoffset);
//                    break;
//                case 4:
//                    color += texture2DRect(lftex5, pos - tilepixoffset);
//                    break;
//                case 5:
//                    color += texture2DRect(lftex6, pos - tilepixoffset);
//                    break;
//                case 6:
//                    color += texture2DRect(lftex7, pos - tilepixoffset);
//                    break;
//                case 7:
//                    color += texture2DRect(lftex8, pos - tilepixoffset);
//                    break;
//            };

//            if(x < halfx) {
//                if(y < halfy) {
//                    color += texture2DRect(lftex1, pos);
//
//                } else {
//                    color += texture2DRect(lftex3, pos - vec2(0.0, float(halfy) * resolution.y));
//                }
//            } else {
//                if(y < halfy) {
//                    color += texture2DRect(lftex2, pos - vec2(float(halfx) * resolution.x, 0.0));
//                } else {
//                    color += texture2DRect(lftex4, pos - vec2(float(halfx) * resolution.x, float(halfy) * resolution.y));
//                }
//            }
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    gl_FragColor = color;
}

