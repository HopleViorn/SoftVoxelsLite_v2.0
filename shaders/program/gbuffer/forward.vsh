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

out vec2 uv;
out vec2 lightmapUV;

flat out vec3 vertexNormal;
out vec3 ScenePosition;

out vec4 tint;

uniform vec2 taaOffset;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

attribute vec4 mc_midTexCoord;

#ifdef gTERRAIN
    flat out int matID;

    uniform vec3 cameraPosition;

    attribute vec2 mc_Entity;

    #ifdef windEffectsEnabled
    #include "/lib/vertex/wind.glsl"
    #endif
#endif

#ifdef gTEXTURED
    #ifdef normalmapEnabled
        flat out mat3 tbn;

        attribute vec4 at_tangent;
    #endif
#endif

vec3 blackbody(float temperature){
    vec4 vx = vec4(-0.2661239e9, -0.2343580e6, 0.8776956e3, 0.179910);
    vec4 vy = vec4(-1.1063814, -1.34811020, 2.18555832, -0.20219683);
    float it = rcp(temperature);
    float it2= sqr(it);
    float x = dot(vx, vec4(it * it2, it2, it, 1.0));
    float x2 = sqr(x);
    float y = dot(vy,vec4(x * x2, x2, x, 1.0));
    float z = 1.0 - x - y;
    
    vec3 AP1 = vec3(x * rcp(y), 1.0, z * rcp(y)) * CT_XYZ_AP1;
    return max(AP1, 0.0);
}


#if DIM == 1
#include "/lib/atmos/colorsEnd.glsl"
flat out vec3 directColor;
#elif DIM == -1
#include "/lib/atmos/colorsNether.glsl"
#else
#include "/lib/atmos/colorsDefault.glsl"
flat out vec3 directColor;
#endif

out vec3 shadowPosition;

uniform float sunAngle, lightFlip;

uniform vec3 lightDir;

#if (defined gTRANSLUCENT && defined gTERRAIN)

out float viewDist;
out vec3 worldPos;

#endif

void main() {
    uv          = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightmapUV  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    lightmapUV.x = linStep(lightmapUV.x, rcp(24.0), 1.0);
    lightmapUV.y = linStep(lightmapUV.y, rcp(16.0), 1.0);

    tint        = gl_Color;

    gl_Position = gl_ModelViewMatrix * gl_Vertex;

    vec3 viewNormal     = normalize(gl_NormalMatrix * gl_Normal);

    vertexNormal        = mat3(gbufferModelViewInverse) * viewNormal;

    vec3 scenePosition  = transMAD(gbufferModelViewInverse, gl_Position.xyz);
    ScenePosition = scenePosition;

    #if (defined gTRANSLUCENT && defined gTERRAIN)
        worldPos    = scenePosition + cameraPosition;
    #endif

    #ifdef gTEXTURED
        #ifdef normalmapEnabled
            vec3 tangent    = normalize(gl_NormalMatrix * at_tangent.xyz);
            vec3 binormal   = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);

            tangent     = mat3(gbufferModelViewInverse) * tangent;
            binormal    = mat3(gbufferModelViewInverse) * binormal;

            tbn         = mat3(tangent, binormal, vertexNormal);
        #endif
    #endif

    #ifdef gTERRAIN
        int mcEntity    = int(mc_Entity.x);

        #ifndef gTRANSLUCENT
            matID  = 1;

            if (
            mcEntity == 10022 ||
            mcEntity == 10023 ||
            mcEntity == 10024 ||
            mcEntity == 10025 ||
            mcEntity == 10202) matID = 2;

            if (
            mcEntity == 10021) matID = 4;

            if (mcEntity == 10301 ||
            mcEntity == 10002) matID = 5;

            if (mcEntity == 10302) matID = 6;
        #else
            matID   = 101;

            if (mcEntity == 10001) matID = 102;
            else if (mcEntity == 10003) matID = 103;
        #endif

        #ifdef windEffectsEnabled
        gl_Position.xyz = transMAD(gbufferModelViewInverse, gl_Position.xyz);

        bool windLod    = length(gl_Position.xz) < 64.0;

        if (windLod) {
            bool topVertex      = (gl_MultiTexCoord0.y < mc_midTexCoord.y);

            float windStrength  = sqr(lightmapUV.y) * 0.9 + 0.1;

            vec3 worldPos       = gl_Position.xyz + cameraPosition;

            if (mcEntity == 10021
            || (mcEntity == 10022 && topVertex)
            || (mcEntity == 10023 && topVertex)
             || mcEntity == 10024) {

                vec2 windOffset = vertexWindEffect(worldPos, 0.18, 1.0) * windStrength;

                if (mcEntity == 10021) gl_Position.xyz += windOffset.xyy * 0.4;
                else if (mcEntity == 10023
                        || (mcEntity == 10024 && !topVertex)) gl_Position.xz += windOffset * 0.5;
                else gl_Position.xz += windOffset;
            }
        }

        gl_Position.xyz = transMAD(gbufferModelView, gl_Position.xyz);
        #endif
        
    #endif

    gl_Position         = gl_ProjectionMatrix * gl_Position;

    #ifdef taaEnabled
        gl_Position.xy += taaOffset * (gl_Position.w / ResolutionScale);
    #endif
        
    VertexDownscaling(gl_Position);

    getColorPalette();

    #ifndef DIM
    directColor         = (sunAngle < 0.5 ? colorPalette[0] : colorPalette[1]) * lightFlip;
    #else
    #if DIM != -1
    directColor         = colorPalette[0];
    #endif
    #endif
}