
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

/* RENDERTARGETS: 3,5,14 */
layout(location = 0) out vec4 GBuffer;
layout(location = 1) out vec3 LightColor;
layout(location = 2) out vec3 flatNormals;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

#ifndef DIM
flat in mat4x3 colorPalette;
#define blocklightColor colorPalette[3]
#elif DIM == -1
flat in mat3 colorPalette;
#define blocklightColor colorPalette[2]
#elif DIM == 1
flat in mat3 colorPalette;
#define blocklightColor colorPalette[2]
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex7;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform sampler2D noisetex;

uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform int frameCounter, frame255;

uniform float aspectRatio;
uniform float near, far;
uniform float lightFlip;
uniform float sunAngle;

uniform vec2 skyCaptureResolution;
uniform vec2 pixelSize, viewSize;
uniform vec2 taaOffset;

uniform vec3 upDir, cameraPosition;
uniform vec3 sunDir, moonDir, lightDir, lightDirView;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;


/* ------ includes ------*/
#define FUTIL_MAT16
#define FUTIL_LINDEPTH
#define FUTIL_LIGHTMAP
#include "/lib/fUtil.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

#include "/lib/atmos/project.glsl"

#include "/lib/brdf/fresnel.glsl"
#include "/lib/brdf/hammon.glsl"


/* ------ DITHER ------ */

#define HASHSCALE1 .1031
float hash12(vec2 x) {
    vec3 x3  = fract(vec3(x.xyx) * HASHSCALE1);
        x3  += dot(x3, x3.yzx + 19.19);
    return fract((x3.x + x3.y) * x3.z);
}

#define HASHSCALE3 vec3(.1031, .1030, .0973)
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float ditherHashNoise() {
    float noise     = hash12(gl_FragCoord.xy);
        noise   = fract(noise + (frameCounter * 7.0 * rcp(255.0)) *0);

    return noise;
}
float ditherBluenoise2() {
    ivec2 coord = ivec2(fract(gl_FragCoord.xy/256.0)*256.0);
    float noise = texelFetch(noisetex, coord, 0).a;

        noise   = fract(noise + (frameCounter * 7.0 * rcp(255.0)));

    return noise;
}

vec3 genUnitVector(vec2 p) {
    p.x *= tau; p.y = p.y * 2.0 - 1.0;
    return vec3(sincos(p.x) * sqrt(1.0 - p.y * p.y), p.y);
}
vec3 GenerateCosineVectorSafe(vec3 vector, vec2 xy) {
	// Apparently this is actually this simple.
	// http://www.amietia.com/lambertnotangent.html
	// (cosine lobe around vector = lambertian BRDF)
	// This one deals with ther rare case where cosineVector == (0,0,0)
	// Can just normalize it instead if you are sure that won't be a problem
	vec3 cosineVector = vector + genUnitVector(xy);
	float lenSq = dot(cosineVector, cosineVector);
	return lenSq > 0.0 ? cosineVector * inversesqrt(lenSq) : vector;
}

/* ------ SSPT ------ */
#if 1

vec3 screenspaceRT(vec3 position, vec3 direction, float noise, bool outsideVoxel) {
    const uint maxSteps     = 8;
    float stepSize    = tau / float(maxSteps);
    if (!outsideVoxel) {
        stepSize  = pi / float(maxSteps);
    }

    vec3 stepVector         = direction * stepSize;

    vec3 endPosition        = position + stepVector * maxSteps;
    vec3 endScreenPosition  = viewToScreenSpace(endPosition);

    vec2 maxPosXY           = max(abs(endScreenPosition.xy * 2.0 - 1.0), vec2(1.0));
    float stepMult          = minOf(vec2(1.0) / maxPosXY);
        stepVector         *= stepMult;

    // closest texel iteration
    vec3 samplePos          = position;
    
        //samplePos          += stepVector / 6.0;
    vec3 screenPos          = viewToScreenSpace(samplePos);

    /*
    if (saturate(screenPos.xy) == screenPos.xy) {
        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = outsideVoxel ? abs(linearSample - currentDepth) / clamp(currentDepth, 0.25 / far, 2.0 / far)
                                           : abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.1) return vec3(screenPos.xy, depthSample);
        }
    }*/
    
        samplePos          += stepVector * noise;

    for (uint i = 0; i < maxSteps; ++i) {
        vec3 screenPos      = viewToScreenSpace(samplePos);
            samplePos      += stepVector;
        if (saturate(screenPos.xy) != screenPos.xy) break;

        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = outsideVoxel ? abs(linearSample - currentDepth) / clamp(currentDepth, 0.25 / far, 2.0 / far)
                                           : abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.1) return vec3(screenPos.xy, depthSample);
        }
    }

    return vec3(1.1);
}

#else

vec3 screenspaceRT(vec3 position, vec3 direction, float noise, bool outsideVoxel) {
    const uint maxSteps     = 16;

  	float rayLength = ((position.z + direction.z * far * sqrt3) > -sqrt3 * near) ?
                      (-sqrt3 * near - position.z) / direction.z : far * sqrt3;

    vec3 screenPosition     = viewToScreenSpace(position);
    vec3 endPosition        = position + direction * rayLength;
    vec3 endScreenPosition  = viewToScreenSpace(endPosition);

    vec3 screenDirection    = normalize(endScreenPosition - screenPosition);
        screenDirection.xy  = normalize(screenDirection.xy);

    vec3 maxLength          = (step(0.0, screenDirection) - screenPosition) / screenDirection;
    float stepMult          = minOf(maxLength);
    vec3 screenVector       = screenDirection * stepMult / float(maxSteps);

    vec3 screenPos          = screenPosition + screenDirection * maxOf(pixelSize * pi);

    if (saturate(screenPos.xy) == screenPos.xy) {
        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = outsideVoxel ? abs(linearSample - currentDepth) / clamp(currentDepth, 0.25 / far, 2.0 / far)
                                           : abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.25) return vec3(screenPos.xy, depthSample);
        }
    }
    
        screenPos          += screenVector * noise;

    for (uint i = 0; i < maxSteps; ++i) {
        if (saturate(screenPos.xy) != screenPos.xy) break;

        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = outsideVoxel ? abs(linearSample - currentDepth) / clamp(currentDepth, 0.25 / far, 2.0 / far)
                                           : abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.25) return vec3(screenPos.xy, depthSample);
        }

        screenPos      += screenVector;
    }

    return vec3(1.1);
}

#endif

#include "/lib/voxel/store.glsl"

#include "/lib/voxel/lpvSampling.glsl"


vec3 getVoxelTint(ivec3 index) {
    ivec2 uv    = getVoxelPixel(index);

    vec4 voxel  = texelFetch(shadowcolor0, uv, 0);
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));

    return unpack4x4(voxel.a).x > 0.5 ? albedo.rgb : vec3(1.0);
}

#include "/lib/voxel/trace.glsl"

#include "/lib/light/warp.glsl"

#include "/lib/light/emission.glsl"

vec3 clampNormal(vec3 n, vec3 v){
    float NoV = clamp( dot(n, v), 0., 1. );
    return normalize( NoV * v + n );
}

vec3 GeneratePlausibleVector(vec3 GeoNormal, vec3 SurfaceNormal, vec2 VectorXY) {
    vec3 SurfaceDirection   = GenerateCosineVectorSafe(SurfaceNormal, VectorXY);
    vec3 GeoDirection       = GenerateCosineVectorSafe(GeoNormal, VectorXY);

    vec3 Direction  = SurfaceDirection;

    if (dot(SurfaceNormal, Direction) < 0.0) Direction = -Direction;
    if (dot(GeoNormal, Direction) < 0.0) Direction = GeoDirection;

    //vec3 ClampedSurface     = clampNormal(GeoNormal, SurfaceDirection);

    return Direction;
}

vec3 PTLight(vec3 viewPos, vec3 scenePos, vec3 sceneNormal, vec3 flatNormal, vec2 dither, float SkyOcclusion, bool CrossFoliage, float Lightmap) {
    vec3 totalColor     = vec3(0.0);
    vec3 directLight    = vec3(0.0);

    #ifndef NO_DIRECTLIGHT
        #ifndef DIM
        vec3 directCol      = (sunAngle<0.5 ? colorPalette[0] : colorPalette[1]) * lightFlip;
        #elif DIM == 1
        vec3 directCol      = colorPalette[0];
        #endif
    #endif

    const float a1 = 1.0 / rho;
    const float a2 = a1 * a1;

    vec2 quasirandomCurr2 = 0.5 + fract(vec2(a1, a2) * frame255 + 0.5);

    vec3 startPos       = sceneToVoxelSpace(scenePos);
    ivec3 startVoxel    = voxelSpaceToIndex(startPos - flatNormal / 128.0);

    if (outsideVoxelVolume(startVoxel)) totalColor += Lightmap * blocklightColor;

    if (dot(sceneNormal, flatNormal) < 0.0) sceneNormal = flatNormal;

    if (CrossFoliage) sceneNormal = vec3(0,1,0);
    if (CrossFoliage) flatNormal = vec3(0,1,0);

    for (uint i = 0; i < PT_SPP; ++i) {
        int frame255new     = frame255 + int(i * 256);
        vec2 randSinCos     = vec2(cos(quasirandomCurr2.x), sin(quasirandomCurr2.y));
        vec2 noiseCurr      = hash22(gl_FragCoord.xy + frame255new);
        vec2 quasirandomCurr = 0.5 + fract(vec2(a1, a2) * frame255new + 0.5);

        vec3 voxelPos       = startPos;
            voxelPos       += flatNormal / 128.0;
        ivec3 voxelIndex    = startVoxel;

        vec3 direction      = normalize(scenePos);
        vec3 oldDirection   = direction;

        ++quasirandomCurr;
        noiseCurr      += hash22(vec2(gl_FragCoord.xy + vec2(cos(quasirandomCurr.x), sin(quasirandomCurr.y))));

        vec2 vectorXY   = fract(sqrt(2.0) * quasirandomCurr + noiseCurr);

            direction   = GeneratePlausibleVector(flatNormal, sceneNormal, vectorXY);

        //if (dot(sceneNormal, direction) < 0.0) direction = -direction;
        //if (dot(flatNormal, direction) < 0.0) direction = GenerateCosineVectorSafe(flatNormal, vectorXY);

        float brdf      = clamp(diffuseHammon(sceneNormal, -oldDirection, direction, 1.0) / saturate(dot(direction, sceneNormal)/pi), 0.0, halfPi);
        float directBRDF = diffuseHammon(sceneNormal, -oldDirection, direction, 1.0);
        vec3 contribution = vec3(1);

        bool hit        = false;
        bool OutsideVolume = outsideVoxelVolume(voxelIndex);

        float groundOcclusion = exp(-max0(-direction.y) * sqrPi);

        #ifdef SSPT_Enabled
        vec3 screenHit  = screenspaceRT(viewPos, normalize(mat3(gbufferModelView) * direction), dither.y, OutsideVolume);

            hit         = screenHit.z < 1.0;

        if (hit) {
            ivec2 hitPixel      = ivec2(screenHit.xy * viewSize * ResolutionScale);
            vec3 flatHitNormal  = texelFetch(colortex3, hitPixel, 0).xyz * 2.0 - 1.0;
            vec4 albedoSample   = texelFetch(colortex0, hitPixel, 0);

            vec3 hitPosView     = screenToViewSpace(screenHit);
            vec3 hitPosScene    = viewToSceneSpace(hitPosView);

            vec4 dataSample     = texelFetch(colortex5, hitPixel, 0);

            ivec3 neighbourIndex = sceneToVoxelIndex(hitPosScene + flatHitNormal / 64.0);

            vec4 voxel = vec4(0);

            if (getVoxelOccupancy(neighbourIndex, 0, voxel)) {
                if (unpack2x8I(voxel.z).y == 3) {
                    contribution *= decodeVoxelTint(voxel);
                }
            }

            if (dataSample.a > 1e-8) {
                totalColor     += dataSample.rgb * contribution * brdf;
            }

            if (dataSample.a > 1e-8) albedoSample.rgb = vec3(1);

            totalColor         += readLPV(sceneToVoxelIndex(hitPosScene + flatHitNormal * 0.1)) * contribution * albedoSample.rgb * (brdf);
            //totalColor         += getLight(hitPosScene + flatHitNormal * 0.25) * brdf * albedoSample.rgb * pi;
        } else {
        #endif
            vec4 voxel  = vec4(0);
            vec3 hitNormal = sceneNormal;

            vec3 PrevVoxel = voxelPos;

            hit         = marchBVH(voxelPos, voxelIndex, direction, voxelPos, hitNormal, voxelIndex, voxel, contribution, OutsideVolume);

            if (hit) {
                ivec2 voxelID = unpack2x8I(voxel.z);

                vec3 voxelTint = decodeVoxelTint(voxel);

                float firstBounceFalloff    = saturate(1.0 / (1.0 + distance(voxelPos, startPos) / 8.0));

                totalColor += getEmissionVoxel(voxelID.x, voxelTint, 0.0) * firstBounceFalloff * contribution * brdf;

                if (voxelID.x > 0) voxelTint = vec3(1.0);

                vec3 light = getLight(voxelToSceneSpace(voxelPos + hitNormal * 0.25)) * voxelTint * pi;
                //light  += readLPV(voxelSpaceToIndex(voxelPos + hitNormal * 0.1)) * voxelTint;

                float TraversalDistance = distance(voxelPos, PrevVoxel);

                if (TraversalDistance > 2.0) {
                    float Falloff       = sqr(sstep(TraversalDistance, 2.0, 8.0));
                    totalColor         += Falloff * minimumAmbientColor * minimumAmbientMult * minimumAmbientIllum * brdf * (groundOcclusion * 0.5 + 0.5);
                    #if DIM == -1
                    totalColor          += brdf * colorPalette[0] * Falloff;
                    #endif
                }
                
                totalColor += light * contribution * brdf;
            }

        #ifdef SSPT_Enabled
        }
        #endif

        if (!hit) {
            #if DIM != -1
                vec2 OcclusionFactor  = OutsideVolume ? vec2(sqr(SkyOcclusion), SkyOcclusion) : vec2(1.0);
                    OcclusionFactor.y = sstep(sqr(OcclusionFactor.y), 0.2, 0.8);

                totalColor           += groundOcclusion * (texture(colortex4, projectSky(direction, 1)).rgb * brdf) * skylightIllum * vec3(skylightRedMult, skylightGreenMult, skylightBlueMult) * OcclusionFactor.x;
                totalColor           += minimumAmbientColor * minimumAmbientMult * minimumAmbientIllum * brdf * (groundOcclusion * 0.5 + 0.5);

                #ifndef PT_SHARP_DIRECT
                directLight         += sstep(dot(direction, lightDir), 0.85, 0.9) * contribution * brdf * OcclusionFactor.y;
                #endif
            #else
                totalColor          += brdf * colorPalette[0];
            #endif
        }
    }

    directLight /= PT_SPP;
    totalColor  /= PT_SPP;

    //directLight *= diffuseHammon(mat3(gbufferModelView) * sceneNormal, normalize(viewPos), lightDirView, 1.0);
    #if DIM != -1
    return totalColor + directLight * directCol * sqrt3;
    #else
    return totalColor;
    #endif
}

vec3 GenerateConeVector(vec3 vector, float angle, vec2 xy) {
	vec3 dir = genUnitVector(xy);
	float VoD = dot(vector, dir);
	float noiseAngle = acos(VoD) * (angle / pi);

	return sin(noiseAngle) * (dir - vector * VoD) * inversesqrt(1.0 - VoD * VoD) + cos(noiseAngle) * vector;
}

#if DIM != -1
vec3 PTDirectLight(vec3 viewPos, vec3 scenePos, vec3 sceneNormal, vec3 flatNormal, vec2 dither, bool CrossFoliage) {
    vec3 totalColor     = vec3(0.0);

    vec3 directCol      = (sunAngle<0.5 ? colorPalette[0] : colorPalette[1]) * lightFlip;

    const float a1 = 1.0 / rho;
    const float a2 = a1 * a1;

    vec2 quasirandomCurr2 = 0.5 + fract(vec2(a1, a2) * frame255 + 0.5);

    vec3 startPos       = sceneToVoxelSpace(scenePos);
    ivec3 startVoxel    = voxelSpaceToIndex(startPos - flatNormal / 128.0);

    if (dot(sceneNormal, flatNormal) < 0.0) sceneNormal = flatNormal;

    if (CrossFoliage) sceneNormal = vec3(0,1,0);
    if (CrossFoliage) flatNormal = vec3(0,1,0);

    for (uint i = 0; i < 1; ++i) {
        int frame255new     = frame255 + int(i * 256);
        vec2 randSinCos     = vec2(cos(quasirandomCurr2.x), sin(quasirandomCurr2.y));
        vec2 noiseCurr      = hash22(gl_FragCoord.xy + frame255new);
        vec2 quasirandomCurr = 0.5 + fract(vec2(a1, a2) * frame255new + 0.5);

        vec3 voxelPos       = startPos;
            voxelPos       += flatNormal / 128.0;
        ivec3 voxelIndex    = startVoxel;

        vec3 direction      = normalize(scenePos);
        vec3 oldDirection   = direction;

        ++quasirandomCurr;
        noiseCurr      += hash22(vec2(gl_FragCoord.xy + vec2(cos(quasirandomCurr.x), sin(quasirandomCurr.y))));

        vec2 vectorXY   = fract(sqrt(2.0) * quasirandomCurr + noiseCurr);

            direction   = GenerateConeVector(lightDir, PT_SHARP_DIRECT_Angle, vectorXY);

        if (dot(sceneNormal, direction) < 0.0) break;

        float brdf      = diffuseHammon(sceneNormal, -oldDirection, direction, 1.0);
        vec3 contribution = vec3(1);

        bool hit        = false;
        bool OutsideVolume = outsideVoxelVolume(voxelIndex);

        #ifdef SSPT_Enabled
        vec3 screenHit  = screenspaceRT(viewPos, normalize(mat3(gbufferModelView) * direction), dither.y, OutsideVolume);

            hit         = screenHit.z < 1.0;

        if (!hit) {
        #endif
            vec4 voxel  = vec4(0);
            vec3 hitNormal = sceneNormal;

            hit         = marchBVH(voxelPos, voxelIndex, direction, voxelPos, hitNormal, voxelIndex, voxel, contribution, OutsideVolume);

        #ifdef SSPT_Enabled
        }
        #endif

        if (!hit) {
            totalColor           += directCol * contribution * brdf;
        }
    }

    return totalColor / 1;
}
#endif

#include "/lib/light/contactShadow.glsl"

void main() {
    LightColor  = vec3(0);

    vec2 lowresCoord    = (uv) / indirectResScale / ResolutionScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
    float sceneDepth    = texelFetch(depthtex0, pixelPos, 0).x;

    GBuffer             = vec4(0, 0, 1, 1);

    if (landMask(sceneDepth) && saturate(lowresCoord) == lowresCoord) {
        vec2 uv      = saturate(lowresCoord);

        vec3 viewPos    = screenToViewSpace(vec3(uv, sceneDepth), false);

        vec4 tex1       = texelFetch(colortex1, pixelPos, 0);
        vec3 sceneNormal = decodeNormal(tex1.xy);
        vec2 lightmaps  = saturate(unpack2x8(tex1.z));

        vec4 tex2       = texelFetch(colortex2, pixelPos, 0);
        ivec2 matID     = unpack2x8I(tex2.y);

        bool isSSS          = matID.x == 2 || matID.x == 4;
        float sssOpacity    = float(matID.x == 2 || matID.x == 4);

        GBuffer.xyz     = sceneNormal * 0.5 + 0.5;
        GBuffer.a       = sqrt(depthLinear(sceneDepth));

        vec3 flatNormal     = texelFetch(colortex3, pixelPos, 0).xyz * 2.0 - 1.0;

        //if (matID.x == 2) sceneNormal = vec3(0,1,0);

        float DirectIntensity = 0.0;

        LightColor.rgb   = PTLight(viewPos, viewToSceneSpace(viewPos), sceneNormal, flatNormal, vec2(ditherBluenoise2(), ditherHashNoise()), lightmaps.y, matID.x == 2, pow8(lightmaps.x));
        #if DIM != -1
        #ifdef PT_SHARP_DIRECT
        LightColor.rgb  += PTDirectLight(viewPos, viewToSceneSpace(viewPos), sceneNormal, flatNormal, vec2(ditherBluenoise2(), ditherHashNoise()), matID.x == 2);
        #endif
        #endif

        #if DIM == -1
        LightColor.rgb += colorPalette[0] / tau;
        #endif

        flatNormals     = texelFetch(colortex3, pixelPos, 0).xyz;

    }
}