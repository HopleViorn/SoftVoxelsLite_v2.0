
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

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 indirectCurrent;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex13;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform int frameCounter;

uniform float far, near;

uniform vec2 viewSize;

#define colorSampler colortex5
#define gbufferSampler colortex3

#define colorHistorySampler colortex13
#define gbufferHistorySampler colortex12

/* ------ ATROUS ------ */

#include "/lib/offset/gauss.glsl"

ivec2 clampTexelPos(ivec2 pos) {
    return clamp(pos, ivec2(0.0), ivec2(viewSize * indirectResScale * ResolutionScale));
}

float ditherBluenoise() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    float noise = texelFetch(noisetex, coord & 255, 0).a;

        noise   = fract(noise+float(frameCounter)/euler);

    return noise;
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

vec4 FetchGbuffer(ivec2 UV) {
    vec4 Val  = texelFetch(gbufferSampler, UV, 0);
    return vec4(Val.rgb * 2.0 - 1.0, sqr(Val.w) * far);
}

const float gaussKernel[2][2] = {
	{ 1.0 / 4.0, 1.0 / 8.0  },
	{ 1.0 / 8.0, 1.0 / 16.0 }
};

float computeSigmaL(ivec2 pixelUV, float center) {
	float sum = center * gaussKernel[0][0];

    const int r = 1;
	for(int y = -r; y <= r; y++) {
		for(int x = -r; x <= r; x++) {
			if(x != 0 || y != 0) {
				ivec2 UV    = pixelUV + ivec2(x, y);
				float variance = texelFetch(colorSampler, UV, 0).a;
				float w     = gaussKernel[abs(x)][abs(y)];
				sum        += variance * w;
			}
		}
	}

	return sqrt(max(sum, 1e-8));
}

vec4 atrousSVGF(sampler2D tex, vec2 uv, const int size) {
    ivec2 UV           = ivec2(uv * viewSize);

    vec4 centerData     = FetchGbuffer(UV);

    vec4 centerColor    = texelFetch(tex, UV, 0);
    float centerLuma    = maxOf(centerColor.rgb);

    //return vec4(centerColor.a);

    //return centerColor;

    float pixelAge      = texelFetch(colorHistorySampler, UV, 0).a;

    vec4 total          = centerColor;
    float totalWeight   = 1.0;

    //float sizeMult      = size > 2 ? (fract(ditherBluenoise() + float(size) / euler) + 0.5) * float(size) : float(size);
    //    sizeMult        = mix(float(size), sizeMult, cube(pixelAge));

    //ivec2 jitter        = ivec2(sincos(fract(ditherBluenoise() + float(size) / euler)) * size * 0.5);

    float frames    = pixelAge;

    //float sigmaBias = mix(0.41, 0.07, (saturate(frames / 32.0)));
    float sigmaBias = exp(-frames * PT_SPP / 8.0) + 0.15 / SVGF_RAD;
    float offset    = mix(0.05 * (0.5 * SVGF_RAD), 0.02, saturate(frames / 16.0));
    float maxDelta  = mix(pi, sqrPi, saturate(frames / 16.0));
    float sigmaMul  = mix(0.25, 0.07, saturate(frames / 8.0));

    float sigmaDistMul = 2.0 - (1.0 / (1.0 + centerData.a / 128.0));

	float sigmaL = 1.0 / (sigmaMul * SVGF_STRICTNESS * sigmaDistMul * computeSigmaL(UV, centerColor.a) + sigmaBias);
    
    float normalExp = mix(2.0, 8.0, saturate(frames / 16.0)) * SVGF_NORMALEXP;

	//const int r = size >= 16 ? 2 : SVGF_RAD;
    const int r = SVGF_RAD;
	for(int y = -r; y <= r; ++y) {
		for(int x = -r; x <= r; ++x) {
			ivec2 p = UV + ivec2(x, y) * size;

			if(x == 0 && y == 0)
				continue;

            bool valid          = all(greaterThanEqual(p, ivec2(0))) && all(lessThan(p, ivec2(viewSize)));

            if (!valid) continue;

            vec4 currentData    = FetchGbuffer(p);

            vec4 currentColor   = texelFetch(tex, clampTexelPos(p), 0);
            float currentLuma   = maxOf(currentColor.rgb);

            float w         = float(valid);

            float distLum   = abs(centerLuma - currentLuma);
                distLum     = sqr(distLum) / max(centerLuma, offset);
                distLum     = clamp(distLum, 0.0, maxDelta);

            float distDepth = abs(centerData.a - currentData.a) * 4.0;

                w *= pow(max(0.0, dot(centerData.rgb, currentData.rgb)), normalExp);
                w *= exp(-distDepth / sqrt(float(size)) - sqrt(distLum * sigmaL));

            //accumulate stuff
            total       += currentColor * w * vec4(1,1,1,w);

            totalWeight += w;
        }
    }

    //compensate for total sampling weight
    total /= vec4(totalWeight,totalWeight,totalWeight,sqr(totalWeight));

    return total;
}


void main() {
    vec2 lowresCoord    = uv / indirectResScale / ResolutionScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
    indirectCurrent     = vec4(0.0);

    if (saturate(lowresCoord) == lowresCoord) {
        #ifdef SVGF_FILTER
            if (landMask(texelFetch(depthtex0, pixelPos, 0).x)) indirectCurrent = clamp16F(atrousSVGF(colorSampler, uv, SVGF_SIZE));
            else indirectCurrent = clamp16F(stex(colorSampler));
        #else
            indirectCurrent = clamp16F(stex(colorSampler));
        #endif
    }
}