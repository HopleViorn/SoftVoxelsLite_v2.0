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
#include "/lib/util/encoders.glsl"
#include "/lib/util/bicubic.glsl"

uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform vec3 sunVec;

#include "/lib/atmos/clouds/shadertoy_clouds.glsl"

in vec2 uv;

flat in mat4x3 colorPalette;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler3D depthtex2;

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float eyeAltitude;
uniform float far, near;
uniform float cloudLightFlip;
uniform float sunAngle;
uniform float lightFlip, wetness;
uniform float worldAnimTime;

uniform ivec2 eyeBrightnessSmooth;

uniform vec2 taaOffset;
uniform vec2 viewSize, pixelSize;

uniform vec3 cameraPosition;
uniform vec3 sunDir, sunDirView, moonDir, moonDirView;
uniform vec3 sunPosition, moonPosition;
uniform vec3 lightDirView, lightDir;
uniform vec4 daytime;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferModelView;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;

#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/frag/bluenoise.glsl"

#include "/lib/atmos/project.glsl"

#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/air/density.glsl"
#include "/lib/atmos/phase.glsl"
#include "/lib/atmos/waterConst.glsl"

vec3 getWaterFog(vec3 SceneColor, float dist, vec3 ScatterColor){
    float density   = max0(dist) * waterDensity;

    vec3 transmittance = expf(-waterAttenCoeff * density);

    const vec3 scatterCoeff = vec3(waterRed, waterGreen, waterBlue);

    vec3 scatter    = 1.0-exp(-density * scatterCoeff);
        scatter    *= max(expf(-waterAttenCoeff * density), expf(-waterAttenCoeff * tau));

    return SceneColor * transmittance + scatter * ScatterColor * rpi;
}

#define infClamp(x) max(x, 1e-16);
vec3 getGodrays(vec3 viewDirection, vec3 lightDir, vec3 lightDirView, vec3 lightPosition, vec2 uv) {
    float vis   = sstep(lightDir.y, -0.05, 0.0);

    float edgeFade  = sstep(-lightDirView.z, 0.33, 0.66);

    if (min(vis, edgeFade) < 0.001) return vec3(1);

    vec3 total      = vec3(1);

        vec4 lightPos   = vec4(lightPosition, 1) * gbufferProjection;
            lightPos.xyz /= infClamp(lightPos.w);
            lightPos.xy  /= infClamp(lightPos.z);

        vec2 lightUV    = lightPos.xy * 0.5 + 0.5;

        float truepos   = lightPosition.z/abs(lightPosition.z);

        vec2 stepUV     = (lightUV - uv) * godraySize;
            stepUV     /= godraySamples;

        vec2 sampleUV   = uv + stepUV * ditherBluenoise();
        total = vec3(0);
        float SumWeight = 0.0;
        for (uint i = 0; i < godraySamples; ++i, sampleUV += stepUV) {
            vec2 clampedUV = saturate(sampleUV);
            vec3 mask   = vec3(texture(depthtex0, clampedUV * ResolutionScale).x >= 1.0);
            if (clampedUV != sampleUV) mask = mix(mask, vec3(1), saturate(distance(clampedUV, sampleUV) * pi));
            float weight = cubeSmooth(1.0 - (float(i) / godraySamples));
            SumWeight  += weight;
            total      += mask * weight;
        }

        total          /= max(SumWeight, 0.1);
        total           = mix(vec3(1), total, edgeFade);


    return max0(total);
}

vec2 airPhaseFunction(float cosTheta) {
    return vec2(rayleighPhase(cosTheta), mieCS(cosTheta, airMieG));
}
vec3 simpleFog(vec3 SceneColor, vec3 Position, vec3 ScatterColor, vec3 direction, mat2x3 lightDirection, float Occlusion) {
    vec2 cosTheta = vec2(dot(direction, lightDirection[0]), dot(direction, lightDirection[1]));
    vec4 airPhase = vec4(airPhaseFunction(cosTheta.x), airPhaseFunction(cosTheta.y));
    const float phaseIso = 0.25 * pi;

    float Elevation = length(Position + vec3(0, planetRad + max(eyeAltitude, 1), 0)) - planetRad;
    vec3 Density    = getAirDensity(Elevation) * length(Position) * vec3(25, 10, 25) * FogDensity;
    vec3 OpticalDepth = airExtinctMat * Density;
    vec3 Transmittance = saturate(exp(-OpticalDepth));
    vec3 TransmittanceFraction = saturate((Transmittance - 1.0) / -OpticalDepth) * Occlusion;

    vec3 SunScattering = (airScatterMat[0] * Density.x * airPhase.x * euler + airScatterMat[1] * Density.y * airPhase.y) * TransmittanceFraction;
    vec3 MoonScattering = (airScatterMat[0] * Density.x * airPhase.z * euler + airScatterMat[1] * Density.y * airPhase.w) * TransmittanceFraction;

    vec3 Scattering = (airScatterMat * Density.xy) * TransmittanceFraction * (1.0 - wetness * 0.35);

    #ifdef godraysEnabled
    SunScattering *= getGodrays(direction, sunDir, sunDirView, sunPosition, uv / ResolutionScale);
    #endif


    return SceneColor * Transmittance + SunScattering * colorPalette[0] + MoonScattering * (0.41 * colorPalette[1] / normalizeSafe(moonIllum)) + Scattering * colorPalette[2] * rpi;
}

/* ------ Refraction ------ */

vec3 refract2(vec3 I, vec3 N, vec3 NF, float eta) {     //from spectrum by zombye
    float NoI = dot(N, I);
    float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
    if (k < 0.0) {
        return vec3(0.0); // Total Internal Reflection
    } else {
        float sqrtk = sqrt(k);
        vec3 R = (eta * dot(NF, I) + sqrtk) * NF - (eta * NoI + sqrtk) * N;
        return normalize(R * sqrt(abs(NoI)) + eta * I);
    }
}


/* ------ Reflections ------ */

#define RTRACE
#include "/lib/frag/reflection.glsl"

#define SPF_TEMPORAL_BLUENOISE

vec3 ditherBluenoiseStaticF3() {
    ivec2 coord = ivec2(gl_FragCoord.xy);

    #ifdef SPF_TEMPORAL_BLUENOISE
    vec3 noise  = texelFetch(depthtex2, ivec3(coord & 255, frameCounter & 7), 0).xyz;
    #else
    vec3 noise  = texelFetch(depthtex2, ivec3(coord & 255, 0), 0).xyz;
    #endif
        noise.xy  = fract(noise.xy + torroidalShift.xy * frameCounter);

    return noise;
}

vec2 rsi(vec3 pos, vec3 dir, float r) {
    float b     = dot(pos, dir);
    float det   = sqr(b) - dot(pos, pos) + sqr(r);

    if (det < 0.0) return vec2(-1.0);

        det     = sqrt(det);

    return vec2(-b) + vec2(-det, det);
}
vec3 planetCurvePosition(in vec3 x) {
    return vec3(x.x, length(x + vec3(0.0, planetRad, 0.0))-planetRad, x.z);
}

void main() {
    sceneColor  = texture(colortex0, uv).rgb;

    vec4 GBuffer0       = texture(colortex1, uv);

    vec4 GBuffer1       = texture(colortex2, uv);
    int matID           = int(unpack2x8(GBuffer1.y).x * 255.0);

    vec4 translucencyColor  = texture(colortex5, uv);

    vec2 sceneDepth     = vec2(texture(depthtex0, uv).x, texture(depthtex1, uv).x);
    bool translucent    = sceneDepth.x < sceneDepth.y;

    vec3 position0      = vec3(uv / ResolutionScale, sceneDepth.x);
        position0       = screenToViewSpace(position0);

    vec3 position1      = vec3(uv / ResolutionScale, sceneDepth.y);
        position1       = screenToViewSpace(position1);

    mat2x3 scenePos     = mat2x3(viewToSceneSpace(position0), viewToSceneSpace(position1));

    vec3 worldDir       = mat3(gbufferModelViewInverse) * normalize(position0);
    vec3 viewDir        = normalize(position0);

    bool water          = matID == 102;

    vec3 sceneNormal    = decodeNormal(GBuffer0.xy);
    vec3 viewNormal     = mat3(gbufferModelView) * sceneNormal;

    if (water){
        vec3 flatNormal     = clampDIR(normalize(cross(dFdx(scenePos[0]), dFdy(scenePos[0]))));
        vec3 flatViewNormal = normalize(mat3(gbufferModelView) * flatNormal);

        vec3 normalCorrected = dot(viewNormal, normalize(position1)) > 0.0 ? -viewNormal : viewNormal;

        vec3 refractedDir   = clampDIR(refract2(normalize(position1), normalCorrected, flatViewNormal, rcp(1.33)));
        //vec3 refractedDir   = refract(normalize(viewPos1), normalCorrected, rcp(1.33));

        float refractedDist = distance(position0, position1);

        vec3 refractedPos   = position1 + refractedDir * refractedDist;

        vec3 screenPos      = viewToScreenSpace(refractedPos);

        float distToEdge    = maxOf(abs(screenPos.xy * 2.0 - 1.0));
            distToEdge      = sqr(sstep(distToEdge, 0.7, 1.0));

        screenPos.xy        = mix(screenPos.xy, uv / ResolutionScale, distToEdge);

        //vec2 refractionDelta = coord - screenPos.xy;

        float refractedDepth = texture(depthtex1, screenPos.xy * ResolutionScale).x;

        if (refractedDepth > sceneDepth.x) {
            sceneDepth.y = refractedDepth;
            position1   = screenToViewSpace(vec3(screenPos.xy, sceneDepth.y));
            scenePos[1] = viewToSceneSpace(position1);

            sceneColor.rgb = texture(colortex0, screenPos.xy * ResolutionScale).rgb;

            worldDir    = clampDIR(normalize(scenePos[1]));
        }
    }

    vec3 skyColor       = texture(colortex4, projectSky(worldDir, 0)).rgb;
    
    // 添加体积云渲染
    // if (!landMask(sceneDepth.x) && isEyeInWater == 0) {
    // }

    mat2x3 reflectionAux = unpackReflectionAux(texture(colortex3, uv));

    vec3 translucencyAbsorption = reflectionAux[1];

    float vDotL     = dot(normalize(position1), lightDirView);

    float caveMult  = cube(linStep(eyeBrightnessSmooth.y/240.0, 0.4, 0.9));
    vec3 fogScatterColor = (sunAngle<0.5 ? colorPalette[0] : colorPalette[1]) * lightFlip * mieHG(vDotL, 0.68) * sqrt(caveMult);
        fogScatterColor *= mix(0.33, 0.66, sqrt(abs(lightDir.y)));
        fogScatterColor += colorPalette[2] * rpi * caveMult;

    if (matID == 102 && isEyeInWater == 0) {
        #ifdef waterFogEnabled
        sceneColor = getWaterFog(sceneColor, distance(position0, position1), fogScatterColor);
        translucencyAbsorption  = vec3(1);
        #endif
    }

    if (translucent) sceneColor = sceneColor * saturate(translucencyAbsorption) * (1.0 - translucencyColor.a) + translucencyColor.rgb;


    if (landMask(sceneDepth.x)) {


        materialProperties material = materialProperties(1.0, 0.02, false, false, mat2x3(0.0));
        if (water) material = materialProperties(0.01, 0.02, false, false, mat2x3(0.0));
        else material   = decodeLabBasic(unpack2x8(GBuffer1.x));

        float GroundWetness = unpack2x8(GBuffer1.z).y;

        vec3 blueNoiseF3 = ditherBluenoiseStaticF3();
        vec2 lightmaps  = saturate(unpack2x8(GBuffer0.z));

        float SkyOcclusion = sstep(lightmaps.y, 0.7, 0.8);
        float RoughnessFalloff  = 1.0 - (linStep(material.roughness, ReflectionRoughnessCutoff * 0.71, ReflectionRoughnessCutoff));

        if (dot(-viewDir, viewNormal) < 0.0) {
            sceneNormal = -sceneNormal;
            viewNormal = -viewNormal;
        }

        vec4 ReflectionColor = vec4(0.0);

        vec3 ReflectedViewDirection = reflect(viewDir, viewNormal);
        vec3 ReflectedDirection = reflect(worldDir, sceneNormal);

        vec3 Fresnel    = vec3(0);

        #ifndef RoughReflections
        if (GroundWetness > 0.01) {
            material.roughness = 0.01;
            material.conductor = false;
            material.conductorComplex = false;
            material.f0 = 0.02;
        }
        #endif

        if (RoughnessFalloff > 0.001 || water || GroundWetness > 0.01) {
            if (water || material.roughness <= 0.01) {
                float fresnel   = fresnelDielectric(dot(-viewDir, viewNormal), 0.02);
                bool hit    = false;

                float ssrThreshold  = 128.0;

                #ifdef screenspaceReflectionsEnabled
                    vec3 reflectedPos   = screenspaceRT(position0, ReflectedViewDirection, blueNoiseF3.z, ssrThreshold);
                        hit    = reflectedPos.z < 1.0;

                    if (hit) ReflectionColor += vec4(texelFetch(colortex0, ivec2(reflectedPos.xy * viewSize * ResolutionScale), 0).rgb, 1.0);
                #endif

                if (!hit) ReflectionColor += vec4(texture(colortex4, projectSky(ReflectedDirection, 1)).rgb * SkyOcclusion, SkyOcclusion);

                ReflectionColor.a *= RoughnessFalloff;

                Fresnel = BRDFfresnelAlbedoTint(-viewDir, viewNormal, material, reflectionAux[1]);
            }
            #ifdef RoughReflections
            else {
                mat3 rot        = getRotationMat(vec3(0, 0, 1), viewNormal);
                vec3 tangentV   = viewDir * rot;

                const uint steps    = RoughReflectionSamples;
                const float rSteps  = 1.0 / float(steps);

                for (uint i = 0; i < steps; ++i) {
                    if (RoughnessFalloff <= 1e-3) break;
                    vec3 roughNrm   = rot * ggxFacetDist(-tangentV, material.roughness, blueNoiseF3.xy);

                    vec3 ReflectedViewDirection = reflect(viewDir, roughNrm);

                    vec3 reflectSceneDir = mat3(gbufferModelViewInverse) * ReflectedViewDirection;

                    bool hit    = false;

                    float ssrThreshold  = 128.0;

                    #ifdef screenspaceReflectionsEnabled
                        vec3 reflectedPos   = screenspaceRT(position0, ReflectedViewDirection, blueNoiseF3.z, ssrThreshold);
                            hit    = reflectedPos.z < 1.0;

                        if (hit) ReflectionColor += vec4(texelFetch(colortex0, ivec2(reflectedPos.xy * viewSize * ResolutionScale), 0).rgb, 1.0);
                    #endif

                    if (!hit) ReflectionColor += readSpherePositionAware(SkyOcclusion, scenePos[0], reflectSceneDir);

                        Fresnel    += BRDFfresnelAlbedoTint(-viewDir, roughNrm, material, reflectionAux[1]);
                }
                if (clamp16F(ReflectionColor) != ReflectionColor) ReflectionColor = vec4(0.0);

                ReflectionColor *= rSteps;
                Fresnel    *= rSteps;

                ReflectionColor.a *= RoughnessFalloff;
            }
            #endif

            if (material.conductor) sceneColor.rgb = mix(sceneColor.rgb, ReflectionColor.rgb * Fresnel, ReflectionColor.a);
            else sceneColor.rgb = mix(sceneColor.rgb, ReflectionColor.rgb, Fresnel * ReflectionColor.a);
        }
    }

    #if FogMode == 1
    vec2 PlanetSphere   = rsi(vec3(0, planetRad + max(eyeAltitude, 1), 0), worldDir, planetRad);
    bool IsPlanet       = PlanetSphere.x > 0.0;
    vec3 SurfacePosition = IsPlanet && !(landMask(sceneDepth.x)) ? (worldDir * max0(PlanetSphere.x)) : scenePos[0];

    // if ((landMask(sceneDepth.x) || IsPlanet) && isEyeInWater == 0) sceneColor.rgb = simpleFog(sceneColor.rgb, SurfacePosition, fogScatterColor, normalize(position0), mat2x3(sunDirView, moonDirView), caveMult);
    #endif

    if (isEyeInWater == 1) {
        #ifdef waterFogEnabled
        sceneColor = getWaterFog(sceneColor, length(position0), fogScatterColor);
        #endif
    }

    vec3 ro = cameraPosition;
    vec3 rd = worldDir;
    ivec2 px = ivec2(gl_FragCoord.xy);
    vec4 clouds = renderShadertoyClouds(ro, rd, px);
    sceneColor = sceneColor * (1.0 - clouds.a) + clouds.rgb;
}