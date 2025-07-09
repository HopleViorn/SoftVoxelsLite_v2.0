
struct materialProperties {
    float roughness;
    float f0;
    bool conductor;
    bool conductorComplex;
    mat2x3 eta;
};

const mat2x3 conductorProperties[8] = mat2x3[8](
    mat2x3(vec3(2.9114,  2.9497,  2.5845),  vec3(3.0893, 2.9318, 2.7670)),     //iron
    mat2x3(vec3(0.18299, 0.42108, 1.3734),  vec3(3.4242, 2.3459, 1.7704)),   //gold
    mat2x3(vec3(1.3456,  0.96521, 0.61722), vec3(7.4746, 6.3995, 5.3031)),   //aluminum
    mat2x3(vec3(3.1071,  3.1812,  2.3230),  vec3(3.3314, 3.3291, 3.1350)),     //chrome
    mat2x3(vec3(0.27105, 0.67693, 1.3164),  vec3(3.6092, 2.6248, 2.2921)),   //copper
    mat2x3(vec3(1.9100,  1.8300,  1.4400),  vec3(3.5100, 3.4000, 3.1800)),     //lead
    mat2x3(vec3(2.3757,  2.0847,  1.8453),  vec3(4.2655, 3.7153, 3.1365)),     //platinum
    mat2x3(vec3(0.15943, 0.14512, 0.13547), vec3(3.9291, 3.1900, 2.3808))   //silver
);

materialProperties decodeLabBasic(in vec2 data) {
    materialProperties material     = materialProperties(1.0, 0.04, false, false, mat2x3(1.0));

    material.roughness  = sqr(1.0 - data.r);
    material.f0         = clamp(data.g, 0.02, 0.9);

    uint integerF0      = uint(data.g * 255.0);

    material.conductor  = integerF0 >= 230;
    material.conductorComplex = integerF0 <= 237;

    material.eta        = conductorProperties[clamp(int(integerF0 - 230), 0, 7)];
    material.eta[0]     = material.eta[0];
    material.eta[1]     = material.eta[1];

    return material;
}

/* --- Fresnel --- */
float fresnelDielectric(float cosTheta, float f0) {
        f0      = min(sqrt(f0), 0.99999);
        f0      = (1.0 + f0) * rcp(1.0 - f0);

    float sinThetaI = sqrt(saturate(1.0 - sqr(cosTheta)));
    float sinThetaT = sinThetaI * rcp(max(f0, 1e-16));
    float cosThetaT = sqrt(1.0 - sqr(sinThetaT));

    float Rs        = sqr((cosTheta - (f0 * cosThetaT)) * rcp(max(cosTheta + (f0 * cosThetaT), 1e-10)));
    float Rp        = sqr((cosThetaT - (f0 * cosTheta)) * rcp(max(cosThetaT + (f0 * cosTheta), 1e-10)));

    return saturate((Rs + Rp) * 0.5);
}

vec3 fresnelConductor(float cosTheta, mat2x3 data) {
    vec3 eta            = data[0];
    vec3 etak           = data[1];
    float cosTheta2     = sqr(cosTheta);
    float sinTheta2     = 1.0 - cosTheta2;
    vec3 eta2           = sqr(eta);
    vec3 etak2          = sqr(etak);

    vec3 t0             = eta2 - etak2 - sinTheta2;
    vec3 a2plusb2       = sqrt(sqr(t0) + 4.0 * eta2 * etak2);
    vec3 t1             = a2plusb2 + cosTheta2;
    vec3 a              = sqrt(0.5 * (a2plusb2 + t0));
    vec3 t2             = 2.0 * a * cosTheta;
    vec3 Rs             = (t1 - t2) * rcp(max(t1 + t2, 1e-16));

    vec3 t3             = cosTheta2 * a2plusb2 + sinTheta2 * sinTheta2;
    vec3 t4             = t2 * sinTheta2;   
    vec3 Rp             = Rs * (t3 - t4) * rcp(max(t3 + t4, 1e-16));

    return saturate((Rs + Rp) * 0.5);
}
vec3 fresnelTinted(float cosTheta, vec3 tint) {
    vec3 tintSqrt   = sqrt(clamp(tint, 0.0, 0.99));
    vec3 n          = (1.0 + tintSqrt) / (1.0 - tintSqrt);
    vec3 g          = sqrt(sqr(n) + sqr(cosTheta) - 1);

    return 0.5 * sqr((g - cosTheta) / (g + cosTheta)) * (1.0 + sqr(((g + cosTheta) * cosTheta - 1.0) / ((g - cosTheta) * cosTheta + 1.0)));
}

vec3 BRDFfresnel(vec3 viewDir, vec3 normal, materialProperties material, vec3 albedo) {
    float vDotN     = max0(dot(viewDir, normal));

    if (material.conductor) {
        return material.conductorComplex ? fresnelConductor(vDotN, material.eta) : fresnelTinted(vDotN, albedo);
    } else {
        return vec3(fresnelDielectric(vDotN, material.f0));
    }
}
vec3 BRDFfresnelAlbedoTint(vec3 viewDir, vec3 normal, materialProperties material, vec3 albedo) {
    float vDotN     = max0(dot(viewDir, normal));

    if (material.conductor) {
        return fresnelTinted(vDotN, albedo);
    } else {
        return vec3(fresnelDielectric(vDotN, material.f0));
    }
}
vec3 BRDFfresnel(vec3 viewDir, vec3 normal, materialProperties material) {
    float vDotN     = max0(dot(viewDir, normal));
    return vec3(fresnelDielectric(vDotN, material.f0));
}

/* --- BRDF --- */
const float specularMaxClamp    = sqrPi * sqrPi;

float brdfDistBeckmann(vec2 data) {
    //data.y  = max(sqr(data.y), 2e-4);
    /*data.x *= data.x;

    return rcp(pi * data.y * cos(sqr(data.x))) * (exp((data.x - 1.0) * rcp(data.y * tan(data.x))));*/

    float ndoth = data.x;
    float alpha2 = max(data.y, 2e-4);

        ndoth *= ndoth;
    float e = exp((ndoth - 1.0) / (alpha2 * tan(ndoth)));
    float num = rcp(pi * alpha2 * cos(ndoth * ndoth));
    return num*e;
}
float brdfDistTrowbridgeReitz(vec2 data) {
    data.x *= data.x;
    data.y *= data.y;

    return max(data.y, 1e-5) * rcp(max(pi * sqr(data.x * (data.y - 1.0) + 1.0), 1e-10));
}
float brdfGeometrySchlick(vec2 data) {  //y = sqr(roughness + 1) / 8.0
    return data.x * rcp(data.x * (1.0 - data.y) + data.y);
}
float brdfGeometryBeckmann(vec2 data) {
    float c     = data.x * rcp(data.y * sqrt(1.0 - sqr(data.x)));

    if (c >= 1.6) return 1.0;
    else return (3.535 * c + 2.181 * sqr(c)) * rcp(1.0 + 2.276 * c + 2.577 * sqr(c));
}

float brdfShadowSmithBeckmann(float nDotV, float nDotL, float roughness) {
    return brdfGeometryBeckmann(vec2(nDotL, roughness)) * brdfGeometryBeckmann(vec2(nDotV, roughness));
}
float brdfShadowSmithSchlick(float nDotV, float nDotL, float roughness) {
    roughness   = sqr(roughness + 1.0) / 8.0;
    return brdfGeometrySchlick(vec2(nDotL, roughness)) * brdfGeometrySchlick(vec2(nDotV, roughness));
}

vec3 specularTrowbridgeReitzGGX(vec3 viewDir, vec3 lightDir, vec3 normal, materialProperties material, vec3 albedo) {
    vec3 halfWay    = normalize(viewDir + lightDir);

    float nDotL     = max0(dot(normal, lightDir));
    float nDotH     = max0(dot(normal, halfWay));
    float vDotN     = max0(dot(viewDir, normal));
    float vDotH     = max0(dot(viewDir, halfWay));

    vec2 dataD      = vec2(nDotH, material.roughness);

    float D         = brdfDistTrowbridgeReitz(dataD);
    float G         = brdfShadowSmithSchlick(vDotN, nDotL, material.roughness);
    float result    = max0(D * G * rcp(max(4.0 * vDotN * nDotL, 1e-10)));

    vec3 fresnel    = vec3(0.0);

    if (material.conductor) {
        fresnel = material.conductorComplex ? fresnelConductor(vDotH, material.eta) * sqrt(albedo) : fresnelTinted(vDotH, albedo);
    } else {
        fresnel = vec3(fresnelDielectric(vDotH, material.f0));
    }

    return vec3(result) * fresnel;
}

/*
    These two functions used for rough reflections are based on zombye's spectrum shaders
    https://github.com/zombye/spectrum
*/

mat3 getRotationMat(vec3 x, vec3 y) {
	float cosine = dot(x, y);
	vec3 axis = cross(y, x);

	float tmp = 1.0 / dot(axis, axis);
	      tmp = tmp - tmp * cosine;
	vec3 tmpv = axis * tmp;

	return mat3(
		axis.x * tmpv.x + cosine, axis.x * tmpv.y - axis.z, axis.x * tmpv.z + axis.y,
		axis.y * tmpv.x + axis.z, axis.y * tmpv.y + cosine, axis.y * tmpv.z - axis.x,
		axis.z * tmpv.x - axis.y, axis.z * tmpv.y + axis.x, axis.z * tmpv.z + cosine
	);
}

#define GGX_TAILCLAMP 0.25

vec3 ggxFacetDist(vec3 viewDir, float roughness, vec2 xy) {
	/*
        GGX VNDF sampling
        http://www.jcgt.org/published/0007/04/01/
    */
    roughness   = max(roughness, 0.001);
    xy.x        = clamp(xy.x * GGX_TAILCLAMP, 0.001, GGX_TAILCLAMP);

    viewDir     = normalize(vec3(roughness * viewDir.xy, viewDir.z));

    float clsq  = dot(viewDir.xy, viewDir.xy);
    vec3 T1     = vec3(clsq > 0.0 ? vec2(-viewDir.y, viewDir.x) * inversesqrt(clsq) : vec2(1.0, 0.0), 0.0);
    vec3 T2     = vec3(-T1.y * viewDir.z, viewDir.z * T1.x, viewDir.x * T1.y - T1.x * viewDir.y);

	float r     = sqrt(xy.x);
	float phi   = tau * xy.y;
	float t1    = r * cos(phi);
	float a     = saturate(1.0 - t1 * t1);
	float t2    = mix(sqrt(a), r * sin(phi), 0.5 + 0.5 * viewDir.z);

	vec3 normalH = t1 * T1 + t2 * T2 + sqrt(saturate(a - t2 * t2)) * viewDir;

	return normalize(vec3(roughness * normalH.xy, normalH.z));
}


/*
    Screenspace Trace
*/


    #define SSR_DistanceThreshold 128.0

vec3 screenspaceRT(vec3 position, vec3 direction, float noise, float distanceThreshold) {
    const uint maxSteps     = 16;

  	float rayLength = ((position.z + direction.z * far * sqrt3) > -near) ?
                      (-near - position.z) / direction.z : far * sqrt3;

    vec3 screenPosition     = viewToScreenSpace(position);
    vec3 endPosition        = position + direction * rayLength;
    vec3 endScreenPosition  = viewToScreenSpace(endPosition);

    vec3 screenDirection    = normalize(endScreenPosition - screenPosition);
        screenDirection.xy  = normalize(screenDirection.xy);

    vec3 maxLength          = (step(0.0, screenDirection) - screenPosition) / screenDirection;
    float stepMult          = minOf(maxLength);
    vec3 screenVector       = screenDirection * stepMult / float(maxSteps);

    vec3 screenPos          = screenPosition + screenDirection * maxOf(pixelSize * pi);

    if (saturate(screenPos.xy) == screenPos.xy) {
        float depthSample   = texelFetch(depthtex1, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = abs(linearSample - currentDepth) / clamp(currentDepth, 0.25 / far, distanceThreshold / far);
            if (dist <= 0.25) return vec3(screenPos.xy, depthSample);
        }
    }

        screenPos          += screenVector * noise;

    for (uint i = 0; i < maxSteps; ++i) {
        if (saturate(screenPos.xy) != screenPos.xy) break;

        float depthSample   = texelFetch(depthtex1, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = abs(linearSample - currentDepth) / clamp(currentDepth, 0.25 / far, distanceThreshold / far);
            if (dist <= 0.25) return vec3(screenPos.xy, depthSample);
        }

        screenPos      += screenVector;
    }

    return vec3(1.1);
}
vec3 screenspaceRT_LR(vec3 position, vec3 direction, float noise, float distanceThreshold) {
    const uint maxSteps     = 8;

  	float rayLength = ((position.z + direction.z * far * sqrt3) > -near) ?
                      (-near - position.z) / direction.z : far * sqrt3;

    vec3 screenPosition     = viewToScreenSpace(position);
    vec3 endPosition        = position + direction * rayLength;
    vec3 endScreenPosition  = viewToScreenSpace(endPosition);

    vec3 screenDirection    = normalize(endScreenPosition - screenPosition);
        screenDirection.xy  = normalize(screenDirection.xy);

    vec3 maxLength          = (step(0.0, screenDirection) - screenPosition) / screenDirection;
    float stepMult          = min(minOf(maxLength), 0.5);
    vec3 screenVector       = screenDirection * stepMult / float(maxSteps);

    vec3 screenPos          = screenPosition;

        screenPos          += screenVector * noise;

    for (uint i = 0; i < maxSteps; ++i) {
        if (saturate(screenPos.xy) != screenPos.xy) break;

        float depthSample   = texelFetch(depthtex1, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = abs(linearSample - currentDepth) / clamp(currentDepth, 0.25 / far, distanceThreshold / far);
            if (dist <= 0.25) return vec3(screenPos.xy, depthSample);
        }

        screenPos      += screenVector;
    }

    return vec3(1.1);
}

#include "/lib/frag/capture.glsl"

vec4 readSkyCapture(vec3 direction, float occlusion) {
    return vec4(texture(colortex4, projectSky(direction, 1)).rgb, occlusion * sqr(saturate(direction.y + 1.0)));
}

void applySkyCapture(inout vec4 color, vec3 sky, float occlusion) {
    #ifdef NOSKY
        if (color.a < 1.0) {
            color = vec4(color.rgb, 1.0);
        } else {
            color = vec4(0);
        }
        return;
    #else
        if (color.a < 1.0) {
            color = vec4(color.rgb, 1.0);
        } else {
            color = vec4(sky * occlusion, occlusion);
        }
        return;
    #endif
}

vec4 readSpherePositionAware(float occlusion, vec3 scenePosition, vec3 direction) {
    #ifdef NOSKY
    return vec4(0);
    #else
    return vec4(texture(colortex4, projectSky(direction, 1)).rgb * sqrt(occlusion), occlusion);
    #endif
}

mat2x3 unpackReflectionAux(vec4 data){
    vec3 shadows    = decodeRGBE8(vec4(unpack2x8(data.x), unpack2x8(data.y)));
    vec3 albedo     = decodeRGBE8(vec4(unpack2x8(data.z), unpack2x8(data.w)));

    return mat2x3(shadows, albedo);
}