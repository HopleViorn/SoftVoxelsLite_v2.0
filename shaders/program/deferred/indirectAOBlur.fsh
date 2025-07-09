
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

#include "/lib/frag/bluenoise.glsl"

#define colorSampler colortex5
#define gbufferSampler colortex3

#define colorHistorySampler colortex13
#define gbufferHistorySampler colortex12

/* ------ ATROUS ------ */

#include "/lib/offset/gauss.glsl"

ivec2 clampTexelPos(ivec2 pos) {
    return clamp(pos, ivec2(0.0), ivec2(viewSize));
}

vec4 FetchGbuffer(ivec2 UV) {
    vec4 Val  = texelFetch(gbufferSampler, UV, 0);
    return vec4(Val.rgb * 2.0 - 1.0, sqr(Val.w) * far);
}

float SpatialBlur(sampler2D tex, vec2 uv) {
    ivec2 UV           = ivec2(uv * viewSize);

    vec4 centerData     = FetchGbuffer(UV);

    float centerColor   = texelFetch(tex, UV, 0).a;

    float total         = centerColor;
    float totalWeight   = 1.0;

	const int r = 2;
	for(int y = -r; y <= r; ++y) {
		for(int x = -r; x <= r; ++x) {
			ivec2 p = UV + ivec2(x, y);

			if(x == 0 && y == 0)
				continue;

            bool valid          = all(greaterThanEqual(p, ivec2(0))) && all(lessThan(p, ivec2(viewSize)));

            if (!valid) continue;

            vec4 currentData    = FetchGbuffer(p);

            float currentColor  = texelFetch(tex, clampTexelPos(p), 0).a;

            float w         = 1.0;

            float distDepth = abs(centerData.a - currentData.a);

                w *= pow(max(0.0, dot(centerData.rgb, currentData.rgb)), 2);
                w *= exp(-distDepth);

            //accumulate stuff
            total       += currentColor * w;

            totalWeight += w;
        }
    }

    //compensate for total sampling weight
    total /= totalWeight;

    return total;
}


void main() {
    vec2 lowresCoord    = uv / indirectResScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
    indirectCurrent     = clamp16F(stex(colorSampler));

    if (saturate(lowresCoord) == lowresCoord) {
        indirectCurrent.a = clamp16F(SpatialBlur(colorSampler, uv));
        indirectCurrent.rgb *= indirectCurrent.a;
    }
}