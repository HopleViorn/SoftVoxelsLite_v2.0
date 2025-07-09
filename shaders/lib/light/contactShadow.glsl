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

/*
Screenspace Contact shadows based on Spectrum by Zombye.
Because I have a hard time with screenspace RT effects for some reason...
*/

float viewToScreenSpace(float depth) {
	return (gbufferProjection[2].z * depth + gbufferProjection[3].z) * 0.5 * rcp(-depth) + 0.5;
}

float AscribeDepth(float depth, float ascribeAmount) {  //from Spectrum, didn't feel like redoing that function for no reason
	depth = 1.0 - 2.0 * depth;
	depth = (depth + gbufferProjection[2].z * ascribeAmount) / (1.0 + ascribeAmount);
	return 0.5 - 0.5 * depth;
}
float GetLinearDepth(sampler2D depthSampler, vec2 coord) {
    // Interpolates after linearizing, significantly reduces a lot of issues for screen-space shadows
    coord = coord * viewSize + 0.5;

    vec2  f = fract(coord);
    ivec2 i = ivec2(coord - f);

    vec4 s = textureGather(depthSampler, i / viewSize) * 2.0 - 1.0;
    s = 1.0 / (gbufferProjectionInverse[2].w * s + gbufferProjectionInverse[3].w);

    s.xy = mix(s.wx, s.zy, f.x);
    return mix(s.x,  s.y,  f.y) * gbufferProjectionInverse[3].z;
}
float getContactShadow(sampler2D depth, vec3 viewPos, float dither, float sceneDepth, float nDotV, vec3 lightDir) {
    const uint steps = 16;
    const uint stride = 4;
    
    vec3 screenPos  = viewToScreenSpace(viewPos, true);

    vec3 rStep  = viewPos + abs(viewPos.z) * lightDir;
        rStep   = viewToScreenSpace(rStep, true) - screenPos;
        rStep  *= minOf((step(0.0, rStep) - screenPos) / rStep);

        screenPos.xy *= viewSize;
        rStep.xy   *= viewSize;
        //screenPos.xy -= taaOffset * 0.5;

        rStep  *= rcp(abs(abs(rStep.x) < abs(rStep.y) ? rStep.y : rStep.x));

    vec2 stepsToEnd     = (step(0.0, rStep.xy) * viewSize - screenPos.xy) / rStep.xy;
    uint maxIterations  = min(uint(ceil(min(min(stepsToEnd.x, stepsToEnd.y), maxOf(viewSize)) * rcp(float(stride)))), steps);

    vec3 startPos   = screenPos;

    bool hit    = false;

    float noise     = floor(stride * dither + 1.0);

    for (uint i = 0; i < maxIterations && !hit; ++i) {
        float pixelSteps    = float(i * stride) + noise;
        screenPos   = startPos + pixelSteps * rStep;

        float maxZ  = screenPos.z;
        float minZ  = rStep.z > 0.0 && i == 0 ? startPos.z : screenPos.z - float(stride) * abs(rStep.z);

        if (1.0 < minZ || maxZ < 0.0) break;

        float d     = texelFetch(depth, ivec2(screenPos.xy * ResolutionScale), 0).x;
        float ascribedD = AscribeDepth(d, 1e-2 * (i == 0 ? noise : float(stride)) * gbufferProjectionInverse[1].y);
        float dInterp = viewToScreenSpace(GetLinearDepth(depth, screenPos.xy * pixelSize * ResolutionScale));
        float ascribedDInterp = AscribeDepth(dInterp, 1e-2 * (i == 0 ? noise : float(stride)) * gbufferProjectionInverse[1].y);

        hit = maxZ >= d && minZ <= ascribedD && maxZ >= dInterp && minZ <= ascribedDInterp && d > 0.65 && d < 1.0;
    }

    return float(!hit);
}

/*
float getRTShadow(vec3 viewPos, float dither) {
    const uint steps    = 16;

    vec3 viewDir    = normalize(viewPos);

    float dist      = length(viewPos);
    float minStep   = max(dist * 0.005, 0.01);

    float stepLength   = max(minStep * 0.25, 0.25) / float(steps);

    vec3 rStart     = viewPos;
    vec3 rDir       = lightvecView;
    vec3 rStep      = rDir * stepLength;
    vec3 rPos       = rStart + rStep * dither;

    bool hit        = false;

    for (uint i = 0; i < steps; ++i) {
        vec3 screenPos  = viewToScreenSpace(rPos);

        if (saturate(screenPos.xy) != screenPos.xy) break;

        float depth     = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize), 0).x;
        vec3 sampleViewPos = screenToViewSpace(vec3(screenPos.xy, depth));

        float error     = distance(rPos, sampleViewPos);

        if (error < stepLength && (distance(rStart, rPos) > minStep) && screenPos.z > depth && distance(screenPos.z, depth) < stepLength) {
            hit = true;
            break;
        }
        rPos   += rStep;
    }

    return float(!hit);
}*/