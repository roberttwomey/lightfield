#version 150

// refocused textures
uniform sampler2DRect refocustex[16]; // 16 is the max number of individual textures

uniform int numtextures;

out vec4 fragColor;

#define PRECISION 0.000001

void main (void){
    vec4 color = vec4(0, 0, 0, 0);
    int counter = 0;

    // TESTING:
    // vec4 thiscolor = texture2DRect(refocustex[1], gl_FragCoord.xy);
    // color += vec4(thiscolor.rgb, 0.0);

    for(int i=0; i < numtextures; i++) {
        
        // color = vec4(1.0, 1.0, 0.0, 1.0); // uniformely yellow
        // colors are weighted according to number of visible subimages on per-tile basis
        vec4 thiscolor = texture2DRect(refocustex[i], gl_FragCoord.xy);
        color += vec4(thiscolor.rgb, 1.0);
    }

    color = texture2DRect(refocustex[0], gl_FragCoord.xy);
    // multi-tile blend
    fragColor = vec4(color.rgb, 1.0);// / counter;

}




//     for(int i=0; i < numtextures; i++) {
//         vec4 thiscolor = texture2DRect(refocustex[i], gl_FragCoord.xy);
// //
//         // colors are weighted according to number of visible subimages on per-tile basis
//         color += vec4(thiscolor.rgb, 0.0);

//        if(thiscolor.a > 0.0) {
//            counter ++;
//            color += vec4(thiscolor.rgb, 1.0);
//        }

//
//        float mask = step(0.0, thiscolor.a - PRECISION);
//
//        counter += int(mask);
////        color += mask * vec4(thiscolor.rgb, 1.0);
//        color += thiscolor.a * vec4(thiscolor.rgb, 1.0);

//        color += thiscolor;//vec4(thiscolor.rgb, 1.0);
//        if(all(greaterThan(thiscolor, vec4(zero_ish)))) {
//            counter ++;
//            color += thiscolor;
//        }

        // no change in performance with the following
//        float nz = step(0.0, length(thiscolor));
//        counter += int(nz);
//        color += nz * thiscolor;

    // }
    // debugging
   // fragColor = vec4(vec3(float(counter) * 0.25), 1.0);
//    fragColor = vec4(color.aaa * 0.25, 1.0);
//    fragColor = vec4(vec3(float(counter)), 1.0);
