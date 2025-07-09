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

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 sceneColor;

#include "/lib/head.glsl"

in vec2 uv;

flat in mat3 colorPalette;

uniform sampler2D colortex4;

uniform sampler2D noisetex;

uniform int worldTime;

uniform vec2 taaOffset;

void main() {
    sceneColor      = colorPalette[1];

    //sceneColor  = texture(colortex3, uv).rgb;
}