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

const float kernelW_3x3[9]  = float[9](
    0.0625, 0.125, 0.0625,
    0.125,  0.250, 0.125,
    0.0625, 0.125, 0.0625
);

const ivec2 kernelO_3x3[9]  = ivec2[9](
    ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
    ivec2(-1, 0),  ivec2(0, 0),  ivec2(1, 0),
    ivec2(-1, 1),  ivec2(0, 1),  ivec2(1, 1)
);

const float kernelW_5x5[25] = float[25] (
  0.0038, 0.0150, 0.0238, 0.0150, 0.0038,
  0.0150, 0.0599, 0.0949, 0.0599, 0.0150,
  0.0238, 0.0949, 0.1503, 0.0949, 0.0238,
  0.0150, 0.0599, 0.0949, 0.0599, 0.0150,
  0.0038, 0.0150, 0.0238, 0.0150, 0.0038
);

const ivec2 kernelO_5x5[25] = ivec2[25] (
    ivec2(2,  2), ivec2(1,  2), ivec2(0,  2), ivec2(-1,  2), ivec2(-2,  2),
    ivec2(2,  1), ivec2(1,  1), ivec2(0,  1), ivec2(-1,  1), ivec2(-2,  1),
    ivec2(2,  0), ivec2(1,  0), ivec2(0,  0), ivec2(-1,  0), ivec2(-2,  0),
    ivec2(2, -1), ivec2(1, -1), ivec2(0, -1), ivec2(-1, -1), ivec2(-2, -1),
    ivec2(2, -2), ivec2(1, -2), ivec2(0, -2), ivec2(-1, -2), ivec2(-2, -2)
);