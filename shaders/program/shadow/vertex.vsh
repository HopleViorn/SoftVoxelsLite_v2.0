#include "/lib/head.glsl"

attribute vec3 at_midBlock;
attribute vec4 at_tangent;
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 shadowModelViewInverse;

out vertexOut {
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
};

#include "/lib/light/idTable.glsl"

void main() {
    UV              = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    MidUV           = (gl_TextureMatrix[0] * mc_midTexCoord).xy;

    Tint            = gl_Color.rgb;

    vec4 position   = gl_Vertex;

    LocalLocation   = position.xyz;

        position    = gl_ModelViewMatrix * position;
        position    = shadowModelViewInverse * position;

    SceneLocation   = position.xyz;

    CenteredSceneLocation = position.xyz + (at_midBlock / 64.0) * 0.9;

    Normal          = gl_Normal;
    Tangent         = at_tangent;

    int mcEntity    = int(mc_Entity.x);

    voxelMode       = remapShapeID(mcEntity);
    /*
    if (mcEntity == 0
     || mcEntity == 1010
     || mcEntity == 10022
     || mcEntity == 10023
     || mcEntity == 10024
     || mcEntity == 10025
     || mcEntity == 1040
     || mcEntity == 1100
     || mcEntity == 1034
     || mcEntity == 1035
     || mcEntity == 1036
     || mcEntity == 1037
     || mcEntity == 1038
     || mcEntity == 1039
     || mcEntity == 10001
     ) voxelMode = 0;

    if (mcEntity == 1020
     || mcEntity == 1021
     || mcEntity == 1022
     || mcEntity == 1060
     || mcEntity == 1004
     || mcEntity == 1005
     || mcEntity == 1006
     || mcEntity == 1007
     || mcEntity == 1052
     || mcEntity == 1053
     ) voxelMode = 2;   // Generic Emitters    

    if (mcEntity == 1100) voxelMode = 3;    // Absorbing Translucents

    if (mcEntity == 1031 
     || mcEntity == 10002) voxelMode = 4;   // Bottom Slab
    if (mcEntity == 1032) voxelMode = 5;    // Top Slab
    if (mcEntity == 1033) voxelMode = 0;    // Carpet
    if (mcEntity == 1030) voxelMode = 0;    // Pressure Plate
    */

    weightSideFaces = 0;
    if (mcEntity == 1004
     || mcEntity == 1005
     || mcEntity == 1006
     || mcEntity == 1007
     ) weightSideFaces = 1;

    blockID         = 0;
    if (mcEntity == 10001) blockID = 102;

    emissionID      = remapEmissionID(mcEntity);
}