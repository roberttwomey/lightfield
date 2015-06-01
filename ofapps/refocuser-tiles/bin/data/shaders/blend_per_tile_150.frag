#version 150

// refocused textures
uniform sampler2DRect refocustex[16];

uniform int numtextures;

out vec4 fragColor;

const float zero_ish = 0.0000001;

void main (void){
    vec4 color = vec4(0, 0, 0, 0);
    int counter = 0;

//    for(int i=0; i < numtextures; i++)
//        color += texture2DRect(refocustex[i], gl_FragCoord.xy);

    for(int i=0; i < numtextures; i++) {
        vec4 thiscolor = texture2DRect(refocustex[i], gl_FragCoord.xy);

        if(all(greaterThan(thiscolor, vec4(zero_ish)))) {
            counter ++;
            color += thiscolor;
        }

        // no change in performance with the following
//        float nz = step(0.0, length(thiscolor));
//        counter += int(nz);
//        color += nz * thiscolor;

    }

    fragColor = color / counter;

//   fragColor = texture2DRect(refocustex[0], gl_FragCoord.xy);
}

