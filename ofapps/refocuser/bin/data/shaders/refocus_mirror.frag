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
    vec2 pixelpos = (gl_TexCoord[0].st - roll) * zoom;
    vec4 color = vec4(0,0,0,0);

    // grab color from each subimage in arrayed texture
    for (int x=ap_loc.x; x <(ap_loc.x+ap_size.x); x++){
        for (int y=ap_loc.y; y<(ap_loc.y+ap_size.y); y++) {
            vec2 subimg_corner = vec2(float(x)*resolution.x, float(y)*resolution.y);
            vec2 cam_num = vec2(x, y);
//            vec2 subimg_corner = texture2DRect(subimg_corner_tex, cam_num).xy;
            vec2 offset = texture2DRect(campos_tex, cam_num).xy;
            vec2 shift = fscale * offset;

            vec2 poffset = resolution - abs(resolution - (mod(pixelpos - shift, resolution * 2)));
            
            color += texture2DRect(lftex, subimg_corner +poffset);//+ pixelpos - shift);
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    gl_FragColor = color;
}

