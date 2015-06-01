#version 150

// this tile of lightfield data
uniform sampler2DRect lftex;

// offset from large virtual texture (atlas) to this tile
uniform vec2 tilepixoffset;

uniform vec2 resolution;
uniform ivec2 subimages;

uniform ivec2 subimgstart;

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

void main (void){
    vec2 size = textureSize(lftex);

    // keep zoom centered around middle of texture
    vec2 halfres = 0.5 * resolution;
    vec2 pixelpos = (gl_FragCoord.xy - halfres) * zoom - roll + halfres;

    vec4 color = vec4(0,0,0,0);

    // aperture center, used to keep refocused image centered
    vec2 ap_center = 0.5 * ap_size + ap_loc;

    int count = 0;

//    // only iterate over subimages that are on this tile
//    ivec2 start = ivec2(max(subimgstart, ap_loc));
//    ivec2 end = ivec2(min(subimgstart + subimages, ap_loc + ap_size));
//
//    for (int x=start.x; x <end.x; x++){
//        for (int y=start.y; y<end.y; y++) {
//
    // grab color from each subimage in arrayed texture
    for (int x=ap_loc.x; x <(ap_loc.x+ap_size.x); x++){
        for (int y=ap_loc.y; y<(ap_loc.y+ap_size.y); y++) {

            // resolution should be a float
            vec2 subimg_corner = vec2(x, y) * resolution; //vec2(float(x)*resolution.x, float(y)*resolution.y);
            vec2 cam_num = vec2(x, y);

            // keep refocused image centered, offset by camera position minus aperture center
            vec2 offset = texture2DRect(campos_tex, cam_num).xy - texture2DRect(campos_tex, ap_center).xy;
            vec2 shift = fscale * offset;

            // position in large virtual texture (atlas) composed of these tiles
            vec2 atlaspos = subimg_corner + pixelpos - shift;

            // position on this tile
            vec2 thispos = atlaspos - tilepixoffset;

            // debugging positions, etc.
//            color += vec4(subimg_corner / (resolution * subimages), 0.0, 1.0); // check subimage corners
//            color += vec4(atlaspos / (resolution * subimages), 0.0, 1.0); // check atlas position
//            color += vec4(tilepixoffset / (halfres * subimages), 0.0, 1.0); // check that tilepixoffset is working
//            color += vec4(tilepixoffset / vec2(14560, 16380), 0.0, 1.0); // check that tilepixoffset is working
//            color += vec4(pos / (resolution * subimages), 0.0, 1.0); // check tile texture position

            // zero out color if we are out of bounds for the current tile
            vec2 minedge = step(vec2(0.0), thispos);//pos-tilepixoffset);//step(tilepixoffset, pos);
            float minmask = minedge.x * minedge.y;
            vec2 maxedge = vec2(1.0) - step(size, thispos);//pos-tilepixoffset);//, pos - tilepixoffset);
            float maxmask = maxedge.x * maxedge.y;// * uppermask.x * uppermask.y;
            float mask = minmask * maxmask;

            // debugging
//            color += vec4(minedge, 0.0, 1.0); // check lower edge mask
//            color += vec4(maxedge, 0.0, 1.0); // check lower edge mask

//            color += vec4(vec3(minmask), 1.0); // check lower edge mask
//            color += vec4(vec3(maxmask), 1.0); // check lower edge mask

//            color += vec4(vec3(mask), 1.0);// check lower edge mask

            count += int(mask);

            color += vec4(mask * texture2DRect(lftex, thispos));//pos - tilepixoffset));
        }
    }

    color = color / float(count);//ap_size.x*ap_size.y);
    fragColor = color;
}

