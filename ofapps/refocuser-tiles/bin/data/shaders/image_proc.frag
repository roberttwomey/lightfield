#version 120

// combined desaturation and realtime levels/gamma adjustment
//
// realtime curve / level adjustmen
// from http://wes-uoit-comp-graphics.blogspot.com/2013/04/post-processing-levels-brightness.html
//
// rgb <-> hsv transforms from http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl

uniform sampler2DRect img_tex;

uniform float desaturation;
uniform float minlevelIn;
uniform float maxlevelIn;
uniform float gamma;
uniform float minlevelOut;
uniform float maxlevelOut;
uniform float brightness;
uniform float contrast;

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

// This is another Y'UV transform that can be used, but it doesn't
// accurately transform my source image.  Your images may well fare
// better with it, however, considering they come from a different
// source, and because I'm not sure that my original was converted
// to Y'UV420p with the same RGB->YUV (or YCrCb) conversion as
// yours.
//
// vec4 channels = vec4(yChannel, uChannel, vChannel, 1.0);
// float3x4 conversion = float3x4(1.0,  0.0,      1.13983, -0.569915,
//                                1.0, -0.39465, -0.58060,  0.487625,
//                                1.0,  2.03211,  0.0,     -1.016055);
// float3 rgb = mul(conversion, channels);

// Note: The output cannot fully replicate the original image. This is partly
// because WebGL has limited NPOT (non-power-of-two) texture support and also
// due to sRGB color conversions that occur in WebGL but not in the plugin.

//vec3 rgb2yuv(vec3 c) {
//    // http://src.chromium.org/svn/trunk/o3d/samples/shaders/yuv2rgb-glsl.shader
//
//    // [0,1] to [-.5,.5] as part of the transform.
//    vec4 channels = vec4(c, 1.0);
//
//    mat4 conversion = mat4(1.0,  0.0,    1.402, -0.701,
//                           1.0, -0.344, -0.714,  0.529,
//                           1.0,  1.772,  0.0,   -0.886,
//                           0, 0, 0, 0);
//    vec3 rgb = (channels * conversion).xyz;
//
//    return rgb;
//}

vec3 rgb2yuv(vec3 rgb) {
    vec4 channels = vec4(rgb, 1.0);

    mat4 coeffs = mat4(
        0.299,  0.587,  0.114, 0.000,
        -0.147, -0.289,  0.436, 0.000,
        0.615, -0.515, -0.100, 0.000,
        0.000,  0.000,  0.000, 0.000
    );

    return (channels * coeffs).xyz;
}

vec3 yuv2rgb(vec3 yuv) {
    vec4 channels = vec4(yuv, 1.0);

    mat4 coeffs = mat4(
                   1.000,  0.000,  1.140, 0.000,
                   1.000, -0.395, -0.581, 0.000,
                   1.000,  2.032,  0.000, 0.000,
                   0.000,  0.000,  0.000, 0.000
                   );

    return (channels * coeffs).xyz;
}


void main()
{
    vec3 color = texture2DRect(img_tex,gl_TexCoord[0].st).rgb;


    // rgb -> yuv
//    color = rgb2yuv(color.rgb);

    // 1. levels/gamma for RGB color
    // levels input range
    color = min(max(color - vec3(minlevelIn), vec3(0.0)) / (vec3(maxlevelIn) - vec3(minlevelIn)), vec3(1.0));

    //gamma correction
    color = pow(color, vec3(gamma));

    //levels output range
    color = mix(vec3(minlevelOut), vec3(maxlevelOut), color);

    // yuv -> rgb
//    color = yuv2rgb(color);

//    // 2. levels/gamma for just value range
//    vec3 hsv = rgb2hsv(color.rgb);
//
//    float value = hsv.b;
//
//    //value input range
//    value = min(max(value - float(minlevelIn), float(0.0)) / (float(maxlevelIn) - float(minlevelIn)), float(1.0));
//
//    //gamma correction
//    value = pow(value, float(gamma));
//
//    //levels output range
//    vec3 hsv_desat = vec3(hsv.rg, mix(float(minlevelOut), float(maxlevelOut), value));


    // 3. percent desaturation for HSV color

    vec3 hsv = rgb2hsv(color.rgb);
    vec3 hsv_desat = hsv * vec3(1.0, 1.0-desaturation, 1.0);
    color = hsv2rgb(hsv_desat);

//    // 4. YUV desaturation
//    vec3 yuv = rgb2yuv(color.rgb);
//    vec3 yuv_desat = yuv * vec3(1.0-desat_val, 1.0-brightness, 1.0-contrast);
//    color = yuv2rgb(yuv_desat);

    // 4. Brightness and Contrast
//
//    vec3 colorContrasted = (color) * contrast;
//    vec3 bright = colorContrasted + vec3(brightness);
//    color = bright;

    gl_FragColor = vec4(color, 1.0);
}
