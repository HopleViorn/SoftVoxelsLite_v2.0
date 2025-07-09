#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

layout (triangles) in;

layout (points, max_vertices = 1) out;
const int maxVerticesOut    = 1;

in vertexOut {
    flat int voxelMode;
    flat int blockID;
    flat int emissionID;
    flat int weightSideFaces;

    vec2 UV;
    vec2 MidUV;

    vec3 Tint;
    vec3 LocalLocation;
    vec3 SceneLocation;
    vec3 CenteredSceneLocation;
    flat vec3 Normal;

    flat vec4 Tangent;
} vertexIn[3];

uniform ivec2 atlasSize;

uniform vec3 cameraPosition;

uniform mat4 shadowModelViewInverse;

#include "/lib/light/warp.glsl"

out voxelOut {
    flat int isVoxel;
    flat int emission;
    flat int voxelType;

    vec2 midUV;
    vec2 minUV;
    vec2 maxUV;
    flat uvec2 packedAtlasData;
};

out geoOut {
    flat int matID;

    float warp;

    vec2 UV;

    vec3 tint;
    vec3 scenePos;
};

#define NO_OCCUPANCY

#include "/lib/voxel/store.glsl"

struct atlasData {
    vec2 tileIndexFraction; //2x8 bits
    vec2 tileIndexFloored;  //2x4 bits
    float tileRes;          //4 bits
};

uvec2 packAtlasData(atlasData data) {
    return uvec2(pack2x8UI(data.tileIndexFraction),
                 pack2x8UI(vec2(encode2x4Unorm(data.tileIndexFloored), data.tileRes)));
}

void main() {

    if (vertexIn[0].voxelMode == 0) return;

    /* ATLAS UVS */

    vec2 midCoord   = vertexIn[0].MidUV;
    vec3 bitangent  = cross(vertexIn[0].Tangent.xyz, vertexIn[0].Normal) * (vertexIn[0].Tangent.w < 0.0 ? -1.0 : 1.0);
    vec3 vertPosU   = vertexIn[0].Tangent.xyz * mat3(vertexIn[0].LocalLocation, vertexIn[1].LocalLocation, vertexIn[2].LocalLocation);
    vec3 vertPosV   = bitangent * mat3(vertexIn[0].LocalLocation, vertexIn[1].LocalLocation, vertexIn[2].LocalLocation);

    vec2 faceSize   = vec2(maxOf(vertPosU) - minOf(vertPosU), maxOf(vertPosV) - minOf(vertPosV));
        faceSize   /= vec2(length(vertexIn[0].Tangent.xyz), length(bitangent));

    vec2 minCoord   = min(min(vertexIn[0].UV, vertexIn[1].UV), vertexIn[2].UV);
    vec2 maxCoord   = max(max(vertexIn[0].UV, vertexIn[1].UV), vertexIn[2].UV);
    vec2 tileSize   = abs(maxCoord - minCoord) / faceSize;
    vec2 tileRes    = round(tileSize * atlasSize);

    ivec2 tileIndex = ivec2(vertexIn[0].MidUV / tileSize);

    atlasData atlasUV   = atlasData(fract(tileIndex / 256.0) * 256.0 / 255.0,
                                        floor(tileIndex / 256.0) / 15.0,
                                        log2(maxOf(tileRes)) / 15.0);

    uvec2 atlasTemp     = packAtlasData(atlasUV);

    /* GEO STUFF */

    vec3 avgTint    = vertexIn[0].Tint;

    vec3 normal     = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * vertexIn[0].Normal);

    float normalBias = 0.5 - 0.25 * normal.y;

    vec3 triangleBoundsMin  = min(vertexIn[0].CenteredSceneLocation, min(vertexIn[1].CenteredSceneLocation, vertexIn[2].CenteredSceneLocation));
    vec3 triangleBoundsMax  = max(vertexIn[0].CenteredSceneLocation, max(vertexIn[1].CenteredSceneLocation, vertexIn[2].CenteredSceneLocation));

    vec3 triangleMidLocation = (triangleBoundsMin + triangleBoundsMax) * 0.5;

    ivec3 voxelIndex     = sceneToVoxelIndex(triangleMidLocation);
        //voxelIndex     += ivec3(1, 0, 1);

    int isEmissive      = vertexIn[0].emissionID;

    if (!outsideVoxelVolume(voxelIndex)) {
        vec2 texelCoord     = vec2(getVoxelUV(voxelIndex));
            texelCoord      = texelCoord * 2.0 - 1.0;

            isVoxel         = 1;
            emission        = isEmissive;
            midUV           = midCoord;
            minUV           = minCoord;
            maxUV           = maxCoord;
            tint            = avgTint;
            voxelType       = vertexIn[0].voxelMode;
            packedAtlasData = atlasTemp;
            matID           = vertexIn[0].blockID;

            gl_Position     = vec4(texelCoord, normalBias, 1.0);

        EmitVertex();
        EndPrimitive();
    } else {
        return;
    }

}