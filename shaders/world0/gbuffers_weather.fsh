#version 430 compatibility

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

/* RENDERTARGETS: 15 */
layout(location = 0) out vec4 aux2;

#include "/lib/head.glsl"

in vec2 coord;

in vec4 tint;

uniform sampler2D gcolor;

void main() {
    vec4 sceneColor   = texture(gcolor, coord * vec2(3.0, 1.4));
        sceneColor.a *= tint.a;
    if (sceneColor.a < 0.3) discard;

    aux2 = vec4(1.0, 1.0, 0.0, 1.0);
}