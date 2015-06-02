#version 120
//#extension GL_ARB_texture_rectangle : enable

// lightfield data
uniform sampler2DRect lftex;

uniform vec2 resolution;
uniform ivec2 subimages;

// refocusing aperture
uniform ivec2 ap_size;
uniform ivec2 ap_loc;

// refocusing zoom, pixel roll
uniform float fscale;
uniform float zoom;
uniform vec2 roll;

// camera_positions
uniform sampler2DRect campos_tex;
//uniform sampler2DRect subimg_corner_tex;


void main (void){
    // keep zoom contered around middle of texture
    vec2 halfres = resolution/2;
    vec2 pixelpos = (gl_TexCoord[0].st - halfres) * zoom - roll + halfres;
    
    vec4 color = vec4(0,0,0,0);

    // aperture center, used to keep refocused image centered
    vec2 ap_center = ap_loc + ap_size/2;
    
    // grab color from each subimage in current refocusing window
    for (int x=ap_loc.x; x <(ap_loc.x+ap_size.x); x++){
        for (int y=ap_loc.y; y<(ap_loc.y+ap_size.y); y++) {
            vec2 subimg_corner = vec2(float(x)*resolution.x, float(y)*resolution.y);
            vec2 cam_num = vec2(x, y);
//            vec2 subimg_corner = texture2DRect(subimg_corner_tex, cam_num).xy;

            // keep refocused image centered, offset by camera position minus aperture center
            vec2 offset = texture2DRect(campos_tex, cam_num).xy - texture2DRect(campos_tex, ap_center).xy;
            vec2 shift = fscale * offset;

            color += texture2DRect(lftex, subimg_corner + pixelpos - shift);
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    gl_FragColor = color;
}

