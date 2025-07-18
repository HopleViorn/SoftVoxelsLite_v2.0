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

#include "/lib/head.glsl"
uniform vec2 viewSize;
#define VERTEX_STAGE
#include "/lib/downscaleTransform.glsl"

out vec2 coord;

out vec4 tint;

uniform vec2 taaOffset;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

void main() {
    coord       = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    vec4 pos    = gl_Vertex;
        pos     = transMAD(gl_ModelViewMatrix, pos.xyz).xyzz;

        tint    = gl_Color;

        pos     = pos.xyzz * diag4(gl_ProjectionMatrix) + vec4(0.0, 0.0, gl_ProjectionMatrix[3].z, 0.0);

    #ifdef taaEnabled
        pos.xy += taaOffset * (pos.w / ResolutionScale);
    #endif
        
    gl_Position = pos;
    VertexDownscaling(gl_Position);
}