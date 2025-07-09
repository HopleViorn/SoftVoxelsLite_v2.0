/*
====================================================================================================

    Copyright (C) 2023 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.com/copyright-license

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/



float ditherBluenoise() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    float noise = texelFetch(noisetex, coord & 255, 0).a;

    #ifdef taaEnabled
        noise   = fract(noise+float(frameCounter)/pi);
    #endif

    return noise;
}

float ditherBluenoiseStatic() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    float noise = texelFetch(noisetex, coord & 255, 0).a;

    return noise;
}