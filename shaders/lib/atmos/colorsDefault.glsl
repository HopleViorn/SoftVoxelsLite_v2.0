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

#ifdef cloudPass
    const float eyeAltitude = 800.0;
#else
    uniform float eyeAltitude;
#endif

uniform float rainStrength;
uniform float wetness;

uniform vec3 sunDir;
uniform vec3 moonDir;

uniform vec4 daytime;

uniform sampler2D gaux1;

flat out mat4x3 colorPalette;

#ifdef cloudPass
    #define airmassStepBias 0.4
#else
    #define airmassStepBias 0.35
#endif

#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/air/density.glsl"
#include "/lib/atmos/project.glsl"

void getColorPalette() {
    #ifdef cloudPass
        vec3 airEyePos = vec3(0.0, planetRad + 2000.0, 0.0);
    #else
        vec3 airEyePos = vec3(0.0, planetRad + eyeAltitude, 0.0);
    #endif

    colorPalette[0]  = getAirTransmittance(airEyePos, sunDir, 6) * sunIllum;

    #if !(defined cloudPass || defined skyboxPass)
        colorPalette[0] *= (1.0 - wetness * 0.75);
    #endif

    #ifdef cloudPass
        colorPalette[1]  = getAirTransmittance(airEyePos, moonDir, 6) * colorSaturation(moonIllum, 0.5);
    #else
        colorPalette[1]  = getAirTransmittance(airEyePos, moonDir, 6) * moonIllum;
    #endif
    
    #ifdef cloudPass
        colorPalette[2]  = texture(gaux1, projectSky(vec3(0.0, 1.0, 0.0), 0)).rgb * pi * 0.25;
    #else
        colorPalette[2]  = texture(gaux1, projectSky(vec3(0.0, 1.0, 0.0), 0)).rgb * pi * skylightIllum;
    #endif

    #ifdef desatRainSkylight
        colorPalette[2]   = colorSaturation(colorPalette[1], 1.0 - rainStrength * 0.8);
    #endif

    colorPalette[2] *= vec3(skylightRedMult, skylightGreenMult, skylightBlueMult);
        
    #ifndef skipBlocklight
        colorPalette[3]  = blackbody(float(blocklightBaseTemp)) * blocklightIllum * blocklightBaseMult * 1.5;
    #endif
}