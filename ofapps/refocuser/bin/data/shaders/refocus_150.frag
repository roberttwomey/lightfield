#version 150

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

out vec4 fragColor;

//in vec2 texCoordVarying;


void main (void){
    // doesn't work
    //vec2 pixelpos = (texCoordVarying.st - roll) * zoom;

    vec2 pixelpos = (gl_FragCoord.xy - roll) * zoom;
    vec4 color = vec4(0,0,0,0);

    // grab color from each subimage in arrayed texture
    for (int x=ap_loc.x; x <(ap_loc.x+ap_size.x); x++){
        for (int y=ap_loc.y; y<(ap_loc.y+ap_size.y); y++) {
            vec2 subimg_corner = vec2(float(x)*resolution.x, float(y)*resolution.y);
            vec2 cam_num = vec2(x, y);

            vec2 offset = texture2DRect(campos_tex, cam_num).xy;
            vec2 shift = fscale * offset;

            color += texture2DRect(lftex, subimg_corner + pixelpos - shift);
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    fragColor = color;
}

