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

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 data0;
layout(location = 1) out vec4 lpv;

#define shadowmapTextureMipBias 0   //[1 2 3 4]

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/shadowconst.glsl"

in voxelOut {
    flat int isVoxel;
    flat int emission;
    flat int voxelType;

    vec2 midUV;
    vec2 minUV;
    vec2 maxUV;
    flat uvec2 packedAtlasData;
} voxelIn;

in geoOut {
    flat int matID;

    float warp;

    vec2 UV;

    vec3 tint;
    vec3 scenePos;
} geoIn;

#define gSHADOW

uniform sampler2D tex;

uniform sampler2D noisetex;

uniform sampler2D shadowcolor1;

uniform int blockEntityId;

uniform float frameTimeCounter;

uniform ivec2 atlasSize;

uniform vec3 cameraPosition;
uniform vec3 lightDir;


/* ------ VOXELS ------ */

vec4 emissionColor(vec3 albedo, float alpha) {
    if (voxelIn.emission == 0) return vec4(albedo, alpha);

    float lum   = getLuma(albedo);

    float albedoLum = mix(avgOf(albedo), maxOf(albedo), 0.71);
        albedoLum   = saturate(albedoLum * sqrt2);

    float emitterLum = saturate(mix(sqr(albedoLum), sqrt(maxOf(albedo)), albedoLum) * sqrt2);

    return vec4(mix(sqr(normalizeSafe(albedo)), normalizeSafe(albedo), (emitterLum)) * emitterLum, alpha);
}

vec4 getAlbedoAverage(vec3 tint) {
    vec4 totalAlbedo    = vec4(0);

    if (geoIn.matID == 102) return vec4(vec3(0.4, 0.7, 1.0) * 0.71, 1.0);

    bool smallEmitter   = voxelIn.voxelType == 2 && voxelIn.emission > 0;

    int atlasMipmapLevel = smallEmitter ? 0 : textureQueryLevels(tex)-1;
    //atlasMipmapLevel = 0;
    
    totalAlbedo         = textureLod(tex, smallEmitter ? voxelIn.minUV : voxelIn.midUV, atlasMipmapLevel);
    totalAlbedo.rgb     = srgbToPipelineAlbedo(totalAlbedo.rgb * tint);

    float alpha         = totalAlbedo.a;

    totalAlbedo         = emissionColor(totalAlbedo.rgb, totalAlbedo.a);

    //const vec2 edgeOffset = vec2(1.0 / 16.0, 1.0 - (2.0 / 16.0));

    if (totalAlbedo.a < 0.1) {        
        for (uint x = 0; x <= VOXEL_COLOR_SAMPLES; ++x) {
            for (uint y = 0; y <= VOXEL_COLOR_SAMPLES; ++y) {
                float Xlerp     = saturate(float(x) / VOXEL_COLOR_SAMPLES) * 0.8 + 0.1;
                float Ylerp     = saturate(float(y) / VOXEL_COLOR_SAMPLES) * 0.8 + 0.1;
                vec2 uv     = vec2(mix(voxelIn.minUV.x, voxelIn.maxUV.x, Xlerp), mix(voxelIn.minUV.y, voxelIn.maxUV.y, Ylerp));

                vec4 tapSample  = textureLod(tex, uv, atlasMipmapLevel);
                alpha          += tapSample.a;
                tapSample.rgb   = srgbToPipelineAlbedo(tapSample.rgb * tint);
                tapSample       = emissionColor(tapSample.rgb, tapSample.a);
                totalAlbedo    += tapSample;
            }
        }
        //totalAlbedo = vec4(1.0, 0.0, 0.0, 1.0);
    }
    
    totalAlbedo /= max(totalAlbedo.a, 1e-8);

    if (alpha < 0.1) return vec4(1,1,1,0);

    if (voxelIn.voxelType == 3) totalAlbedo.rgb = normalizeSafe(totalAlbedo.rgb);

    return saturate(vec4(totalAlbedo.rgb, alpha));
    
}

void main() {
    lpv     = clamp16F(texelFetch(shadowcolor1, ivec2(floor(gl_FragCoord.xy)), 0));

    if (blockEntityId == 10201) discard;

    vec4 albedo     = getAlbedoAverage(geoIn.tint.rgb);
    if (albedo.a < 0.1) discard;
    data0   = vec4(pack2x8(albedo.xy), pack2x8(albedo.z, 1.0), pack2x8(ivec2(voxelIn.emission, voxelIn.voxelType)), float(voxelIn.voxelType > 0));
    //data0   = vec4(vec2(voxelIn.packedAtlasData) / 65535.0, pack2x8(ivec2(voxelIn.emission, voxelIn.voxelType)), packColor16(geoIn.tint.rgb));
}