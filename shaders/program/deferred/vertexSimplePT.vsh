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

#include "/settings.glsl"

uniform vec2 viewSize;
#define VERTEX_STAGE
#include "/lib/downscaleTransform.glsl"

#ifdef SPEC
    const float reflectionResScale = sqrt(1.0 / reflectionResReduction) * 0.9 + 0.1;

    out vec2 uv;

    void main() {
        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
        gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * reflectionResScale) * 2.0 - 1.0;

        uv = gl_MultiTexCoord0.xy * reflectionResScale;
        #ifndef FULLRES_PASS
        VertexDownscaling(gl_Position, uv);
        #endif
    }
#else
    const float indirectResScale = sqrt(1.0 / indirectResReduction) * 0.8 + 0.2;    //needs padding

    out vec2 uv;

    void main() {
        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
        gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * indirectResScale) * 2.0 - 1.0;

        uv = gl_MultiTexCoord0.xy * indirectResScale;
        #ifndef FULLRES_PASS
        VertexDownscaling(gl_Position, uv);
        #endif
    }
#endif