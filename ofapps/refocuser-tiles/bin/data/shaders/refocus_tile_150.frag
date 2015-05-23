#version 150

// lightfield data
uniform sampler2DRect lftex[16];

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

out vec4 fragColor;

void main (void){
    // keep zoom contered around middle of texture
    vec2 halfres = 0.5 * resolution;
    vec2 pixelpos = (gl_FragCoord.xy - halfres) * zoom - roll + halfres;

    vec4 color = vec4(0,0,0,0);

    // aperture center, used to keep refocused image centered
    vec2 ap_center = 0.5 * ap_size + ap_loc;

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

            color += texture2DRect(lftex[tilenum], pos-tilepixoffset);
            //color += getColor(tilenum, pos-tilepixoffset);
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    fragColor = color;
}

