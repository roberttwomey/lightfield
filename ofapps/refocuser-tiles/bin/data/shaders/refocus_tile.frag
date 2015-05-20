#version 120
//#extension GL_ARB_texture_rectangle : enable

// lightfield data
uniform sampler2DRect lftex1;
uniform sampler2DRect lftex2;
uniform sampler2DRect lftex3;
uniform sampler2DRect lftex4;

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

//uniform vec2 cam_positions[600];

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

            int texpos = int(x < halfx) + 2 * int(y < halfy);

            if(x < halfx) {
                if(y < halfy) {
                    color += texture2DRect(lftex1, pos);

                } else {
                    color += texture2DRect(lftex3, pos - vec2(0.0, float(halfy) * resolution.y));
                }
            } else {
                if(y < halfy) {
                    color += texture2DRect(lftex2, pos - vec2(float(halfx) * resolution.x, 0.0));
                } else {
                    color += texture2DRect(lftex4, pos - vec2(float(halfx) * resolution.x, float(halfy) * resolution.y));
                }
            }
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    gl_FragColor = color;
}

