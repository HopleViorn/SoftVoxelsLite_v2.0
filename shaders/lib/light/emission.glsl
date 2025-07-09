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


#define LIGHT_LAVA vec3(1.0, 0.4, 0.05)
#define LIGHT_TORCH vec3(1.0, 0.55, 0.18)
#define LIGHT_REDTORCH vec3(1.0, 0.3, 0.1)
#define LIGHT_SOUL vec3(0.26, 0.42, 1.0)
#define LIGHT_FIRE vec3(1.0, 0.45, 0.12)
#define LIGHT_ENDROD vec3(0.76, 0.35, 1.0)
#define LIGHT_AMETHYST vec3(0.55, 0.25, 1.0)
#define LIGHT_SCULK vec3(0.45, 1.0, 0.75)

vec3 getEmissionVoxel(int ID, vec3 albedo, float textureEmission) {
    albedo  = max(albedo, 1e-8);
    vec3 albedoIn   = albedo;

    #if labEmissionMode != 2
        /*
        float lum   = getLuma(albedo);

        float albedoLum = mix(avgOf(albedo), maxOf(albedo), 0.71);
            albedoLum   = saturate(albedoLum * sqrt2);

        float emitterLum = saturate(mix(sqr(albedoLum), sqrt(maxOf(albedo)), albedoLum) * sqrt2);

        #if labEmissionMode == 1
            emitterLum  = max(emitterLum, textureEmission);
        #endif

        albedo  = albedo;*/
    #else
        albedo   *= textureEmission;
    #endif

    switch (ID) {
        case 1: return albedo * 30;
        case 2: return albedo * 20;
        case 3: return albedo * 10;
        case 4: return albedo * 5;
        case 5: return albedo * 2.5;
        case 10: return LIGHT_TORCH * 15;
        case 11: return LIGHT_REDTORCH * 7;
        case 12: return LIGHT_SOUL * 10;
        case 13: return LIGHT_FIRE * 20;
        case 14: return LIGHT_LAVA * 15;
        case 20: return LIGHT_ENDROD * 15;
        case 21: return LIGHT_AMETHYST * 8;
        case 22: return LIGHT_AMETHYST * 4;
        case 23: return LIGHT_SCULK * 4;
    }

    #if labEmissionMode == 0
        return vec3(0);
    #elif labEmissionMode == 1
        return albedoIn * textureEmission * 5;
    #elif labEmissionMode == 2
        return albedo * 5;
    #endif
}

vec3 getEmissionScreenSpace(int ID, vec3 albedo, float textureEmission, inout float luma) {
    albedo  = max(albedo, 1e-8);
    vec3 albedoIn   = albedo;

    #if labEmissionMode != 2
        float lum   = getLuma(albedo);

        float albedoLum = mix(avgOf(albedo), maxOf(albedo), 0.71);
            albedoLum   = saturate(albedoLum * sqrt2);

        float emitterLum = saturate(mix(sqr(albedoLum), sqrt(maxOf(albedo)), albedoLum) * sqrt2);

        #if labEmissionMode == 1
            emitterLum  = max(emitterLum, textureEmission);
        #endif

        albedo  = mix(sqr(normalize(albedo)), normalize(albedo), sqrt(emitterLum)) * emitterLum;
    #else
        albedo   *= textureEmission;
        float emitterLum = textureEmission;
    #endif

        luma     = emitterLum;

    switch (ID) {
        case 1: return albedo * 30;
        case 2: return albedo * 20;
        case 3: return albedo * 10;
        case 4: return albedo * 5;
        case 5: return albedo * 2.5;
        case 10: return LIGHT_TORCH * 15 * emitterLum;
        case 11: return LIGHT_REDTORCH * 7 * emitterLum;
        case 12: return LIGHT_SOUL * 10 * emitterLum;
        case 13: return LIGHT_FIRE * 20 * emitterLum;
        case 14: return LIGHT_LAVA * 15 * emitterLum;
        case 20: return LIGHT_ENDROD * 15 * emitterLum;
        case 21: return LIGHT_AMETHYST * 8 * emitterLum;
        case 22: return LIGHT_AMETHYST * 4 * emitterLum;
        case 23: return LIGHT_SCULK * 4 * emitterLum;
    }

    #if labEmissionMode == 0
        return vec3(0);
    #elif labEmissionMode == 1
        return albedoIn * textureEmission * 5;
    #elif labEmissionMode == 2
        return albedo * 5;
    #endif
}