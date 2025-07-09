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

int remapShapeID(int mcEntity) {        // Eight Bits
    int blockID     = 1;    // Generic Block

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
     || mcEntity == 1039) blockID = 0; // Un-voxelisable

    if (mcEntity == 1020
     || mcEntity == 1021
     || mcEntity == 1022
     || mcEntity == 1060
     || mcEntity == 1004
     || mcEntity == 1005
     || mcEntity == 1006
     || mcEntity == 1007
     || mcEntity == 1052
     || mcEntity == 1053) blockID = 2;  // Generic Non-Cubic Emitters

    if (mcEntity == 1100
     || mcEntity == 10003) blockID = 3;  // Absorbing Translucents

    if (mcEntity == 1031
     || mcEntity == 1008
     || mcEntity == 1009
     || mcEntity == 10002) blockID = 4;  // Bottom Slabs
    if (mcEntity == 1032) blockID = 5;  // Top Slabs

    if (mcEntity == 1030) blockID = 0;  // Pressure Plates

    if (mcEntity == 1033) blockID = 0;  // Carpets

    if (mcEntity == 1080) blockID = 8;  // Paths
    if (mcEntity == 1300) blockID = 9;  // Cacti
    
    /*
    if (mcEntity == 1020
     || mcEntity == 1021
     || mcEntity == 1022) blockID = 10; // Torch-esque
    if (mcEntity == 1004
     || mcEntity == 1005
     || mcEntity == 1006
     || mcEntity == 1007
     || mcEntity == 1052
     || mcEntity == 1053) blockID = 11; // Small Emitters (Lower-Half shifted small cube as approximated shape)
     */

    if (mcEntity == 1060) blockID = 20; // End Rod Up-Down
    if (mcEntity == 1061) blockID = 21; // End Rod East-West
    if (mcEntity == 1062) blockID = 22; // End Rod North-South

    if (mcEntity == 1034) blockID = 23; // Trapdoor Bottom
    if (mcEntity == 1035) blockID = 24; // Door East Closed
    if (mcEntity == 1036) blockID = 25; // Door West Closed
    if (mcEntity == 1037) blockID = 26; // Door South Closed
    if (mcEntity == 1038) blockID = 27; // Door North Closed
    if (mcEntity == 1039) blockID = 28; // Trapdoor Top

    if (mcEntity == 10001) blockID = 40; // Water

    if (mcEntity == 1200) blockID = 60; // Stairs (north, bottom, straight)
    if (mcEntity == 1201) blockID = 61; // Stairs (south, bottom, straight)
    if (mcEntity == 1202) blockID = 62; // Stairs (east,  bottom, straight)
    if (mcEntity == 1203) blockID = 63; // Stairs (west,  bottom, straight)
    if (mcEntity == 1204) blockID = 64; // Stairs (north, top, straight)
    if (mcEntity == 1205) blockID = 65; // Stairs (south, top, straight)
    if (mcEntity == 1206) blockID = 66; // Stairs (east,  top, straight)
    if (mcEntity == 1207) blockID = 67; // Stairs (west,  top, straight)
    if (mcEntity == 1208) blockID = 68; // Stairs (bottom, outer_northeast)
    if (mcEntity == 1209) blockID = 69; // Stairs (bottom, outer_southeast)
    if (mcEntity == 1210) blockID = 70; // Stairs (bottom, outer_northwest)
    if (mcEntity == 1211) blockID = 71; // Stairs (bottom, outer_southwest)
    if (mcEntity == 1212) blockID = 72; // Stairs (top, outer_northeast)
    if (mcEntity == 1213) blockID = 73; // Stairs (top, outer_southeast)
    if (mcEntity == 1214) blockID = 74; // Stairs (top, outer_northwest)
    if (mcEntity == 1215) blockID = 75; // Stairs (top, outer_southwest)
    if (mcEntity == 1216) blockID = 76; // Stairs (bottom, inner_northeast)
    if (mcEntity == 1217) blockID = 77; // Stairs (bottom, inner_southeast)
    if (mcEntity == 1218) blockID = 78; // Stairs (bottom, inner_northwest)
    if (mcEntity == 1219) blockID = 79; // Stairs (bottom, inner_southwest)
    if (mcEntity == 1220) blockID = 80; // Stairs (top, inner_northeast)
    if (mcEntity == 1221) blockID = 81; // Stairs (top, inner_southeast)
    if (mcEntity == 1222) blockID = 82; // Stairs (top, inner_northwest)
    if (mcEntity == 1223) blockID = 83; // Stairs (top, inner_southwest)

    return blockID;
}

int remapEmissionID(int mcEntity) {     // Eight Bits
    int blockID     = 0;

    /* Albedo Tinted Emission */
    if (mcEntity == 1000
     || mcEntity == 1004) blockID = 1;  // Bright Block Emitters

    if (mcEntity == 1001
     || mcEntity == 1005) blockID = 2;  // Medium Block Emitters

    if (mcEntity == 1002
     || mcEntity == 1006
     || mcEntity == 1008) blockID = 3;  // Dim Block Emitters

    if (mcEntity == 1003
     || mcEntity == 1007) blockID = 4;  // Very Dim Block Emitters

    if (mcEntity == 1009) blockID = 5;  // Very,very Dim Block Emitters

    #ifdef ConretePowderEmission
    if (mcEntity == 1025) blockID = 2;
    #endif

    /* Hardcoded Emission Types */
    if (mcEntity == 1020) blockID = 10;  // Torchlight
    if (mcEntity == 1021) blockID = 11;  // Redstone Torch
    if (mcEntity == 1022
     || mcEntity == 1051) blockID = 12;  // Soullight
    if (mcEntity == 1023) blockID = 13;  // Fire
    if (mcEntity == 10002) blockID = 14; // lava
    if (mcEntity == 1060
     || mcEntity == 1061
     || mcEntity == 1062) blockID = 20;  // End Rod
    if (mcEntity == 1052) blockID = 21;  // Amethyst
    if (mcEntity == 1053) blockID = 22;  // Amethyst
    if (mcEntity == 1054) blockID = 23;  // Generic Sculk

    return blockID;
}