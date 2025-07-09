/*
const bool shadowcolor1Clear  = false;
*/

layout(location = 0) out vec4 data0;
layout(location = 1) out vec4 lpvImage;

#include "/lib/head.glsl"
#include "/lib/shadowconst.glsl"
#include "/lib/util/encoders.glsl"

uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform float lightFlip;
uniform float sunAngle;

flat in mat4x3 colorPalette;

uniform vec3 lightDir;

#include "/lib/voxel/store.glsl"

in vec2 uv;

#include "/lib/light/emission.glsl"

bool getVoxelOccupancy(vec4 voxel) {
    ivec2 voxelID = unpack2x8I(voxel.z);

    return unpack4x4(voxel.a).x > 0.5 && voxelID.y <= 1;
}
bool getVoxelOccupancyTransparent(vec4 voxel) {
    ivec2 voxelID = unpack2x8I(voxel.z);

    return unpack4x4(voxel.a).x > 0.5 && (voxelID.y <= 1 || voxelID.y == 3);
}
vec3 getVoxelTint(vec4 voxel) {
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));

    return unpack4x4(voxel.a).x > 0.5 ? albedo.rgb : vec3(1.0);
}


vec3 getVoxelEmission(ivec3 index) {
    ivec2 uv    = getVoxelPixel(index);

    vec4 voxel  = texelFetch(shadowcolor0, uv, 0);
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));
    ivec2 voxelID = unpack2x8I(voxel.z);

    return getEmissionVoxel(voxelID.x, albedo.rgb, 0.0);
}
vec3 getVoxelEmission(vec4 voxel) {
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));
    ivec2 voxelID = unpack2x8I(voxel.z);

    return getEmissionVoxel(voxelID.x, albedo.rgb, 0.0);
}

vec3 getSkylightInjection(ivec3 index) {
    if (index.y != (volumeDepth - 1)) {
        return vec3(0.0);
    } else {
        ivec2 uv    = getVoxelPixel(index);

        vec4 voxel  = texelFetch(shadowcolor0, uv, 0);

        return vec3(0.6, 0.85, 1.0) * float(voxel.a < 0.1) * tau;
    }
}

#include "/lib/voxel/trace.glsl"

vec3 PTDirectLight(vec3 scenePos) {
    vec3 totalColor     = vec3(0.0);

    vec3 directCol      = (sunAngle<0.5 ? colorPalette[0] : colorPalette[1]) * lightFlip;

    vec3 startPos      = vec3(sceneToVoxelIndexNoCam(scenePos) + vec3(0.5));
    ivec3 startVoxel    = ivec3(startPos);

    for (uint i = 0; i < PT_SPP; ++i) {
        vec3 voxelPos       = vec3(startPos);
        ivec3 voxelIndex    = startVoxel;

        vec3 direction   = lightDir;

        vec3 contribution = vec3(1);

        bool hit        = false;
        vec4 voxel  = vec4(0);
        vec3 hitNormal = vec3(0,0,1);

        hit         = marchBVH(voxelPos, voxelIndex, direction, voxelPos, hitNormal, voxelIndex, voxel, contribution);
        //hit         = marchVoxel(voxelPos, voxelIndex, direction, 128, voxelPos, hitNormal, voxelIndex);

        if (!hit) {
            totalColor           += directCol * contribution;
        }
    }

    #ifndef LPV_MULTIPASS_PROPAGATION
    totalColor /= pi;
    #endif

    return totalColor / pi / PT_SPP;
}

bool isSunlightVoxel(vec3 scenePos, out vec4 hitVoxel) {
    scenePos += -ceil(abs(lightDir)) * sign(lightDir);

    hitVoxel    = texelFetch(shadowcolor0, getVoxelPixel(sceneToVoxelIndexNoCam(scenePos)), 0);

    return getVoxelOccupancyTransparent(hitVoxel);
}

uniform int WorldTimeChange;

void main() {
    ivec2 pixelUV   = ivec2(floor(gl_FragCoord.xy));

    data0           = texelFetch(shadowcolor0, pixelUV, 0);

    ivec3 voxelIndex        = uvToVoxelIndex(pixelUV);

    if (!outsideVoxelVolume(voxelIndex)) {
        lpvImage        = vec4(0);

        vec3 scenePos           = voxelToSceneSpace(voxelIndex) + vec3(0.5);
        vec3 velocity           = vec3(floor(cameraPosition) - floor(previousCameraPosition));
        vec3 previousScenePos   = (scenePos + velocity);
        ivec3 previousIndex     = sceneToVoxelIndexNoCam(previousScenePos);
        ivec2 previousUV        = getVoxelPixel(previousIndex);

        vec4 history            = clamp16F(texelFetch(shadowcolor1, previousUV, 0));

        if (previousUV == ivec2(-1)) history = vec4(0);

        if (clamp16F(history) != history) history = vec4(0);

        #ifndef DIM
        if (WorldTimeChange == 1) history = vec4(0);
        #endif

        history.rgb += getVoxelEmission(data0);

        vec4 hitVoxel;

        #if DIM != -1
        if (isSunlightVoxel(scenePos, hitVoxel) && !getVoxelOccupancy(data0)) history.rgb += PTDirectLight(scenePos) * getVoxelTint(hitVoxel);
        #endif

        lpvImage    = clamp16F(history);
    } else {
        lpvImage    = vec4(0,0,0,0);
    }
}