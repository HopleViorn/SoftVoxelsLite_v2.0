# 体积云实现分析报告

## 实验步骤
基于Minecraft的体积云实时渲染实现。
基于现有的shader进行修改，在其中添加体积云渲染。
开源代码在(TODO:url)

## 体积云核心实现概述：

该文件实现了一个基于光线步进（Ray Marching）的体积云渲染器，主要包括以下几个关键部分：

1.  **噪声生成**:
    *   `simplexNoise` 函数：提供高质量的 Simplex 噪声，作为云形状的基础。
    *   `fbm` 函数：利用 Simplex 噪声生成分形布朗运动（FBM），模拟云的复杂、多尺度结构。

2.  **云密度计算 (`cloudDensity`)**:
    *   结合 FBM 噪声 (`base_noise` 和 `detail_noise`) 来定义云的形状和细节。
    *   通过 `smoothstep` 函数在预设的 `bottom_y` (150.0) 和 `top_y` (220.0) 之间创建平滑的垂直梯度，确保云层有明确的底部和顶部边界。

3.  **光照模型**:
    *   `henyeyGreenstein` 函数：实现 Henyey-Greenstein 相位函数，用于模拟光在云中的散射方向，支持前向散射（产生银边效果）和后向散射（补光）。
    *   `getLightEnergy` 函数：通过二次光线步进（secondary raymarch）计算从当前点到太阳方向的光线能量，模拟云的自阴影效果，并使用比尔-朗伯定律计算光的透光率。
    *   `raymarch` 函数：
        *   这是核心的体积渲染循环，沿着视线方向进行光线步进。
        *   在每一步中，计算当前点的云密度。
        *   整合了新的光照计算逻辑：
            *   获取自阴影光能。
            *   计算散射光（结合前向和后向相位函数）。
            *   通过简单的近似计算环境光。
            *   将散射光和环境光结合，得到最终光照。
            *   计算当前步的吸收和散射。
            *   使用从后向前混合（back-to-front blending）累加颜色，并更新视线方向的透光率。
            *   最后，基于光学深度计算最终的 alpha 值，实现物理正确的透明度。

## 结果图

预留
动态展示可参考代码仓库

## 特点
1. 高性能渲染 1080p(实际1885x1044)下 50 - 60 FPS RTX 4070
2. 实时噪声生成，丰富的动态效果。
3. 正确场景交互，在云内部和外部观察都能有正确的视觉效果。能正确与场景遮挡。
   

## 遇到的问题
要实现高质量的拟阵的云形状不容易，经过反复测试形成了现在的fbm噪声采样方法，实现动态的美丽的，长得像云的噪声图。

## 详细代码

```

// 高质量Simplex噪声实现
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x*34.0)+1.0)*x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

const float bottom_y = 150.0;
const float top_y =220.0;

float simplexNoise(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;

    i = mod289(i);
    vec4 p = permute(permute(permute(
                 i.z + vec4(0.0, i1.z, i2.z, 1.0))
               + i.y + vec4(0.0, i1.y, i2.y, 1.0))
               + i.x + vec4(0.0, i1.x, i2.x, 1.0));

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

    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

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

float cloudDensity(vec3 p, float time) {
    float scale = 0.005; 
    float time_scale = 0.05;

    vec3 q = p * scale + vec3(0.0, 0.0, time * time_scale*0.1);
    float base_noise = fbm(q, 4, 2.0, 0.5);

    vec3 r = p * scale * 3.0 + vec3(0.0, 0.0, time * time_scale * 2.0);
    float detail_noise = fbm(r, 3, 3.0, 0.5);

    float density = base_noise - detail_noise * 0.2;
    
    float vertical_gradient = smoothstep(bottom_y, bottom_y + 20.0, p.y) * (1.0 - smoothstep(top_y - 20.0, top_y, p.y));
    density *= vertical_gradient;

    return clamp(density * 1.5, 0.0, 1.0);
}

const int kDiv = 1; 

// const vec3 SUN_COLOR = vec3(1.0, 0.85, 0.7); // 太阳光颜色
const vec3 SUN_COLOR = vec3(1.0); // 太阳光颜色
const float SCATTERING_COEFFICIENT = 0.9; // 散射系数，影响光的传播
const float ABSORPTION_COEFFICIENT = 0.1; // 吸收系数，影响云的暗度
const float DENSITY_MULTIPLIER = 1; // 整体密度乘数

// Henyey-Greenstein 相位函数，模拟光在云中的散射方向
// g > 0: 前向散射 (产生漂亮的银边)
// g < 0: 后向散射
// g = 0: 均匀散射
float henyeyGreenstein(float cos_theta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(1.0 - 2.0 * g * cos_theta + g2, 1.5));
}

// 计算从pos点朝太阳方向的光线能量 (通过二次步进)
float getLightEnergy(vec3 pos, float time) {
    float light_march_steps = 2.0;
    float light_march_dist = 30.0 / light_march_steps; // 向光步进的总距离
    float transmittance = 1.0;

    for (int i = 0; i < int(light_march_steps); i++) {
        vec3 light_pos = pos + sunDir * float(i) * light_march_dist;
        float density_sample = cloudDensity(light_pos, time);
        if (density_sample > 0.01) {
            // 根据比尔-朗伯定律计算透光率
            transmittance *= exp(-density_sample * DENSITY_MULTIPLIER * SCATTERING_COEFFICIENT * light_march_dist);
        }
        if (transmittance < 0.001) break; // 提前退出以优化
    }
    return transmittance;
}


vec4 raymarch(in vec3 ro, in vec3 rd, in vec3 bgcol, in ivec2 px, in float tmaxx)
{
    
    float tb = (bottom_y - ro.y) / rd.y;
    float tt = (top_y - ro.y) / rd.y;

    float tmin;
    float tmax;

    if (tb * tt < 0) {
        tmin = 0;
        tmax = 1000.0;
    }else{
        tt = abs(tt);
        tb = abs(tb);
        tmin = min(tt, tb);
        tmax = max(tt, tb);
    }

    // tmax = 20.0;
    // tmin = 0.0;


    if (tmaxx > 0) {
        tmax = min(tmax, tmaxx);
    }

    // tmax = min(tmax, 300.0);
    // tmin = min(tmin, tmax);

    if (tmax <= tmin) {
        return vec4(0.0);
    }

    vec3 SKY_COLOR = vec3(1.0);
    
    float t = tmin;
    vec4 sum = vec4(0.0);
    float transmittance = 0.8; // 沿着视线方向的透光率
    
    // 主光线步进循环
    for (int i = 0; i < 128 * kDiv; i++)
    {
        if (t > tmax || transmittance < 0.01) break;

        float dt = max(0.1, 0.04*t/float(kDiv));
        vec3 pos = ro + t * rd;
        float den = cloudDensity(pos, frameTimeCounter);
        
        if (den > 0.01)
        {
            // --- 全新的光照计算代码块 ---

            // 1. 计算到达此点的光能 (考虑自阴影)
            float light_energy = getLightEnergy(pos, frameTimeCounter);

            // 2. 计算散射
            float cos_theta = dot(rd, sunDir);
            float phase_forward = henyeyGreenstein(cos_theta, 0.4);  // 前向散射 (银边效果)
            float phase_backward = henyeyGreenstein(cos_theta, -0.15); // 后向散射 (补光)
            vec3 scattering_color = SUN_COLOR * (phase_forward + phase_backward);

            // 3. 计算环境光/环境遮蔽
            // 一个简单的近似：密度越高，吸收的环境光越多
            vec3 ambient_light = SKY_COLOR * (1.0 - den * 0.7);

            // 4. 结合光照
            // (散射光 * 阳光) + 环境光
            vec3 final_light =  light_energy * scattering_color + ambient_light;
            
            // 5. 计算当前步的颜色和吸收
            float absorption = exp(-den * DENSITY_MULTIPLIER * ABSORPTION_COEFFICIENT * dt);
            float scattering = exp(-den * DENSITY_MULTIPLIER * SCATTERING_COEFFICIENT * dt);
            
            // 当前步贡献的颜色 = 光照 * (1 - 散射率)
            vec3 step_color = final_light * (1.0 - scattering);

            // 6. 从后向前混合
            // 累加颜色，并乘以视线方向的透光率
            sum.rgb += step_color * transmittance;
            
            // 更新视线方向的透光率
            transmittance *= absorption;

            // 基于光学深度的物理正确透明度计算
            float optical_depth = -log(max(transmittance, 1e-5));
            float alpha = 1.0 - exp(-optical_depth * DENSITY_MULTIPLIER * 0.5);
            sum.a = clamp(alpha, 0.0, 1.0);
        }
        
        t += dt;
    }
    
    return clamp(sum, 0.0, 1.0);
}

// 保持不变的入口函数
vec4 renderShadertoyClouds( in vec3 ro, in vec3 rd, in ivec2 px, in vec3 bgcol, in float tmaxx )
{
    vec4 res = raymarch( ro, rd, bgcol, px, tmaxx );
    return res;
}
```