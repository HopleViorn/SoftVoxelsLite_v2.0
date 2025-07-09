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

/* RENDERTARGETS: 5,1,2,3 */
layout(location = 0) out vec4 sceneColor;
layout(location = 1) out vec4 GBuffer0;
layout(location = 2) out vec4 GBuffer1;
layout(location = 3) out vec4 lightingData;

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/util/encoders.glsl"
uniform vec2 viewSize;
#include "/lib/downscaleTransform.glsl"

in vec2 uv;
in vec2 lightmapUV;

flat in vec3 vertexNormal;
in vec3 ScenePosition;

in vec4 tint;

#ifdef gTERRAIN
    flat in int matID;

    uniform float frameTimeCounter;
#endif

#ifdef gTEXTURED
    uniform sampler2D gcolor;
    uniform sampler2D specular;

    #ifdef normalmapEnabled
        flat in mat3 tbn;

        uniform sampler2D normals;

        vec3 decodeNormalTexture(vec3 ntex, inout float materialAO) {
            if(all(lessThan(ntex, vec3(0.003)))) return vertexNormal;

            vec3 nrm    = ntex * 2.0 - (254.0 * rcp(255.0));

            #if normalmapFormat==0
                nrm.z  = sqrt(saturate(1.0 - dot(nrm.xy, nrm.xy)));
                materialAO = ntex.z;
            #elif normalmapFormat==1
                materialAO = length(nrm);
                nrm    = normalize(nrm);
            #endif

            return normalize(tbn * nrm);
        }
    #endif

    #ifdef gENTITY
        uniform vec4 entityColor;
    #endif
#endif

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform vec3 cameraPosition, lightDir;

#if DIM == -1
    #define LightmapColor colorPalette[2]
    flat in mat3 colorPalette;
#else
    #define LightmapColor colorPalette[3]
    flat in vec3 directColor;
    flat in mat4x3 colorPalette;
#endif

float diffuseLambert(vec3 normal, vec3 direction) {
    return saturate(dot(normal, direction));
}

#include "/lib/voxel/store.glsl"

#include "/lib/voxel/lpvSampling.glsl"


#define FUTIL_LIGHTMAP
#include "/lib/fUtil.glsl"


/*
    This offset thing is from spectrum, and zombye has it from here:
    http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
*/
vec2 R2(float n) {
	const float s0 = 0.5;
	const vec2 alpha = 1.0 / vec2(rho, rho * rho);
	return fract(n * alpha + s0);
}

uniform sampler2D noisetex;

uniform int frameCounter;

#include "/lib/frag/bluenoise.glsl"

vec4 packReflectionAux(vec3 directLight, vec3 albedo) {
    vec4 lightRGBE  = encodeRGBE8(directLight);
    vec4 albedoRGBE = encodeRGBE8(albedo);

    return vec4(pack2x8(lightRGBE.xy),
                pack2x8(lightRGBE.zw),
                pack2x8(albedoRGBE.xy),
                pack2x8(albedoRGBE.zw));
}

#if (defined gTRANSLUCENT && defined gTERRAIN)

in float viewDist;
in vec3 worldPos;

#include "/lib/util/bicubic.glsl"

#include "/lib/atmos/waterWaves.glsl"

vec3 waterNormal() {
    vec3 pos    = worldPos;

    float dstep   = 0.01 + saturate((viewDist) / 128.0);

    vec2 delta;
        delta.x     = waterWaves(pos + vec3( dstep, 0.0, -dstep), matID);
        delta.y     = waterWaves(pos + vec3(-dstep, 0.0,  dstep), matID);
        delta      -= waterWaves(pos + vec3(-dstep, 0.0, -dstep), matID);

    return normalize(vec3(-delta.x, 2.0 * dstep, -delta.y));
}

#endif

void main() {
    if (OutsideDownscaleViewport()) discard;
    vec3 sceneNormal    = vertexNormal;
    vec4 sceneMaterial  = vec4(0.0);
    float occlusion     = 1.0;

    #ifndef gTERRAIN
    const int matID     = 1;
    #endif

    #ifdef gTEXTURED
        sceneColor      = texture(gcolor, uv);
        if (sceneColor.a < 0.1) discard;

        sceneColor.rgb *= tint.rgb;

        #ifdef normalmapEnabled
        sceneNormal     = decodeNormalTexture(texture(normals, uv).rgb, occlusion);
        #endif

        #ifdef gTRANSLUCENT
        sceneColor.a    = pow(sceneColor.a, 1.0);
        sceneColor.a    = 0.1 + sqr(linStep(sceneColor.a, 0.1, 1.0)) * 0.9;
        #endif

        sceneMaterial   = texture(specular, uv);

        #ifdef gENTITY
            sceneColor.rgb = mix(sceneColor.rgb, entityColor.rgb, entityColor.a);
        #endif
    #else
        sceneColor      = tint;
        if (sceneColor.a<0.01) discard;
        sceneColor.a    = 1.0;
    #endif

    sceneColor.rgb      = srgbToPipelineColor(sceneColor.rgb);

    #if (defined gTRANSLUCENT && defined gTERRAIN)
        if (matID == 102) {
            #ifdef customWaterNormals
            sceneNormal     = waterNormal();
            #endif

            #ifdef customWaterColor
                float textureAlpha = cube(sceneColor.a);
                sceneColor.rgb = vec3(waterRed, waterGreen, waterBlue)*(0.15 + textureAlpha * waterTextureBlend);
                sceneColor.a   = waterAlpha;
            #endif

            sceneMaterial   = vec4(1.0, 0.02, 0.0, 0.0);
        }
    #endif

    vec3 sceneTint      = matID == 102 ? vec3(1.0) : normalize(max(sceneColor.rgb, 1e-3));
    
    occlusion          *= sqr(tint.a) * 0.9 + 0.1;

    #if DIM != -1
        vec3 directLight    = directColor;
            directLight    *= occlusion * 0.9 + 0.1;
    #else
        const vec3 directLight = vec3(0);
    #endif

    #if DIM == 1

    vec3 indirectLight  = colorPalette[2];

    #elif DIM == -1

    vec3 indirectLight = colorPalette[0] / pi;

    #else

    vec3 indirectLight  = cube(lightmapUV.y) * colorPalette[2];
        //indirectLight  += pow6(linStep(lightmapUV.y, 0.33, 1.0)) * directColor * 0.025;
        indirectLight  += vec3(0.4, 0.6, 1.0) * 0.005;

    #endif

        indirectLight  *= occlusion;

    vec3 light  = getLight(ScenePosition + vertexNormal * 0.25);

    vec3 blockLight     = getBlocklightMap(LightmapColor, lightmapUV.x);
        blockLight     *= occlusion * float(!sceneWithinVoxelVolume(ScenePosition));
        
    if (lightmapUV.x > (15.0/16.0) || matID == 5) {
        float albedoLum = getLuma(sceneColor.rgb);
            albedoLum   = mix(cube(albedoLum), albedoLum, albedoLum);
        blockLight += LightmapColor * albedoLum;
    }

    lightingData    = packReflectionAux(directLight, sceneTint.rgb);

    sceneColor.rgb *= light + blockLight;

    GBuffer0.xy     = encodeNormal(sceneNormal);
    GBuffer0.z      = pack2x8(lightmapUV);
    GBuffer0.w      = pack2x8(sceneMaterial.zw);

    GBuffer1.x      = pack2x8(sceneMaterial.xy);
    GBuffer1.y      = pack2x8(ivec2(matID, 0));
    GBuffer1.zw     = vec2(0);
}