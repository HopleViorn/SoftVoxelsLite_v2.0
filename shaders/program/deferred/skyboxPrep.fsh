/* RENDERTARGETS: 4 */
layout(location = 0) out vec3 skyCapture;

#include "/lib/head.glsl"

in vec2 uv;

flat in vec3 airIlluminance;
flat in mat2x3 celestialLight;
flat in mat2x3 airIllumMod;

flat in vec3 sunDir;
flat in vec3 moonDir;

uniform float aspectRatio;
uniform float eyeAltitude;

uniform vec2 viewSize, pixelSize;

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;


/* ------ includes ------ */
#include "/lib/atmos/phase.glsl"
#include "/lib/atmos/air/atmosphere.glsl"
#include "/lib/atmos/project.glsl"


void main() {
    // Original sky rendering is disabled for Shadertoy clouds integration.
    skyCapture      = vec3(0.0);

    vec2 projectionUV   = fract(uv * vec2(1.0, TILES_COUNT));

    uint index      = uint(floor(uv.y * TILES_COUNT));

    if (index == 0) {
        // Clear Sky Capture
        vec3 direction  = unprojectSky(projectionUV);

            skyCapture  = atmosphericScattering(direction, mat2x3(sunDir, moonDir), airIlluminance, airIllumMod, celestialLight);
    } else if (index == 1) {
        vec3 direction  = unprojectSky(projectionUV);

            skyCapture  = atmosphericScattering(direction, mat2x3(sunDir, moonDir), airIlluminance, airIllumMod, celestialLight);
    } else if (index == 2) {
        vec3 direction  = unprojectSky(projectionUV);

            skyCapture  = getAirTransmittance(vec3(0.0, planetRad * mix(0.9997, 1.0, saturate(sqrt(max0(sunDir.y * tau)))) + eyeAltitude, 0.0), direction);
    }

    skyCapture      = clamp16F(skyCapture);
}