
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

/* RENDERTARGETS: 5,7 */
layout(location = 0) out vec4 lightCurrent;
layout(location = 1) out vec4 fresnelCurrent;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex7;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;
uniform sampler3D depthtex2;

uniform int frameCounter;

uniform float far, near;

uniform vec2 viewSize;

#define colorSampler colortex5
#define fresnelSampler colortex7

#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"

/* ------ ATROUS ------ */

#include "/lib/offset/gauss.glsl"

ivec2 clampTexelPos(ivec2 pos) {
    return clamp(pos, ivec2(0.0), ivec2(viewSize));
}

float ditherBluenoise() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    float noise = texelFetch(noisetex, coord & 255, 0).a;

        noise   = fract(noise+float(frameCounter)/euler);

    return noise;
}
vec3 ditherBluenoiseF3() {
    ivec2 coord = ivec2(gl_FragCoord.xy);

    vec3 noise  = texelFetch(depthtex2, ivec3(coord & 255, 0), 0).xyz;
        noise   = fract(noise + torroidalShift.xyz * SVGF_SIZE);

    return noise;
}


vec2 computeVariance(ivec2 pos) {
    float sumMsqr   = 0.0;
    float sumMean   = 0.0;

    for (int i = 0; i<9; i++) {
        ivec2 deltaPos     = kernelO_3x3[i];

        vec3 col    = texelFetch(fresnelSampler, clampTexelPos(pos + deltaPos), 0).rgb;
        float lum   = getLuma(col);

        sumMsqr    += sqr(lum);
        sumMean    += lum;
    }
    sumMsqr  /= 9.0;
    sumMean  /= 9.0;

    return vec2(abs(sumMsqr - sqr(sumMean)) * rcp(max(sumMean, 1e-20)), sumMean);
}

vec4 FetchGbuffer(ivec2 UV) {
        UV          = ivec2(vec2(UV) / reflectionResScale);
    vec3 normals    = decodeNormal(texelFetch(colortex1, UV, 0).xy);
    float depth     = depthLinear(texelFetch(depthtex0, UV, 0).x) * far;
    return vec4(normals, depth);
}

/*
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
}*/

#define SPF_STRICTNESS 1.0      //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define SPF_NORMAL_STRICTNESS 1.0       //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

float sphericalGaussian(vec3 dir1, vec3 dir2, float lambda) {
    return exp(lambda * (saturate(dot(dir1, dir2)) - 1.0));
}

float lobeSharpness(float roughness) {
    return 2.0 / sqr(max(roughness, 1e-5));
}

float specularLobeWeight(vec3 centerNorm, vec3 norm, float centerRoughness, float roughness, float beta) {
    float lambaCenter = lobeSharpness(centerRoughness);
    float lambaSample = lobeSharpness(roughness);
    return pow(2.0 * sqrt(lambaCenter*lambaSample) / max(lambaCenter + lambaSample, 1e-5), beta) 
        * sphericalGaussian(centerNorm, norm, beta * lambaCenter * lambaSample / max(lambaCenter + lambaSample, 1e-5));
}

const float lobeFactor = SPF_LOBE;
const float sharpenWeight = SPF_SHARPEN;

vec4 modifySpecularColor(vec4 color) {
    return vec4(pow(length(color.rgb), sharpenWeight) * normalizeSafe(color.rgb), color.a);
}
vec4 inverseModifySpecularColor(vec4 color) {
    return vec4(pow(length(color.rgb), 1.0 / sharpenWeight) * normalizeSafe(color.rgb), color.a);
}

vec4 atrousSVGF(vec2 uv, const int size, out vec4 fresnel) {
    ivec2 UV           = ivec2(uv * viewSize);

    vec4 centerData     = FetchGbuffer(UV);

    vec4 centerColor    = texelFetch(colorSampler, UV, 0);
    float centerLuma    = getLuma(centerColor.rgb);

    fresnel             = texelFetch(fresnelSampler, UV, 0);

    float centerRoughness = fresnel.a;

    //return vec4(centerData.xyz, 1);

    //return vec4(centerColor.a);

    #ifndef reflectionsAtrousEnabled
    return centerColor;
    #endif

    vec4 total          = centerColor;
    float totalWeight   = 1.0;

    ivec2 jitter        = ivec2((ditherBluenoiseF3().xy - 0.5) * size);
    
    float normalExp = 128.0 * SPF_NORMAL_STRICTNESS;


    float specularWaveletWeight = mix(SPF_KERNEL_MINW, SPF_KERNEL_MAXW, (centerRoughness));
    float specularKernel[3][3] = {
		{ 1.0,                        specularWaveletWeight,       sqr(specularWaveletWeight) },
		{ specularWaveletWeight,      sqr(specularWaveletWeight),  pow4(specularWaveletWeight) },
        { sqr(specularWaveletWeight), pow4(specularWaveletWeight), pow8(specularWaveletWeight) }
        };

    total   = modifySpecularColor(total);

    const int r = 1;
	for(int y = -r; y <= r; ++y) {
		for(int x = -r; x <= r; ++x) {
			ivec2 p = UV + ivec2(x, y) * size + jitter;

			if(x == 0 && y == 0)
				continue;

            bool valid          = all(greaterThanEqual(p, ivec2(0))) && all(lessThan(p, ivec2(viewSize * reflectionResScale)));

            if (!valid) continue;

            vec4 currentData    = FetchGbuffer(p);

            vec4 currentColor   = texelFetch(colorSampler, clampTexelPos(p), 0);
            vec4 currentFresnel = texelFetch(fresnelSampler, p, 0);

            float w         = float(valid);
                w          *= specularKernel[abs(x)][abs(y)];

            float distDepth = abs(centerData.a - currentData.a) * 2.0;

                //w *= pow(max(0.0, dot(centerData.rgb, currentData.rgb)), normalExp);
                w *= exp(-distDepth / sqrt(float(size)) /*- sqrt(distLum * sigmaL)*/);
                w *= max0(specularLobeWeight(centerData.xyz, currentData.xyz, (centerRoughness), (currentFresnel.a), lobeFactor));

            //if (w < 1e-16) continue;

            //accumulate stuff
            total       += modifySpecularColor(currentColor) * w;
            fresnel.rgb += currentFresnel.rgb * w;

            totalWeight += w;
        }
    }

    //compensate for total sampling weight
    total  /= totalWeight;
    total   = inverseModifySpecularColor(total);
    fresnel.rgb /= totalWeight;

    return total;
}


void main() {
    vec2 lowresCoord    = uv / reflectionResScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / reflectionResScale);
    lightCurrent        = vec4(0.0);
    fresnelCurrent      = vec4(0);

    if (saturate(lowresCoord) == lowresCoord) {
        if (landMask(texelFetch(depthtex0, pixelPos, 0).x)) lightCurrent = clamp16F(atrousSVGF(uv, SVGF_SIZE, fresnelCurrent));
        else lightCurrent = clamp16F(texture(colorSampler, uv));
    }
}