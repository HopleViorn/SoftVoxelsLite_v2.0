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
    Voxel Structure based on Superscalar by Bobcao3
*/

#define VX_MAX_WIDTH 256    //[32 64 128 256 512]
#define VX_MAX_DEPTH 256    //[32 64 128 256 512]

const int volumeWidth = min(voxelMapRes / 16, VX_MAX_WIDTH);
const int volumeHeight = volumeWidth;

const int voxelmapResolution = voxelMapRes;
const ivec2 voxelSegmentEdge = ivec2(voxelmapResolution, voxelmapResolution) - 1;

const int volumeDepthGridSize = (voxelmapResolution / volumeWidth);

const int volumeDepth = min(VX_MAX_DEPTH, ((voxelmapResolution / volumeWidth) * (voxelmapResolution / volumeHeight)));

ivec3 sceneToVoxelIndex(vec3 scenePos) {
    return ivec3(floor(scenePos + fract(cameraPosition))) + ivec3(volumeWidth, volumeDepth, volumeHeight) / 2;
}
ivec3 sceneToVoxelIndexNoCam(vec3 scenePos) {
    return ivec3(floor(scenePos)) + ivec3(volumeWidth, volumeDepth, volumeHeight) / 2;
}
vec3 voxelToSceneSpace(ivec3 voxelPos) {
    return vec3(voxelPos) - vec3(volumeWidth, volumeDepth, volumeHeight) / 2.0;
}
vec3 voxelToSceneSpace(vec3 voxelPos) {
    return vec3(voxelPos) - vec3(volumeWidth, volumeDepth, volumeHeight) / 2.0 - fract(cameraPosition);
}
vec3 sceneToVoxelSpace(vec3 scenePos) {
    return (scenePos + fract(cameraPosition)) + vec3(volumeWidth, volumeDepth, volumeHeight) / 2.0;
}
ivec3 voxelSpaceToIndex(vec3 voxelPos) {
    return ivec3(floor(voxelPos));
}

bool outsideVoxelVolume(ivec3 pos) {
    return pos.x < 0 || pos.x >= volumeWidth || pos.y < 0 || pos.y >= volumeDepth || pos.z < 0 || pos.z >= volumeHeight;
}
bool outsideVoxelVolume(vec3 pos) {
    return pos.x < 0 || pos.x >= volumeWidth || pos.y < 0 || pos.y >= volumeDepth || pos.z < 0 || pos.z >= volumeHeight;
}
bool sceneWithinVoxelVolume(vec3 pos) {
    return !outsideVoxelVolume(sceneToVoxelIndexNoCam(pos));
}

ivec2 getVoxelPixel(ivec3 pos) {
    if (outsideVoxelVolume(pos)) return ivec2(-1);

    ivec2 base = ivec2((pos.y % volumeDepthGridSize) * volumeWidth, (pos.y / volumeDepthGridSize) * volumeHeight);
    ivec2 uv = base + pos.xz;

    return uv;
}

vec2 getVoxelUV(vec3 pos) {
    if (outsideVoxelVolume(pos)) return ivec2(-1);

    ivec2 base = ivec2((int(pos.y) % volumeDepthGridSize) * volumeWidth, (int(pos.y) / volumeDepthGridSize) * volumeHeight);
    vec2 uv = vec2(base) + pos.xz;

    return (uv + 0.5) / voxelmapResolution;
}

ivec3 uvToVoxelIndex(ivec2 uv) {
    ivec2 y_grid = uv / ivec2(volumeWidth, volumeHeight);
    ivec2 xz_pos = uv % ivec2(volumeWidth, volumeHeight);
    ivec3 wpos = ivec3(xz_pos.x, y_grid.x + y_grid.y * volumeDepthGridSize, xz_pos.y);

    return wpos;
}

bool outsideVoxelVolume(ivec3 pos, int lod) {
    int lodFactor   = int(pow(2, lod));

    ivec3 bounds    = ivec3(volumeWidth, volumeDepth, volumeHeight) / lodFactor;
    return pos.x < 0 || pos.x >= bounds.x || pos.y < 0 || pos.y >= bounds.y || pos.z < 0 || pos.z >= bounds.z;
}
ivec2 getVoxelPixel(ivec3 pos, int lod) {
    if (outsideVoxelVolume(pos)) return ivec2(-1);

    int lodFactor   = int(pow(2, lod));

    pos    /= lodFactor;

    ivec2 bounds    = ivec2(volumeWidth, volumeDepth) / lodFactor;
    int volumeDepthGridSize = (voxelmapResolution / lodFactor) / bounds.x;

    ivec2 base = ivec2((pos.y % volumeDepthGridSize) * bounds.x, (pos.y / volumeDepthGridSize) * bounds.x);
    ivec2 UV = base + pos.xz;

    return UV;
}
vec2 getVoxelUV(ivec3 pos, int lod) {
    if (outsideVoxelVolume(pos)) return ivec2(-1);

    int lodFactor   = int(pow(2, lod));

    pos    /= lodFactor;

    ivec2 bounds    = ivec2(volumeWidth, volumeDepth) / lodFactor;
    int volumeDepthGridSize = (voxelmapResolution / lodFactor) / bounds.x;

    ivec2 base = ivec2((pos.y % volumeDepthGridSize) * bounds.x, (pos.y / volumeDepthGridSize) * bounds.x);
    ivec2 UV = base + pos.xz;

    return (vec2(UV) + 0.5) / voxelmapResolution;
}
ivec3 uvToVoxelIndex(ivec2 uv, int lod) {
    int lodFactor   = int(pow(2, lod));

    ivec2 bounds    = ivec2(volumeWidth, volumeDepth) / lodFactor;
    int volumeDepthGridSize = (voxelmapResolution / lodFactor) / bounds.x;

    ivec2 YGrid = uv / ivec2(bounds.x);
    ivec2 XZPos = uv % ivec2(bounds.x);
    ivec3 wpos = ivec3(XZPos.x, YGrid.x + YGrid.y * volumeDepthGridSize, XZPos.y);

    return wpos;
}

#ifndef NO_OCCUPANCY
bool getVoxelOccupancy(ivec3 index) {
    ivec2 uv    = getVoxelPixel(index);

    vec4 voxel  = texelFetch(shadowcolor0, uv, 0);
    ivec2 voxelID = unpack2x8I(voxel.z);

    return unpack4x4(voxel.a).x > 0.5 && voxelID.y <= 1;
}
bool getVoxelOccupancy(ivec3 index, out vec4 voxel) {
    ivec2 uv    = getVoxelPixel(index);

        voxel  = texelFetch(shadowcolor0, uv, 0);
    ivec2 voxelID = unpack2x8I(voxel.z);

    return unpack4x4(voxel.a).x > 0.5;
}
bool getVoxelOccupancyScene(vec3 scenePos) {
    ivec2 uv    = getVoxelPixel(sceneToVoxelIndex(scenePos));

    vec4 voxel  = texelFetch(shadowcolor0, uv, 0);
    ivec2 voxelID = unpack2x8I(voxel.z);

    return unpack4x4(voxel.a).x > 0.5 && voxelID.y <= 1;
}

bool getVoxelOccupancy(ivec3 index, int lod) {
    ivec2 uv    = getVoxelPixel(index, lod);
    if (uv == ivec2(-1)) return false;

    vec4 bvh    = unpack4x4(texelFetch(shadowcolor0, uv, 0).a);

    return bvh[lod] > 0.5;
}

bool getVoxelOccupancy(ivec3 index, int lod, out vec4 voxel) {
    ivec2 uv    = getVoxelPixel(index, lod);
    if (uv == ivec2(-1)) return false;

    voxel       = texelFetch(shadowcolor0, uv, 0);

    vec4 bvh    = unpack4x4(voxel.a);

    return bvh[lod] > 0.5;
}
#endif