#define CLOUD_PLANE0_ENABLED
#define CLOUD_PLANE1_ENABLED
#define CLOUD_SHEET_ENABLED


#ifdef freezeAtmosAnim
    const float cloudTime   = float(atmosAnimOffset) * 0.003;
#else
    #ifdef volumeWorldTimeAnim
        float cloudTime     = worldAnimTime * 1.8;
    #else
        float cloudTime     = frameTimeCounter * 0.003;
    #endif
#endif

#define CLOUD_PLANE0_ALT    8000.0 
#define CLOUD_PLANE0_DEPTH  3000.0  //[500.0 1000.0 1500.0 2000.0 2500.0 3000.0 3500.0 4000.0 4500.0 5000.0]
#define CLOUD_PLANE0_CLIP   25e4
#define CLOUD_PLANE0_COVERAGE 0.0   //[-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]
#define CLOUD_PLANE0_SIGMA 0.002
#define CLOUD_PLANE0_DITHERED_LIGHT

const vec2 CLOUD_PLANE0_BOUNDS = vec2(
    -CLOUD_PLANE0_DEPTH * 0.4 + CLOUD_PLANE0_ALT,
     CLOUD_PLANE0_DEPTH * 0.6 + CLOUD_PLANE0_ALT
);

#define CLOUD_PLANE1_ALT    3000.0
#define CLOUD_PLANE1_DEPTH  1000.0  //[500.0 1000.0 1500.0 2000.0 2500.0 3000.0 3500.0 4000.0 4500.0 5000.0]
#define CLOUD_PLANE1_CLIP   15e4
#define CLOUD_PLANE1_COVERAGE 0.0   //[-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]
#define CLOUD_PLANE1_DITHERED_LIGHT

const vec2 CLOUD_PLANE1_BOUNDS = vec2(
    -CLOUD_PLANE1_DEPTH * 0.4 + CLOUD_PLANE1_ALT,
     CLOUD_PLANE1_DEPTH * 0.6 + CLOUD_PLANE1_ALT
);

#define CLOUD_SHEET_ALT    13000.0
#define CLOUD_SHEET_DEPTH  4000.0   //[500.0 1000.0 1500.0 2000.0 2500.0 3000.0 3500.0 4000.0 4500.0 5000.0]
#define CLOUD_SHEET_CLIP   35e4
#define CLOUD_SHEET_COVERAGE 0.0    //[-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]
#define CLOUD_SHEET_DITHERED_LIGHT

const vec2 CLOUD_SHEET_BOUNDS = vec2(
    -CLOUD_SHEET_DEPTH * 0.4 + CLOUD_SHEET_ALT,
     CLOUD_SHEET_DEPTH * 0.6 + CLOUD_SHEET_ALT
);




vec2 noise2DCubic(sampler2D tex, vec2 pos) {
        pos        *= 256.0;
    ivec2 location  = ivec2(floor(pos));

    vec2 samples[4]    = vec2[4](
        texelFetch(tex, location                 & 255, 0).xy, texelFetch(tex, (location + ivec2(1, 0)) & 255, 0).xy,
        texelFetch(tex, (location + ivec2(0, 1)) & 255, 0).xy, texelFetch(tex, (location + ivec2(1, 1)) & 255, 0).xy
    );

    vec2 weights    = cubeSmooth(fract(pos));


    return mix(
        mix(samples[0], samples[1], weights.x),
        mix(samples[2], samples[3], weights.x), weights.y
    );
}
vec3 noise2DCubic3(sampler2D tex, vec2 pos) {
        pos        *= 256.0;
    ivec2 location  = ivec2(floor(pos));

    vec3 samples[4]    = vec3[4](
        texelFetch(tex, location                 & 255, 0).xyz, texelFetch(tex, (location + ivec2(1, 0)) & 255, 0).xyz,
        texelFetch(tex, (location + ivec2(0, 1)) & 255, 0).xyz, texelFetch(tex, (location + ivec2(1, 1)) & 255, 0).xyz
    );

    vec2 weights    = cubeSmooth(fract(pos));


    return mix(
        mix(samples[0], samples[1], weights.x),
        mix(samples[2], samples[3], weights.x), weights.y
    );
}

float cloudPhaseNew(float cosTheta, vec3 asymmetry) {
    float x = mieHG(cosTheta, asymmetry.x);
    float y = mieHG(cosTheta, -asymmetry.y);
    float z = mieCS(cosTheta, asymmetry.z);

    return 0.7 * x + 0.2 * y + 0.1 * z;
}

float estimateEnergy(float ratio) {
    return ratio / (1.0 - ratio);
}

vec3 GetPlane(float Altitude, vec3 Direction) {
    return  Direction * ((Altitude - eyeAltitude) / Direction.y);
}


// ---- PLANAR 0 ---- //
uniform vec2 Cloud0Dynamics;

float cloudPlanarShape0(vec3 pos) {
    float altitude      = pos.y;
    float altRemapped = saturate((altitude - CLOUD_PLANE0_BOUNDS.x) / CLOUD_PLANE0_DEPTH);

    float erodeLow  = 1.0 - sstep(altRemapped, 0.0, 0.35);
    float erodeHigh = sstep(altRemapped, 0.42, 1.0);
    float fadeLow   = sstep(altRemapped, 0.0, 0.19);
    float fadeHigh  = 1.0 - sstep(altRemapped, 0.6, 1.0);

    vec3 wind       = vec3(cloudTime, 0.0, cloudTime*0.4);

    //pos.xz         += vec2(2e3, -4e3);
    pos.xz         /= 1.0 + distance(cameraPosition.xz, pos.xz) * 0.000006;
    pos            *= 0.00025;
    pos            += wind * 9;

    float coverage_bias = saturate(0.42 - wetness*0.15 + CLOUD_PLANE0_COVERAGE + Cloud0Dynamics.x);

    pos.xz         += noise2DCubic(noisetex, pos.xz * 0.004).xy * 1.0;

    pos.x          *= 0.66;

    float coverage  = noise2D(pos.xz*0.026).b * 0.85 + 0.15;
        coverage    = (coverage - coverage_bias) * rcp(1.0 - saturate(coverage_bias));

        coverage    = (coverage * fadeLow * fadeHigh) - erodeLow * 0.3 - erodeHigh * 0.75;

        //coverage    = saturate(coverage * 1.0);
        
    if (coverage <= 0.0) return 0.0;

    float shape     = coverage;
    float slope     = sqrt(1.0 - saturate(shape));
    
        pos.xy += shape * 1.0;
    float n1        = value3D(pos * 6.0) * 0.25;
        shape      -= n1;   pos -= n1 * 0.75;

          n1        = value3D(pos * 16.0) * 0.1;
        shape      -= n1;   pos -= n1 * 0.35;

    if (shape <= 0.0) return 0.0;

        slope      = sqrt(1.0 - saturate(shape));
        shape      -= value3D(pos * 48.0 * vec3(0.4, 1.0, 1.0)) * 0.07;

        slope      = sqrt(1.0 - saturate(shape));
        shape      -= value3D((pos + shape * 0.05) * 144.0 * vec3(2.0, 1.0, 0.1)) * 0.035;

        shape    = max0(shape);
        shape    = cubeSmooth((shape));

    return max(shape * Cloud0Dynamics.y, 0.0);
}

float cloudPlanarLight0(vec3 pos, const uint steps) {
    float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;
        
        float density = cloudPlanarShape0(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudPlanarLight0(vec3 pos, const uint steps, vec3 dir) {
    float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE0_BOUNDS.x, CLOUD_PLANE0_BOUNDS.y) * 0.9;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;
        
        float density = cloudPlanarShape0(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
#if 1
float cloudPlanarLight0(vec3 pos, const uint steps, float noise) {
    float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;
        
        float density = cloudPlanarShape0(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
#else
float cloudPlanarLight0(vec3 pos, const uint steps, float noise) {
    const float basestep = 22.0;
    const float exponent = 2.4;

    float stepsize  = basestep;
    float prevStep  = stepsize;

    //float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        pos += cloudLightDir * noise * (stepsize - prevStep);

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;

            prevStep  = stepsize;
            stepsize *= exponent;
        
        float density = cloudPlanarShape0(pos);
        if (density <= 0.0) continue;

            od += density * prevStep;
    }

    return od;
}
#endif
float cloudPlanarLight0(vec3 pos, const uint steps, vec3 dir, float noise) {
    float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE0_BOUNDS.x, CLOUD_PLANE0_BOUNDS.y) * 0.9;

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;
        
        float density = cloudPlanarShape0(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}


// ---- PLANAR 1 ---- //
uniform vec2 Cloud1Dynamics;

float cloudPlanarShape1(vec3 pos, bool light) {
    float altitude      = pos.y;
    float altRemapped = saturate((altitude - CLOUD_PLANE1_BOUNDS.x) / CLOUD_PLANE1_DEPTH);

    float erodeLow  = 1.0 - sstep(altRemapped, 0.0, 0.35);
    float erodeHigh = sstep(altRemapped, 0.42, 1.0);
    float fadeLow   = sstep(altRemapped, 0.0, 0.19);
    float fadeHigh  = 1.0 - sstep(altRemapped, 0.6, 1.0);

    vec3 wind       = vec3(cloudTime, 0.0, cloudTime*0.4);

    pos.xz         /= 1.0 + distance(cameraPosition.xz, pos.xz) * 0.000031;
    pos            *= 0.0005;
    pos            += wind * 7;

    vec3 sample0    = noise2DCubic3(noisetex, pos.xz * 0.01 + vec2(0.31, -0.16)).xyz;

    pos.xz         += sample0.xy * 0.25;

    float coverage_bias = saturate(sample0.z * 0.05 + 0.42 - wetness*0.15 + CLOUD_PLANE1_COVERAGE + Cloud1Dynamics.x);

    //pos.x          *= 0.66;

    float coverage  = noise2D(pos.xz*0.06 + vec2(-0.15, 0.78)).b;
        coverage   += noise2D(pos.xz*0.008).x * 0.5;

        coverage   /= 1.0 + 0.5;

        coverage    = (coverage - coverage_bias) * rcp(1.0 - saturate(coverage_bias));

        coverage    = (coverage * fadeLow * fadeHigh) - erodeLow * 0.26 - erodeHigh * 0.6;

        //coverage    = saturate(coverage * 1.0);
        
    if (coverage <= 0.0) return 0.0;

    float dfade     = 0.001 + sstep(altRemapped, 0.0, 0.2) * 0.1;
        dfade      += sstep(altRemapped, 0.1, 0.45) * 0.4;
        dfade      += sstep(altRemapped, 0.2, 0.60) * 0.8;
        dfade      += sstep(altRemapped, 0.3, 0.85) * 0.9;
        dfade      /= 0.001 + 0.1 + 0.4 + 0.8 + 0.9;

    float shape     = coverage;
    float slope     = sqrt(1.0 - saturate(shape));
    
        pos.xy += shape * 0.25;
    float n1        = value3D(pos * 12.0) * 0.15;
        shape      -= n1;   pos -= n1 * 1.0;

          n1        = value3D(pos * 24.0) * 0.075;
        shape      -= n1;   pos -= n1 * 1.0;

    if (shape <= 0.0) return 0.0;

        slope      = sqrt(1.0 - saturate(shape));
        shape      -= value3D(pos * 48.0) * 0.05;

        slope      = sqrt(1.0 - saturate(shape));
        //shape      -= value3D((pos + shape * 0.05) * 96.0) * 0.035;

        shape    = max0(shape);
        //shape    = cubeSmooth((shape));

        shape   = 1.0 - pow(1.0 - saturate(shape), 1.0 + altRemapped * 3.0);
        shape   = cubeSmooth(shape);

        //if (light) shape *= dfade;

    return max(shape * Cloud1Dynamics.y, 0.0);
}

float cloudPlanarLight1(vec3 pos, const uint steps, float noise) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = cloudPlanarShape1(pos, true);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudPlanarLight1(vec3 pos, const uint steps, vec3 dir, float noise) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE1_BOUNDS.x, CLOUD_PLANE1_BOUNDS.y) * 0.9;

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = cloudPlanarShape1(pos, true);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudPlanarLight1(vec3 pos, const uint steps) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = cloudPlanarShape1(pos, true);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudPlanarLight1(vec3 pos, const uint steps, vec3 dir) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE1_BOUNDS.x, CLOUD_PLANE1_BOUNDS.y) * 0.9;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = cloudPlanarShape1(pos, true);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}


// ---- PLANAR SHEET ---- //

uniform vec2 CloudSheetDynamics;

float cloudSheetShape(vec3 pos) {
    float altitude      = pos.y;
    float altRemapped = saturate((altitude - CLOUD_SHEET_BOUNDS.x) / CLOUD_SHEET_DEPTH);

    float erodeLow  = 1.0 - sstep(altRemapped, 0.0, 0.35);
    float erodeHigh = sstep(altRemapped, 0.42, 1.0);
    float fadeLow   = sstep(altRemapped, 0.0, 0.19);
    float fadeHigh  = 1.0 - sstep(altRemapped, 0.6, 1.0);

    vec3 wind       = vec3(cloudTime, 0.0, cloudTime*0.4);

    //pos.xz         += vec2(2e3, -4e3);
    pos.xz         /= 1.0 + distance(cameraPosition.xz, pos.xz) * 0.000006;
    pos            *= 0.0001;
    pos            += wind * 8 + vec3(0.7, 0, 0.3);

    float coverage_bias = saturate(0.12 + CLOUD_SHEET_COVERAGE + CloudSheetDynamics.x);

    pos.xz         += noise2DCubic(noisetex, pos.xz * 0.003).xy * 2.0;

    pos.x          *= 0.66;

    float coverage  = noise2D(pos.xz*0.015).b * 0.8 + 0.2;
        coverage    = (coverage - coverage_bias) * rcp(1.0 - saturate(coverage_bias));

        coverage    = (coverage * fadeLow * fadeHigh) - erodeLow * 0.3 - erodeHigh * 0.75;

        //coverage    = saturate(coverage * 1.0);
        
    if (coverage <= 0.0) return 0.0;

    float shape     = coverage;
    float slope     = sqrt(1.0 - saturate(shape));
    
        pos.xy += shape * 1.0;
    float n1        = value3D(pos * 4.0) * 0.25;
        shape      -= n1;   pos -= n1 * 0.5;

          n1        = value3D(pos * 16.0) * 0.1;
        shape      -= n1;   pos -= n1 * 0.5;

    if (shape <= 0.0) return 0.0;

        slope      = sqrt(1.0 - saturate(shape));
        shape      -= value3D(pos * 64.0 * vec3(0.4, 1.0, 1.0)) * 0.07;

        slope      = sqrt(1.0 - saturate(shape));
        //shape      -= value3D((pos + shape * 0.05) * 144.0 * vec3(2.0, 1.0, 0.1)) * 0.035;

        shape    = max0(shape);
        shape    = cubeSmooth(sqr(shape));

    return max(shape * CloudSheetDynamics.y, 0.0);
}

float cloudSheetLight(vec3 pos, const uint steps, float noise) {
    float stepsize = (CLOUD_SHEET_DEPTH / float(steps));

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_SHEET_BOUNDS.y || pos.y < CLOUD_SHEET_BOUNDS.x) continue;
        
        float density = cloudSheetShape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudSheetLight(vec3 pos, const uint steps, vec3 dir, float noise) {
    float stepsize = (CLOUD_SHEET_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_SHEET_BOUNDS.x, CLOUD_SHEET_BOUNDS.y) * 0.9;

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_SHEET_BOUNDS.y || pos.y < CLOUD_SHEET_BOUNDS.x) continue;
        
        float density = cloudSheetShape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudSheetLight(vec3 pos, const uint steps) {
    float stepsize = (CLOUD_SHEET_DEPTH / float(steps));

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_SHEET_BOUNDS.y || pos.y < CLOUD_SHEET_BOUNDS.x) continue;
        
        float density = cloudSheetShape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudSheetLight(vec3 pos, const uint steps, vec3 dir) {
    float stepsize = (CLOUD_SHEET_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_SHEET_BOUNDS.x, CLOUD_SHEET_BOUNDS.y) * 0.9;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_SHEET_BOUNDS.y || pos.y < CLOUD_SHEET_BOUNDS.x) continue;
        
        float density = cloudSheetShape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float cloudPhaseSheet(float cosTheta, vec3 asymmetry) {
    float x = mieHG(cosTheta, asymmetry.x);
    float y = mieCS(cosTheta, -asymmetry.y);
    float z = mieCS(cosTheta, asymmetry.z);

    return 0.4 * x + 0.2 * y + 0.5 * z;
}

// ---- CROSS-LAYER SHADOWING ---- //
float GetPlanar0Occlusion(vec3 pos, vec3 dir) {
    if (dir.y <= 0.001) return 1.0;

    float distanceToPlane   = CLOUD_PLANE0_ALT - pos.y;
        distanceToPlane    /= max(dir.y, 0.001);

    float DistanceRolloff   = 1.0 / (1.0 + max0(distanceToPlane / CLOUD_PLANE0_ALT - 1.0) / 4.0);  

    vec3 ProjectedToPlane   = pos + dir * (distanceToPlane);

    return exp(-cloudPlanarShape0(ProjectedToPlane) * CLOUD_PLANE0_DEPTH * 0.63 * CLOUD_PLANE0_SIGMA * DistanceRolloff);
}
float GetSheetOcclusion(vec3 pos, vec3 dir) {
    if (dir.y <= 0.001) return 1.0;

    float distanceToPlane   = CLOUD_SHEET_ALT - pos.y;
        distanceToPlane    /= max(dir.y, 0.001);

    float DistanceRolloff   = 1.0 / (1.0 + max0(distanceToPlane / CLOUD_SHEET_ALT - 1.0) / 4.0);  

    vec3 ProjectedToPlane   = pos + dir * (distanceToPlane);

    return exp(-cloudSheetShape(ProjectedToPlane) * CLOUD_SHEET_DEPTH * 0.75 * 0.005 * DistanceRolloff);
}

vec2 rsi(vec3 pos, vec3 dir, float r) {
    float b     = dot(pos, dir);
    float det   = sqr(b) - dot(pos, pos) + sqr(r);

    if (det < 0.0) return vec2(-1.0);

        det     = sqrt(det);

    return vec2(-b) + vec2(-det, det);
}

vec3 planetCurvePosition(in vec3 x) {
    return vec3(x.x, length(x + vec3(0.0, planetRad, 0.0))-planetRad, x.z);
}