/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 sceneColor;

#include "/lib/head.glsl"

in vec2 uv;

uniform sampler2D colortex4;

uniform sampler2D noisetex;

uniform int worldTime;

uniform vec2 taaOffset;

flat in vec3 sunDir;

uniform vec4 daytime;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferModelView;

#define FUTIL_ROT2
#include "/lib/fUtil.glsl"

#include "/lib/util/bicubic.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/project.glsl"

#include "/lib/frag/noise.glsl"

vec3 skyStars(vec3 worldDir) {
    vec3 plane  = worldDir/(worldDir.y+length(worldDir.xz)*0.66);
    float rot   = worldTime*rcp(2400.0);
    plane.x    += rot*0.6;
    plane.yz    = rotatePos(plane.yz, (25.0/180.0)*pi);
    vec2 uv1    = floor((plane.xz)*768)/768;
    vec2 uv2    = (plane.xz)*0.04;

    vec3 starcol = vec3(0.3, 0.78, 1.0);
        starcol  = mix(starcol, vec3(1.0, 0.7, 0.6), noise2D(uv2).x);
        starcol  = normalize(starcol)*(noise2D(uv2*1.5).x+1.0);

    float star  = 1.0;
        star   *= noise2D(uv1).x;
        star   *= noise2D(uv1+0.1).x;
        star   *= noise2D(uv1+0.26).x;

    star        = max(star-0.25, 0.0);
    star        = saturate(star*4.0);

    return star*starcol*0.25*sqrt(daytime.w);
}

vec3 sunDisk(vec3 Direction) {
    float sun   = dot(Direction, sunDir);

    const float size = 0.00003;
    float maxsize = size + 0.00001;
        maxsize  += linStep(sunDir.y, -0.04, 0.04)*0.004;

    float s   = linStep(sun, 0.9997 - linStep(sunDir.y, -0.04, 0.04)*0.0003, 0.9999);
        //s    *= 1.0-sstep(sun, 0.004, 0.0059)*0.5;

    float limb = 1.0 - cube(linStep(sun, 0.0, maxsize))*0.8;
        //s    *= limb;

        return s * sunIllum * 1e2;
}

void main() {
    vec3 position   = vec3(uv / ResolutionScale, 1.0);
        position    = screenToViewSpace(position);
        position    = viewToSceneSpace(position);

    vec3 direction  = normalize(position);

    vec3 transmittance = texture(colortex4, projectSky(direction, 2)).rgb;

    sceneColor      = texture(colortex4, projectSky(direction, 0)).rgb;
    if (direction.y > -0.1) sceneColor += (skyStars(direction) + sunDisk(direction)) * sstep(direction.y, -0.1, 0.0) * transmittance;

    //sceneColor  = texture(colortex3, uv).rgb;
}