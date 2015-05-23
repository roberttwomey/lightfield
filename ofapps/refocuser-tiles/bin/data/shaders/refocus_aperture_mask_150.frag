#version 150

// lightfield data
uniform sampler2DRect lftex[16];

uniform vec2 resolution;
uniform ivec2 subimages;

// refocusing aperture
uniform ivec2 ap_size;
uniform ivec2 ap_loc;

uniform sampler2DRect aperture_mask;

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

vec4 getColor(int i, vec2 pos) {
    int ii = int(i);
    vec4 color;

    if(ii==0) color = texture2DRect(lftex[0], pos);
    if(ii==1) color = texture2DRect(lftex[1], pos);
    if(ii==2) color = texture2DRect(lftex[2], pos);
    if(ii==3) color = texture2DRect(lftex[3], pos);
    if(ii==4) color = texture2DRect(lftex[4], pos);
    if(ii==5) color = texture2DRect(lftex[5], pos);
    if(ii==6) color = texture2DRect(lftex[6], pos);
    if(ii==7) color = texture2DRect(lftex[7], pos);
    if(ii==8) color = texture2DRect(lftex[8], pos);
    if(ii==9) color = texture2DRect(lftex[9], pos);
    if(ii==10) color = texture2DRect(lftex[10], pos);
    if(ii==11) color = texture2DRect(lftex[11], pos);
    if(ii==12) color = texture2DRect(lftex[12], pos);
    if(ii==13) color = texture2DRect(lftex[13], pos);
    if(ii==14) color = texture2DRect(lftex[14], pos);
    if(ii==15) color = texture2DRect(lftex[15], pos);

    return color;

}

void main (void){
    // keep zoom contered around middle of texture
    vec2 halfres = resolution/2;
    vec2 pixelpos = (gl_FragCoord.xy - halfres) * zoom - roll + halfres;

    vec4 color = vec4(0,0,0,0);

    // aperture center, used to keep refocused image centered
    vec2 ap_center = ap_loc + ap_size/2;

    for (int x=0; x < subimages.x; x++) {
        for (int y=0; y< subimages.y; y++) {
            vec2 subimg_corner = vec2(float(x)*resolution.x, float(y)*resolution.y);
            vec2 cam_num = vec2(x, y);

            // keep refocused image centered, offset by camera position minus aperture center
            vec2 offset = texture2DRect(campos_tex, cam_num).xy - texture2DRect(campos_tex, ap_center).xy;
            vec2 shift = fscale * offset;

            vec2 pos = subimg_corner + pixelpos - shift;

            int tilenum = int(texture2DRect(tilenum_tex, cam_num).x);
            vec2 tilepixoffset = texture2DRect(tilepixoffset_tex, cam_num).xy;
            float mask = texture2DRect(aperture_mask, cam_num);
            color += mask * texture2DRect(lftex[tilenum], pos-tilepixoffset);
        }
    }

    color = color / float(ap_size.x*ap_size.y);
    fragColor = color;
}

