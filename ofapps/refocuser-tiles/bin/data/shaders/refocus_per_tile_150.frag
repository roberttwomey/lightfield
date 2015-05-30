#version 150

// this tile of lightfield data
uniform sampler2DRect lftex;

// offset from large virtual texture (atlas) to this tile
uniform vec2 tilepixoffset;

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

void main (void){
    vec2 size = textureSize(lftex);

    // keep zoom centered around middle of texture
    vec2 halfres = 0.5 * resolution;
    vec2 pixelpos = (gl_FragCoord.xy - halfres) * zoom - roll + halfres;

    vec4 color = vec4(0,0,0,0);

    // aperture center, used to keep refocused image centered
    vec2 ap_center = 0.5 * ap_size + ap_loc;

    int count = 0;

    // grab color from each subimage in arrayed texture
    for (int x=ap_loc.x; x <(ap_loc.x+ap_size.x); x++){
        for (int y=ap_loc.y; y<(ap_loc.y+ap_size.y); y++) {

            // resolution should be a float
            vec2 subimg_corner = vec2(float(x)*resolution.x, float(y)*resolution.y);
            vec2 cam_num = vec2(x, y);

            // keep refocused image centered, offset by camera position minus aperture center
            vec2 offset = texture2DRect(campos_tex, cam_num).xy - texture2DRect(campos_tex, ap_center).xy;
            vec2 shift = fscale * offset;

            // position in large virtual texture (atlas) composed of these tiles
            vec2 atlaspos = subimg_corner + pixelpos - shift;

            // position on this tile
            vec2 pos = atlaspos;

//            color += vec4(subimg_corner / (resolution * subimages), 0.0, 1.0); // check subimage corners
//            color += vec4(atlaspos / (resolution * subimages), 0.0, 1.0); // check atlas position
//            color += vec4(tilepixoffset / (halfres * subimages), 0.0, 1.0); // check that tilepixoffset is working
//            color += vec4(tilepixoffset / vec2(14560, 16380), 0.0, 1.0); // check that tilepixoffset is working
//            color += vec4(pos / (resolution * subimages), 0.0, 1.0); // check tile texture position


            // zero out color if we are out of bounds for the current tile
            vec2 minedge = step(vec2(0.0), pos-tilepixoffset);//step(tilepixoffset, pos);
            float minmask = minedge.x * minedge.y;
            vec2 maxedge = vec2(1.0) - step(size, pos-tilepixoffset);//, pos - tilepixoffset);
            float maxmask = maxedge.x * maxedge.y;// * uppermask.x * uppermask.y;
            float mask = minmask * maxmask;

//            color += vec4(minedge, 0.0, 1.0); // check lower edge mask
//            color += vec4(maxedge, 0.0, 1.0); // check lower edge mask

//            color += vec4(vec3(minmask), 1.0); // check lower edge mask
//            color += vec4(vec3(maxmask), 1.0); // check lower edge mask

//            color += vec4(vec3(mask), 1.0);// check lower edge mask
            if(mask > 0.0)
                count +=1;

            color += vec4(mask * texture2DRect(lftex, pos - tilepixoffset));

//            color += vec4(mask * texture2DRect(lftex, pos - tilepixoffset).rgb, mask);
//            color += mask.xxxx * mask.yyyy * vec4(float(pos.x)/float(size.x), float(pos.y)/float(size.y), 0.0, 1.0);

//            pos = min(pos, size);
//            pos = clamp(pos, tilepixoffset, size+tilepixoffset);//vec2(0.0), size);
            //if(pos.x > 0 && pos.y > 0 && pos.x < textureSize(lftex).x && pos.y < textureSize(lftex).y)
            //    color += texture2DRect(lftex, pos);
//            color += vec4(float(x)/float(subimages.x), float(y)/float(subimages.y), 0.0, 1.0);
        }
    }

    color = color / float(count);//ap_size.x*ap_size.y);
    fragColor = color;
}

