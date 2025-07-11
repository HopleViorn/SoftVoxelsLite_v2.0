
// 0: no LOD
// 1: yes LOD
#define USE_LOD 0



// 高质量Simplex噪声实现
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x*34.0)+1.0)*x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float simplexNoise(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    // 第一角
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    // 其他角
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;

    // 排列
    i = mod289(i);
    vec4 p = permute(permute(permute(
             i.z + vec4(0.0, i1.z, i2.z, 1.0))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0))
           + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // 梯度计算
    float n_ = 0.142857142857; // 1/7
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    // 归一化梯度
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // 混合结果
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// 分形布朗运动 (FBM) 用于体积云
float fbm(vec3 p, int octaves, float lacunarity, float gain) {
    float total = 0.0;
    float frequency = 1.0;
    float amplitude = 1.0;
    float maxValue = 0.0;
    
    for(int i=0; i<octaves; i++) {
        total += simplexNoise(p * frequency) * amplitude;
        maxValue += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }
    
    return total / maxValue;
}

// 改进的云密度函数
float cloudDensity(vec3 p, float time) {
    // p.y -= 100;
    float scale = 0.01;
    float time_scale = 0.1;

    //不scale y

    p = scale * p;

    // p.x *= scale;
    // p.z *= scale;
    

    // 基础形状
    vec3 q = p * 0.5 + vec3(0.0, time*time_scale*0.05, time*time_scale*0.1);
    float shape = fbm(q, 4, 0.1, 0.01);
    
    // 细节层
    vec3 r = p * 1.5 + vec3(0.0, time*time_scale*0.1, 0.0);
    float details = fbm(r, 3, 2.5, 0.4);
    
    // 结合形状和细节
    float density = shape - details*0.2;
    
    // 添加垂直渐变
    density -= smoothstep(0.0, 0.3, p.y/200.0);
    density += smoothstep(0.7, 1.0, p.y/200.0)*0.3;
    
    return clamp(density, 0.0, 1.0);
}

const int kDiv = 1; // make bigger for higher quality

vec3 testSunVec = vec3(-1.0, 0.0, 0.0);

vec4 raymarch( in vec3 ro, in vec3 rd, in vec3 bgcol, in ivec2 px, in float tmaxx )
{
    const float yb = 180;  // 降低底部
    const float yt = 250;  // 提高顶部
    
    float tb = (yb-ro.y)/rd.y;
    float tt = (yt-ro.y)/rd.y;

    // find tigthest possible raymarching segment
    float tmin, tmax;


    tmin = min(tt, tb);
    tmax = max(tt, tb);

    // return vec4(tmaxx, 0.0, 0.0, 1.0);
    tmax = min(tmax, tmaxx);
    tmin = min(tmin, tmaxx);

    tmin = max(tmin, 0.0);
    tmax = min(tmax, 300.0);

    if(tmax <= tmin) {
        return vec4(0.0);
    }
    
    float t = tmin;

    // 光线步进循环
    vec4 sum = vec4(0.0);
    
    for( int i=0; i<200*kDiv; i++ )
    {
        float dt = max(0.1, 0.04*t/float(kDiv));

        vec3 pos = ro + t*rd;
        float den = cloudDensity(pos, frameTimeCounter);
        
        if( den > 0.01 )
        {
            // --- 填充的代码块开始 ---

            // 计算光照
            // 通过在朝向太阳方向上对云密度进行二次采样来模拟简单的散射
            float dif = clamp((den - cloudDensity(pos + 0.3 * sunDir, frameTimeCounter)) / 0.25, 0.0, 1.0);

            // 定义光照颜色和环境光
            vec3 lin = vec3(0.65, 0.65, 0.75) * 1.1 + 0.8 * vec3(1.0, 0.6, 0.3) * dif;

            // 定义云的颜色，根据密度从亮色过渡到暗色
            vec4 col = vec4(mix(vec3(1.0, 0.93, 0.84), vec3(0.25, 0.3, 0.4), den), den);

            // 将光照应用到云的颜色上
            col.xyz *= lin;

            // 根据步长和密度计算当前步的透明度
            col.a = min(col.a * 8.0 * dt, 1.0);

            // 将颜色与透明度预乘
            col.rgb *= col.a;

            // 从前向后混合颜色
            sum += col * (1.0 - sum.a);
            
            // --- 填充的代码块结束 ---
        }
        
        t += dt;
        if(t > tmax) break;
    }
    
    return clamp(sum, 0.0, 1.0);
}

vec4 renderShadertoyClouds( in vec3 ro, in vec3 rd, in ivec2 px, in float tmaxx )
{
    vec4 res = raymarch( ro, rd, vec3(0.0), px, tmaxx );
    return res;
}



