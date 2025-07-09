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

#include "/lib/head.glsl"

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 SceneColor;

in vec2 uv;

flat in vec3 skylightColor;
flat in vec3 directLightColor;

flat in vec3 cloudLightDir;

uniform int frameCounter, worldTime;

uniform float cloudLightFlip, eyeAltitude, frameTimeCounter, wetness, worldAnimTime;

uniform vec2 pixelSize, taaOffset;

uniform vec3 cameraPosition;

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

uniform sampler2D colortex0, colortex4, depthtex0, noisetex;

/* ------ includes ------*/
#define FUTIL_D3X3
#define FUTIL_ROT2
#include "/lib/fUtil.glsl"

#include "/lib/atmos/phase.glsl"
#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

#define airmassStepBias 0.33
#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/air/density.glsl"

#include "/lib/atmos/project.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/bicubic.glsl"
#include "/lib/atmos/clouds/common.glsl"

vec4 RenderClouds(vec3 direction, float vDotL, vec2 dither, vec3 skyColor) {
    vec4 Result     = vec4(0, 0, 0, 1);
    float eyeAltitude = 64.0;

    vec3 sunlight       = directLightColor;
    vec3 skylight       = skylightColor;

    bool PlaneVisible   = false;

    bool IsPlanet   = rsi(vec3(0, planetRad + max(eyeAltitude, 1.0), 0), direction, planetRad).x <= 0.0;

    PlaneVisible    = IsPlanet;

    // --- PLANAR CLOUDS 1 --- //
    #ifdef CLOUD_PLANE1_ENABLED

    if (PlaneVisible && (Result.a > 1e-10)) {
        vec3 Plane      = GetPlane(CLOUD_PLANE1_ALT, direction);

        vec2 Sphere     = rsi(vec3(0, planetRad + eyeAltitude, 0), direction, planetRad + CLOUD_PLANE1_ALT);

        float Distance  = length(Plane);
            Distance    = clamp(eyeAltitude > CLOUD_PLANE1_ALT ? Sphere.x : Sphere.y, 0.0, CLOUD_PLANE1_CLIP);
            Plane       = planetCurvePosition(direction * Distance);

        vec3 Airmass    = getAirmass(vec3(0, planetRad + eyeAltitude, 0), direction, Distance, 0.25, 3) / Distance;

        vec3 RPosition  = Plane + cameraPosition;

        vec4 VolumeResult = vec4(0, 0, 0, 1);

        mat2x3 VolumeBounds = mat2x3(
            GetPlane(CLOUD_PLANE1_BOUNDS.x, direction),
            GetPlane(CLOUD_PLANE1_BOUNDS.y, direction)
        );

        float RLength   = distance(VolumeBounds[0], VolumeBounds[1]);

        const float SigmaT  = 0.0015;

        if (Distance < CLOUD_PLANE1_CLIP) {
            float Density   = cloudPlanarShape1(RPosition, false);

            if (Density > 0.0) {
                float extinction    = Density * SigmaT;
                float stepT         = exp(-extinction * RLength);
                float integral      = (1.0 - stepT) * rcp(SigmaT);

                vec3 atmosFade  = expf(-max(airScatterMat * Airmass.xy * Distance, 0.0));
                    atmosFade   = mix(atmosFade, vec3(0.0), sqr(linStep(Distance / CLOUD_PLANE1_CLIP, 0.5, 1.0)));

                if (maxOf(atmosFade) < 1e-4) {
                    VolumeResult.rgb     += (skyColor * SigmaT) * (integral * VolumeResult.a);
                    VolumeResult.a  *= stepT;
                } else {
                    float lightOD       = cloudPlanarLight1(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3) * 4;
                    float skyOD         = cloudPlanarLight1(VolumeBounds[0], 2, vec3(0.0, 1.0, 0.0));

                    vec2 scattering     = vec2(0);

                    const float albedo = 0.75;
                    const float scatterMult = 1.0;
                    float avgTransmittance  = exp(-(4.0 / SigmaT) * Density);
                    float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
                    float baseScatter       = albedo * (1.0 - stepT);

                    vec3 phaseG         = pow(vec3(0.6, 0.35, 0.9), vec3(1.0 + (lightOD + Density * RLength) * SigmaT) * vec3(1, 1, 0.25));
                    vec3 phaseGSky      = pow(vec3(0.6, 0.35, 0.8), vec3(1.0 + (skyOD + Density * RLength) * SigmaT));

                    float scatterScale  = pow(1.0 + 1.0 * (lightOD) * SigmaT, -1.0 / 1.0) * bounceEstimate;
                    float SkyScatterScale = pow(1.0 + 1.0 * skyOD * SigmaT, -1.0 / 1.0) * bounceEstimate;

                    scattering.x  += baseScatter * cloudPhaseNew(vDotL, phaseG) * scatterScale * GetPlanar0Occlusion(RPosition, cloudLightDir) * GetSheetOcclusion(RPosition, cloudLightDir);
                    scattering.y  += baseScatter * cloudPhaseNew(direction.y, phaseGSky) * SkyScatterScale /* GetPlanar0Occlusion(RPosition, vec3(0,1,0))*/;

                    VolumeResult.rgb    = (sunlight * scattering.x) + (skylight * scattering.y);
                    VolumeResult.rgb    = mix(skyColor * SigmaT * integral, VolumeResult.rgb, atmosFade);
                    VolumeResult.rgb    = VolumeResult.rgb * (VolumeResult.a);

                    VolumeResult.a     *= stepT;
                }
            }
        }

            Result.rgb     = Result.rgb * VolumeResult.a + VolumeResult.rgb;
            Result.a *= VolumeResult.a;
    }
    #endif

    // --- PLANAR CLOUDS 0 --- //
    #ifdef CLOUD_PLANE0_ENABLED
    if (PlaneVisible && (Result.a > 1e-10)) {
        vec3 Plane      = GetPlane(CLOUD_PLANE0_ALT, direction);

        vec2 Sphere     = rsi(vec3(0, planetRad + eyeAltitude, 0), direction, planetRad + CLOUD_PLANE0_ALT);

        float Distance  = length(Plane);
            Distance    = clamp(eyeAltitude > CLOUD_PLANE0_ALT ? Sphere.x : Sphere.y, 0.0, CLOUD_PLANE0_CLIP);
            Plane       = planetCurvePosition(direction * Distance);

        vec3 Airmass    = getAirmass(vec3(0, planetRad + eyeAltitude, 0), direction, Distance, 0.25, 3) / Distance;

        vec3 RPosition  = Plane + cameraPosition;

        vec4 VolumeResult = vec4(0, 0, 0, 1);

        mat2x3 VolumeBounds = mat2x3(
            GetPlane(CLOUD_PLANE0_BOUNDS.x, direction),
            GetPlane(CLOUD_PLANE0_BOUNDS.y, direction)
        );

        float RLength   = distance(VolumeBounds[0], VolumeBounds[1]);

        const float SigmaT  = CLOUD_PLANE0_SIGMA;

        if (Distance < CLOUD_PLANE0_CLIP) {
            float Density   = cloudPlanarShape0(RPosition);

            if (Density > 0.0) {
                float extinction    = Density * SigmaT;
                float stepT         = exp(-extinction * RLength);
                float integral      = (1.0 - stepT) * rcp(SigmaT);

                vec3 atmosFade  = expf(-max(airScatterMat * Airmass.xy * Distance, 0.0));
                    atmosFade   = mix(atmosFade, vec3(0.0), sqr(linStep(Distance / CLOUD_PLANE0_CLIP, 0.5, 1.0)));

                if (maxOf(atmosFade) < 1e-4) {
                    VolumeResult.rgb     += (skyColor * SigmaT) * (integral * VolumeResult.a);
                    VolumeResult.a  *= stepT;
                } else {
                    float lightOD       = cloudPlanarLight0(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3);
                    float skyOD         = cloudPlanarLight0(VolumeBounds[0], 2, vec3(0.0, 1.0, 0.0));

                    vec2 scattering     = vec2(0);

                    const float albedo = 0.75;
                    const float scatterMult = 1.0;
                    float avgTransmittance  = exp(-(8.0 / SigmaT) * Density);
                    float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
                    float baseScatter       = albedo * (1.0 - stepT);

                    vec3 phaseG         = pow(vec3(0.6, 0.35, 0.9), vec3(1.0 + (lightOD + Density * RLength) * SigmaT) * vec3(1, 1, 0.2));
                    vec3 phaseGSky      = pow(vec3(0.6, 0.35, 0.8), vec3(1.0 + (skyOD + Density * RLength) * SigmaT));

                    float scatterScale  = pow(1.0 + 1.0 * (lightOD) * SigmaT, -1.0 / 1.0) * bounceEstimate * GetSheetOcclusion(RPosition, cloudLightDir);
                    float SkyScatterScale = pow(1.0 + 1.0 * skyOD * SigmaT, -1.0 / 1.0) * bounceEstimate;

                    scattering.x  += baseScatter * cloudPhaseNew(vDotL, phaseG) * scatterScale;
                    scattering.y  += baseScatter * cloudPhaseNew(direction.y, phaseGSky) * SkyScatterScale;

                    VolumeResult.rgb    = (sunlight * scattering.x) + (skylight * scattering.y);
                    VolumeResult.rgb    = mix(skyColor * SigmaT * integral, VolumeResult.rgb, atmosFade);
                    VolumeResult.rgb    = VolumeResult.rgb * (VolumeResult.a);

                    VolumeResult.a     *= stepT;
                }
            }
        }

            Result.rgb     = Result.rgb * VolumeResult.a + VolumeResult.rgb;
            Result.a *= VolumeResult.a;
    }
    #endif

    // --- SHEET CLOUDS --- //
    #ifdef CLOUD_SHEET_ENABLED
    if (PlaneVisible && (Result.a > 1e-10)) {
        vec3 Plane      = GetPlane(CLOUD_SHEET_ALT, direction);

        vec2 Sphere     = rsi(vec3(0, planetRad + eyeAltitude, 0), direction, planetRad + CLOUD_SHEET_ALT);

        float Distance  = length(Plane);
            Distance    = clamp(eyeAltitude > CLOUD_SHEET_ALT ? Sphere.x : Sphere.y, 0.0, CLOUD_SHEET_CLIP);
            Plane       = planetCurvePosition(direction * Distance);

        vec3 Airmass    = getAirmass(vec3(0, planetRad + eyeAltitude, 0), direction, Distance, 0.25, 3) / Distance;

        vec3 RPosition  = Plane + cameraPosition;

        vec4 VolumeResult = vec4(0, 0, 0, 1);

        mat2x3 VolumeBounds = mat2x3(
            GetPlane(CLOUD_SHEET_BOUNDS.x, direction),
            GetPlane(CLOUD_SHEET_BOUNDS.y, direction)
        );

        float RLength   = distance(VolumeBounds[0], VolumeBounds[1]);

        const float SigmaT  = 0.005;

        if (Distance < CLOUD_SHEET_CLIP) {
            float Density   = cloudSheetShape(RPosition);

            if (Density > 0.0) {
                float extinction    = Density * SigmaT;
                float stepT         = exp(-extinction * RLength);
                float integral      = (1.0 - stepT) * rcp(SigmaT);

                vec3 atmosFade  = expf(-max(airScatterMat * Airmass.xy * Distance, 0.0));
                    atmosFade   = mix(atmosFade, vec3(0.0), sqr(linStep(Distance / CLOUD_SHEET_CLIP, 0.5, 1.0)));

                if (maxOf(atmosFade) < 1e-4) {
                    VolumeResult.rgb     += (skyColor * SigmaT) * (integral * VolumeResult.a);
                    VolumeResult.a  *= stepT;
                } else {
                    float lightOD       = cloudSheetLight(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3);
                    float skyOD         = cloudSheetLight(VolumeBounds[0], 2, vec3(0.0, 1.0, 0.0));

                    vec2 scattering     = vec2(0);

                    const float albedo = 0.75;
                    const float scatterMult = 1.0;
                    float avgTransmittance  = exp(-(8.0 / SigmaT) * Density);
                    float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
                    float baseScatter       = albedo * (1.0 - stepT);

                    vec3 phaseG         = pow(vec3(0.8, 0.35, 0.98), vec3((1.0 + (lightOD + Density * RLength) * SigmaT * vec3(0.5, 1, 0.1))));
                    vec3 phaseGSky      = pow(vec3(0.6, 0.35, 0.8), vec3((1.0 + (skyOD + Density * RLength) * SigmaT)));

                    float scatterScale  = pow(1.0 + 1.0 * (lightOD) * SigmaT, -1.0 / 1.0) * bounceEstimate;
                    float SkyScatterScale = pow(1.0 + 1.0 * skyOD * SigmaT, -1.0 / 1.0) * bounceEstimate;

                    scattering.x  += baseScatter * cloudPhaseSheet(vDotL, phaseG) * scatterScale;
                    scattering.y  += baseScatter * cloudPhaseNew(direction.y, phaseGSky) * SkyScatterScale;

                    VolumeResult.rgb    = (sunlight * scattering.x) + (skylight * scattering.y);
                    VolumeResult.rgb    = mix(skyColor * SigmaT * integral, VolumeResult.rgb, atmosFade);
                    VolumeResult.rgb    = VolumeResult.rgb * (VolumeResult.a);

                    VolumeResult.a     *= stepT;
                }
            }
        }

            Result.rgb     = Result.rgb * VolumeResult.a + VolumeResult.rgb;
            Result.a *= VolumeResult.a;
    }
    #endif

    return Result;
}

void main() {
    SceneColor = texture(colortex4, uv);

    vec2 projectionUV   = fract(uv * vec2(1.0, TILES_COUNT));

    uint index      = uint(floor(uv.y * TILES_COUNT));

    if (index == 1) {
        vec3 direction  = unprojectSky(projectionUV);

        vec3 skyColor   = texture(colortex4, projectionUV / vec2(1, TILES_COUNT)).rgb;

        vec4 Clouds     = RenderClouds(direction, dot(direction, cloudLightDir), vec2(ditherBluenoiseStatic(), 0), skyColor);

        SceneColor.rgb  = SceneColor.rgb * Clouds.a + Clouds.rgb;
    }
}