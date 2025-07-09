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

const float indirectResScale = sqrt(1.0 / indirectResReduction);
const float reflectionResScale = sqrt(1.0 / reflectionResReduction);

const int shadowMapResolution = 2048; 	//[512 1024 2048 4096 8192]

#define cloudShadowmapRenderDistance 8e3
#define cloudShadowmapResolution 512

const int noiseTextureResolution = 256;

const int voxelMapRes = int(shadowMapResolution * MC_SHADOW_QUALITY);
const int shadowMapRes = int(shadowMapResolution * MC_SHADOW_QUALITY);

#ifndef DIM
    #define generateShadowmap
#endif

#define blocklightBaseMult sqrt2

#define minimumAmbientColor vec3(0.5, 0.5, 1.0)
#define minimumAmbientMult 0.008

#define OCTREE_LEVELS 4     //[1 2 3 4]
#define maxTraversalDistance 64     //[16 24 32 48 64 96 128

#define DEBUG_VIEW 0    //[0 1 2 3 4 5 6] 0-off, 1-whiteworld, 2-indirect light, 3-albedo/unlit, 4-irradiance cache, 5-hdr

#define ResolutionScale 0.75     //[0.25 0.5 0.75 1.0]