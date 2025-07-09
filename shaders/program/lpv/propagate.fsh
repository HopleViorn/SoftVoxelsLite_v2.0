layout(location = 0) out vec4 data0;
layout(location = 1) out vec4 lpvImage;

#include "/lib/head.glsl"
#include "/lib/shadowconst.glsl"
#include "/lib/util/encoders.glsl"

uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

#include "/lib/voxel/store.glsl"

in vec2 uv;

#include "/lib/light/emission.glsl"

vec3 getSkylightInjection(ivec3 index) {
    if (index.y != (volumeDepth - 1)) {
        return vec3(0.0);
    } else {
        ivec2 uv    = getVoxelPixel(index);

        vec4 voxel  = texelFetch(shadowcolor0, uv, 0);

        return vec3(0.6, 0.85, 1.0) * float(voxel.a < 0.1) * tau;
    }
}

vec3 getVoxelEmission(ivec3 index) {
    //ivec2 uv    = getVoxelPixel(index);

    vec4 voxel  = texture(shadowcolor0, getVoxelUV(index), 0);
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));
    ivec2 voxelID = unpack2x8I(voxel.z);

    return getEmissionVoxel(voxelID.x, albedo.rgb, 0.0);
}
vec3 getVoxelTint(ivec3 index) {
    //ivec2 uv    = getVoxelPixel(index);

    vec4 voxel  = texture(shadowcolor0, getVoxelUV(index), 0);
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));

    return unpack4x4(voxel.a).x > 0.5 ? albedo.rgb : vec3(1.0);
}

vec3 getVoxelTint(vec4 voxel) {
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));

    return unpack4x4(voxel.a).x > 0.5 ? albedo.rgb : vec3(1.0);
}
vec3 getVoxelEmission(vec4 voxel) {
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));
    ivec2 voxelID = unpack2x8I(voxel.z);

    return getEmissionVoxel(voxelID.x, albedo.rgb, 0.0);
}
bool getVoxelOccupancy(vec4 voxel) {
    ivec2 voxelID = unpack2x8I(voxel.z);

    return unpack4x4(voxel.a).x > 0.5 && voxelID.y <= 1;
}

vec3 readLPV(ivec3 index) {
    return clamp16F(texture(shadowcolor1, getVoxelUV(index), 0).rgb);
}

vec3 lpvPropagation(ivec3 index, vec4 voxel) {
    vec3 irradiance     = readLPV(index);
    vec3 taps           = vec3(1);

    //return irradiance;

    //bool occupance      = getVoxelOccupancy(index);

    const ivec3[6] directions = ivec3[6] (ivec3(1,0,0),  ivec3(0,1,0),  ivec3(0,0,1),
                                          ivec3(-1,0,0), ivec3(0,-1,0), ivec3(0,0,-1));

    const float blurStrength    = 1.0;

    for (uint i = 0; i < 6; ++i) {
        //bool tapOccupance = getVoxelOccupancy(index + directions[i]);
        //if (!tapOccupance) continue;
        ivec3 tapIndex  = index + directions[i];

        vec3 tapAlbedo  = vec3(1.0) * blurStrength;

        irradiance += readLPV(tapIndex) * tapAlbedo;
        taps += tapAlbedo;
    }

    return (irradiance / max(taps, 1e-16)) * getVoxelTint(voxel);
}

#ifdef LPV_MULTIPASS_PROPAGATION
 /* - */
#endif


void main() {
    ivec2 pixelUV   = ivec2(floor(gl_FragCoord.xy));

    data0           = texelFetch(shadowcolor0, pixelUV, 0);

    ivec3 voxelIndex        = uvToVoxelIndex(pixelUV);

    if (!outsideVoxelVolume(voxelIndex)) {
        lpvImage        = vec4(0);

        vec4 voxel              = data0;

        vec3 irradiance         = getVoxelOccupancy(voxel) ? getVoxelEmission(voxel) : lpvPropagation(voxelIndex, voxel);
        // doing emission of the voxel before the propagation seems to mitigate harsh contrast issues between voxels when interpolating
        //vec3 emission           = getVoxelEmission(voxelIndex);

        #ifndef LAST
        irradiance += getVoxelEmission(voxel);
        //irradiance = max(irradiance, getSkylightInjection(voxelIndex));
        #endif

        lpvImage    = clamp16F(vec4(irradiance, 1.0));
    } else {
        lpvImage    = vec4(0,0,0,0);
    }
}