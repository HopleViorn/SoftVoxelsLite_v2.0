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

layout(location = 0) out vec4 data0;
layout(location = 1) out vec4 data1;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/shadowconst.glsl"

#define gSHADOW

in vec2 uv;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

void main() {
    data0           = clamp16F(texture(shadowcolor0, uv));
    data1           = clamp16F(texture(shadowcolor1, uv));

    ivec2 voxelID       = unpack2x8I(data0.z);

    data0.a             = pack4x4(vec4(float(voxelID.y > 0), 0, 0, 0));
}