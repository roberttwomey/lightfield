#version 150

// refocused textures
uniform sampler2DRect refocustex[16];

uniform int numtextures;

out vec4 fragColor;

void main (void){
    vec4 color = vec4(0, 0, 0, 0);
    int counter = 0;

    for(int i=0; i < numtextures; i++)
        color += texture2DRect(refocustex[i], gl_FragCoord.xy);
//    for(int i=0; i < numtextures; i++) //{
//        vec4 thiscolor = texture2DRect(refocustex[i], gl_FragCoord.xy);
//        color += thiscolor;
////        if(thiscolor != vec4(0.0)) {
////            counter ++;
////            color += thiscolor;
////        }
//    }
////        color = max(color, texture2DRect(refocustex[i], gl_FragCoord.xy));
//
////    color=vec4(gl_FragCoord.xy/1400.0, 0, 1); // test that shader/coords are outputting
////    color = texture2DRect(refocustex[0], gl_FragCoord.xy);
////    color = texture2DRect(testtex, gl_FragCoord.xy);
//    fragColor = color / numtextures;//counter;
    fragColor = color;
}

