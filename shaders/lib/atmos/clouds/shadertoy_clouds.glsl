// To be connected from the main shader
// uniform sampler2D noisetex;r
// uniform float frameTimeCounter;

// 0: sunset look
// 1: bright look
#define LOOK 0

// 0: one 3d texture lookup
// 1: two 2d texture lookups with hardware interpolation
// 2: two 2d texture lookups with software interpolation
#define NOISE_METHOD 1

// 0: no LOD
// 1: yes LOD
#define USE_LOD 0

// To be connected from the main shader
// uniform vec3 sunVec; // Should be the sun direction vector


// Improved Perlin noise for clouds
float hash(vec3 p) {
    p  = fract(p * 0.3183099 + .1);
    p *= 17.0;
    return fract(p.x*p.y*p.z*(p.x+p.y+p.z));
}

float noise( in vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
    
    // Improved Perlin noise
    float n = p.x + p.y*157.0 + p.z*113.0;
    vec4 a = vec4(n, n+1.0, n+157.0, n+158.0);
    vec4 b = vec4(n+113.0, n+114.0, n+270.0, n+271.0);
    vec4 v1 = fract(sin(a)*43758.5453);
    vec4 v2 = fract(sin(b)*43758.5453);
    
    vec4 lerp_x = mix(v1, v2, f.x);
    vec2 lerp_y = mix(lerp_x.xy, lerp_x.zw, f.y);
    float lerp_z = mix(lerp_y.x, lerp_y.y, f.z);
    
    return lerp_z*2.0-1.0;
    // return 1.0;
}

#if LOOK==0
float map( in vec3 p, int oct )
{
	vec3 q = p - vec3(0.0,0.1,1.0)*frameTimeCounter;
    float g = 0.5+0.5*noise( q*0.3 );
    
	float f;
    f  = 0.50000*noise( q ); q = q*2.02;
    #if USE_LOD==1
    if( oct>=2 ) 
    #endif
    f += 0.25000*noise( q ); q = q*2.23;
    #if USE_LOD==1
    if( oct>=3 )
    #endif
    f += 0.12500*noise( q ); q = q*2.41;
    #if USE_LOD==1
    if( oct>=4 )
    #endif
    f += 0.06250*noise( q ); q = q*2.62;
    #if USE_LOD==1
    if( oct>=5 )
    #endif
    f += 0.03125*noise( q ); 
    
    f = mix( f*0.1-0.5, f, g*g );
        
    return 1.5*f - 0.5 - p.y;
}

const int kDiv = 1; // make bigger for higher quality
// const vec3 sundir = normalize( vec3(1.0,0.0,-1.0) ); // Now using sunVec uniform

vec3 testSunVec = sunVec;

vec4 raymarch( in vec3 ro, in vec3 rd, in vec3 bgcol, in ivec2 px )
{
    // bounding planes	
    const float yb = 180;
    const float yt = 200;
    float tb = (yb-ro.y)/rd.y;
    float tt = (yt-ro.y)/rd.t;

    // find tigthest possible raymarching segment
    float tmin, tmax;
    if( ro.y>yt )
    {
        // above top plane
        if( tt<0.0 ) return vec4(0.0); // early exit
        tmin = tt;
        tmax = tb;
    }
    else if (ro.y < yb) {
        if (tb < 0.0) return vec4(0.0);
        tmin = tb;
        tmax = tt;
    }
    else
    {
        // inside clouds slabs
        tmin = 0.0;
        tmax = 60.0;
        if( tt>0.0 ) tmax = min( tmax, tt );
        if( tb>0.0 ) tmax = min( tmax, tb );
    }

    
    // dithered near distance
    // Original used iChannel1 for dithering. For now, this is disabled.
    // It could be connected to a blue noise texture later.
    float t = tmin; //+ 0.1*texelFetch( iChannel1, px&1023, 0 ).x;
    
    // raymarch loop
	vec4 sum = vec4(0.0);
    for( int i=0; i<200*kDiv; i++ )
    {
       // step size
       float dt = max(0.05,0.02*t/float(kDiv));

       // lod
       #if USE_LOD==0
       const int oct = 5;
       #else
       int oct = 5 - int( log2(1.0+t*0.5) );
       #endif
       
       // sample cloud
       vec3 pos = ro + t*rd;
    //    float den = map( pos,oct );
       float den = noise(pos);
       if( den > 0.1 ) // if inside
       {
           // do lighting
        //    float dif = clamp((den - map(pos+0.3*sunVec,oct))/0.25, 0.0, 1.0 );
           float dif = clamp((den - noise(pos+0.3*sunVec))/0.25, 0.0, 1.0 );
           vec3  lin = vec3(0.65,0.65,0.75)*1.1 + 0.8*vec3(1.0,0.6,0.3)*dif;
           vec4  col = vec4( mix( vec3(1.0,0.93,0.84), vec3(0.25,0.3,0.4), den ), den );
           col.xyz *= lin;
           // fog
           col.xyz = mix(col.xyz,bgcol, 1.0-exp2(-0.1*t));
           // composite front to back
           col.w    = min(col.w*8.0*dt,1.0);
           col.rgb *= col.a;
           sum += col*(1.0-sum.a);
        //    sum = vec4(1.0,0.0,0.0,1.0);
       }
       // advance ray
       t += dt;
       // until far clip or full opacity
       if( t>tmax || sum.a>0.99 ) break;
    }

    return clamp( sum, 0.0, 1.0 );
}

vec4 renderShadertoyClouds( in vec3 ro, in vec3 rd, in ivec2 px )
{
	float sun = clamp( dot(testSunVec,rd), 0.0, 1.0 );

    // background sky
    vec3 col = vec3(0.76,0.75,0.95);
    col -= 0.6*vec3(0.90,0.75,0.95)*rd.y;
	col += 0.2*vec3(1.00,0.60,0.10)*pow( sun, 8.0 );

    // // clouds    
    vec4 res = raymarch( ro, rd, col, px );
    return res;

    col = col*(1.0-res.w) + res.xyz;
    
    // // sun glare    
	col += 0.2*vec3(1.0,0.4,0.2)*pow( sun, 3.0 );

    // // tonemap
    col = smoothstep(0.15,1.1,col);

    // col = testSunVec;

    return vec4( col, 1.0 );
}

#else

// The other look is not ported for now.
vec4 renderShadertoyClouds( in vec3 ro, in vec3 rd, in ivec2 px ) {
    return vec4(0.0);
}

#endif
