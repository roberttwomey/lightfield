#version 120
//#extension GL_ARB_texture_rectangle : enable

uniform sampler2DRect lftex;
uniform sampler2DRect campos_tex;

uniform vec2 resolution;
uniform ivec2 subimages;

// refocusing aperture
uniform ivec2 ap_size;
uniform ivec2 ap_loc;

// refocusing zoom, pixel roll
uniform float fscale;
uniform float zoom;
uniform vec2 pixroll;

// camera_positions
//uniform vec2 cam_positions[600];

uniform int count;

void main (void){
    vec2 roll = pixroll; //vec2(xoffset, yoffset); // pixroll;//
    vec2 pixelpos = (gl_TexCoord[0].st - roll) * zoom;
    vec4 color = vec4(0,0,0,0);

//    const int i=504;
    // grab color from each subimage in arrayed texture
    for (int x=ap_loc.x; x<ap_loc.x+ap_size.x; x++){
        for (int y=ap_loc.y; y<ap_loc.y+ap_size.y; y++) {
            vec2 subimg_corner = vec2(float(x)*resolution.x, float(y)*resolution.y);
            // PROBLEMS:
            // can't use non-const index i in line below
            // can't use value above 504
            vec2 cam_num = vec2(x, y);//float(x)/float(subimages.x), 1.0);//float(y)/float(subimages.y))).xy;
            vec2 offset = texture2DRect(campos_tex, cam_num).xy;
//            vec2 offset = cam_positions[i];
            vec2 shift = fscale * offset;// * offsets[x + (y* xsubimages)];

            color += texture2DRect(lftex, subimg_corner + pixelpos - shift);
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    gl_FragColor = color;
}

