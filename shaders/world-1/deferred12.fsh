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


/* RENDERTARGETS: 0,3,5 */
layout(location = 0) out vec4 sceneColor;
layout(location = 1) out vec4 lightingData;
layout(location = 2) out vec4 translucentColor;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

flat in mat4x3 colorPalette;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex7;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform float lightFlip;
uniform float sunAngle;
uniform float near, far;

uniform vec2 pixelSize, viewSize;

#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"

/* ------ ATROUS ------ */

#include "/lib/offset/gauss.glsl"

#define atrousDepthTreshold 0.001
#define atrousDepthOffset 0.25
#define atrousDepthExp 2.0

#define atrousNormalExponent 16

/*
luma exp: big = sharper     now smol = sharp
luma offset: big = moar min blur
*/

#define atrousLumaExp 4.0
#define atrousLumaOffset 8.0

ivec2 clampTexelPos(ivec2 pos) {
    return clamp(pos, ivec2(0.0), ivec2(viewSize));
}

vec2 computeVariance(sampler2D tex, ivec2 pos) {
    float sumMsqr   = 0.0;
    float sumMean   = 0.0;

    for (int i = 0; i<9; i++) {
        ivec2 deltaPos     = kernelO_3x3[i];

        vec3 col    = texelFetch(tex, clampTexelPos(pos + deltaPos), 0).rgb;
        float lum   = getLuma(col);

        sumMsqr    += sqr(lum);
        sumMean    += lum;
    }
    sumMsqr  /= 9.0;
    sumMean  /= 9.0;

    return vec2(abs(sumMsqr - sqr(sumMean)) * rcp(max(sumMean, 1e-20)), sumMean);
}

vec4 atrousSVGF(sampler2D tex, sampler2D gData, vec2 uv, vec3 sceneNormal, float centerDepth) {
    ivec2 pos           = ivec2(uv * viewSize * indirectResScale);

    vec4 centerData     = vec4(sceneNormal, sqrt(depthLinear(centerDepth)) * far);

    vec4 centerColor    = texelFetch(tex, pos, 0);
    float centerLuma    = getLuma(centerColor.rgb);

    //return centerColor;

    vec2 variance       = computeVariance(tex, pos);

    float sigmaL        = rcp(1.0 + atrousLumaExp * variance.x);
    float maxLumDelta   = pi;

    float totalWeight   = 1e-2;
    vec4 total          = centerColor * totalWeight;

    for (int i = 0; i<25; i++) {
        ivec2 deltaPos      = kernelO_5x5[i];
        //if (deltaPos.x == 0 && deltaPos.y == 0) continue;

        ivec2 samplePos     = pos + deltaPos;

        bool valid          = all(greaterThanEqual(samplePos, ivec2(0))) && all(lessThan(samplePos, ivec2(viewSize)));

        if (!valid) continue;

        vec4 currentData    = texelFetch(gData, clampTexelPos(samplePos), 0);
            currentData.xyz = currentData.xyz * 2.0 - 1.0;
            currentData.w   = (currentData.w) * far;

        float depthDelta    = abs(currentData.w - centerData.w) * atrousDepthExp;

        float weight        = pow(max(0.0, dot(currentData.xyz, centerData.xyz)), atrousNormalExponent);

        //if (weight < 1e-20) continue;

        vec4 currentColor   = texelFetch(tex, clampTexelPos(samplePos), 0);
        float currentLuma   = getLuma(currentColor.rgb);

        //float lumaDelta     = abs(centerLuma - currentLuma) / clamp(variance.y, 1e-2, 2e4);

            weight         *= exp(-depthDelta);

        //accumulate stuff
        total       += currentColor * weight;

        totalWeight += weight;
    }

    //compensate for total sampling weight
    total *= rcp(max(totalWeight, 1e-25));

    return total;
}


vec4 packReflectionAux(vec3 directLight, vec3 albedo) {
    vec4 lightRGBE  = encodeRGBE8(directLight);
    vec4 albedoRGBE = encodeRGBE8(albedo);

    return vec4(pack2x8(lightRGBE.xy),
                pack2x8(lightRGBE.zw),
                pack2x8(albedoRGBE.xy),
                pack2x8(albedoRGBE.zw));
}

void main() {
    sceneColor          = stex(colortex0);
    float sceneDepth    = stex(depthtex0).x;
    vec3 albedo         = vec3(1.0);
    vec3 directLight    = vec3(1.0);
    //indirectLuma        = 0.0;

    if (landMask(sceneDepth)) {
        vec4 tex1       = stex(colortex1);
        vec3 sceneNormal = decodeNormal(tex1.xy);

        bool hand   = sceneDepth < stex(depthtex2).x;

            albedo          = sceneColor.rgb;
            //directLight     = stex(colortex7).rgb * 2.0;

        
        vec4 indirectLight  = texture(colortex5, uv * indirectResScale);

        #if indirectResReduction > 1
            indirectLight   = atrousSVGF(colortex5, colortex3, uv, sceneNormal, sceneDepth);
        #endif
        
        //vec3 indirectLight  = colorPalette[2] * cube(sceneColor.a);

        #ifdef textureAoEnabled
            indirectLight  *= saturate(stex(colortex2).w);
        #endif

        vec3 emission       = sqr(normalizeSafe(albedo)) * sceneColor.a * sqrt2;
        if (hand) emission /= pi4;
        

        sceneColor.rgb     *= indirectLight.rgb + emission;
        //sceneColor.rgb      = directLight + indirectLight;

        #if DEBUG_VIEW == 1
            sceneColor.rgb      = indirectLight.rgb + emission;
        #endif

        #if DEBUG_VIEW == 2
            sceneColor.rgb      = indirectLight.rgb;
        #endif

        #if DEBUG_VIEW == 3
            sceneColor.rgb      = albedo.rgb;
        #endif

        //sceneColor.rgb = vec3(indirectLight.a);
        //indirectLuma        = avgOf(indirectLight);
    }

    sceneColor          = drawbufferClamp(sceneColor);
    translucentColor    = vec4(0.0);
    lightingData        = packReflectionAux(directLight, albedo);
}