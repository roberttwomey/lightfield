#version 120
//#extension GL_ARB_texture_rectangle : enable

// realtime desaturate of rgb color sample
//
// rgb <-> hsv transforms from http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl

uniform sampler2DRect img_tex;

uniform float desat_val;


vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);

//    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
//    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
    vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}


vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


void main (void){
    vec2 pixelpos = gl_TexCoord[0].st;
    
    vec4 color = texture2DRect(img_tex, pixelpos);
    
    vec3 hsv = rgb2hsv(color.rgb);
    
    vec3 hsv_desat = hsv * vec3(1.0, 1.0-desat_val, 1.0);

    vec3 color_desat = hsv2rgb(hsv_desat);
    
    gl_FragColor = vec4(color_desat, 1.0);
}

