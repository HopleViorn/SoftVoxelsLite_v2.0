#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

layout(location = 0) out vec4 data0;
layout(location = 1) out vec4 data1;

in vec2 uv;

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform vec3 cameraPosition;

#include "/lib/voxel/store.glsl"

const ivec3 sampleOffsets[8] = ivec3[8](
    ivec3(0, 0, 0), ivec3(1, 0, 0), ivec3(0, 0, 1), ivec3(1, 0, 1),
    ivec3(0, 1, 0), ivec3(1, 1, 0), ivec3(0, 1, 1), ivec3(1, 1, 1)
);

void main() {
    data0   = stex(shadowcolor0);   // Pass through shadowmap data, RENDERTARGETS doesn't seem to work here
    data1   = stex(shadowcolor1);

    vec4 bvhLevels  = unpack4x4(data0.a);

    const int size  = int(pow(2, CURR_LEVEL));
    const int size1  = int(pow(2, CURR_LEVEL-1));

    vec2 lodUV  = uv * vec2(size, (size));

    if (lodUV.y <= 1.0 && lodUV.x <= 1.0) {

        ivec3 index     = uvToVoxelIndex(ivec2(floor(gl_FragCoord.xy)), CURR_LEVEL);

        bool anyVoxel   = false;

        for (int i = 0; i < 8; i++) {
            ivec3 offset    = sampleOffsets[i];

            if (getVoxelOccupancy((index * 2 + offset) * size1, CURR_LEVEL - 1)) {   // Read from one level above the current one
                anyVoxel    = true;
                break;
            }
        }

        #if CURR_LEVEL == 1
            bvhLevels.y = float(anyVoxel);
        #elif CURR_LEVEL == 2
            bvhLevels.z = float(anyVoxel);
        #elif CURR_LEVEL == 3
            bvhLevels.w = float(anyVoxel);
        #endif
    }

    data0.a     = pack4x4(saturate(bvhLevels));
}