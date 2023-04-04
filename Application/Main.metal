//
//  Main.metal
//  Metal-SwiftUI
//

#include <metal_stdlib>
using namespace metal;

#include "Shaders.h"


struct VertexOutput {
	float4 position [[ position ]];
	float2 uv;
};

typedef VertexOutput FragmentInput;


vertex VertexOutput vertex_main(unsigned int vertex_id [[ vertex_id ]]) {
	float2 uv = float2((vertex_id << 1) & 2, vertex_id & 2);
	return {
		float4(uv * float2(2, -2) + float2(-1, 1), 1, 1),
		uv
	};
}


#pragma mark - 2D

struct PSRDNoise2D {
	float value;
	float2 gradient;
};

/// Adapted from: https://github.com/stegu/psrdnoise/blob/4d627ff/src/psrdnoise2-min.glsl#L5
/// psrdnoise (c) Stefan Gustavson and Ian McEwan
/// Ver. 2021-12-02, published under the MIT license:
/// https://github.com/stegu/psrdnoise/
PSRDNoise2D psrdnoise(float2 x, float2 period, float alpha) {
	float2 uv = float2(x.x + x.y * 0.5, x.y);
	float2 i0 = floor(uv), f0 = fract(uv);
	float cmp = step(f0.y, f0.x);
	float2 o1 = float2(cmp, 1 - cmp);
	float2 i1 = i0 + o1, i2 = i0 + 1;
	float2 v0 = float2(i0.x - i0.y * 0.5, i0.y),
	       v1 = float2(v0.x + o1.x - o1.y * 0.5, v0.y + o1.y),
	       v2 = float2(v0.x + 0.5, v0.y + 1);
	float2 x0 = x - v0, x1 = x - v1, x2 = x - v2;
	float3 iu, iv;
	if (any(period > 0)) {
		float3 xw = float3(v0.x, v1.x, v2.x), yw = float3(v0.y, v1.y, v2.y);
		if(period.x > 0) { xw = fmod(float3(v0.x, v1.x, v2.x), period.x); }
		if(period.y > 0) { yw = fmod(float3(v0.y, v1.y, v2.y), period.y); }
		iu = floor(xw + 0.5 * yw + 0.5);
		iv = floor(yw + 0.5);
	} else {
		iu = float3(i0.x, i1.x, i2.x);
		iv = float3(i0.y, i1.y, i2.y);
	}
	float3 hash = fmod(iu, 289);
	hash = fmod((hash * 51 + 2) * hash + iv, 289);
	hash = fmod((hash * 34 + 10) * hash, 289);
	float3 psi = hash * 0.07482 + alpha;
	float3 gx = cos(psi), gy = sin(psi);
	float2 g0 = float2(gx.x, gy.x), g1 = float2(gx.y, gy.y), g2 = float2(gx.z, gy.z);

	float3 w = max(0.8 - float3(dot(x0, x0), dot(x1, x1), dot(x2, x2)), 0);
#if 0
	if (any(i0 != 0) && any(i0 != float2(1, 0)) && any(i0 != 1)) { w.x = 0; }
	if (any(i1 != 0) && any(i1 != float2(1, 0)) && any(i1 != 1)) { w.y = 0; }
	if (any(i2 != 0) && any(i2 != float2(1, 0)) && any(i2 != 1)) { w.z = 0; }
#endif
	float3 ww = w * w, www = ww * w, wwww = ww * ww;

	float3 gdotx = float3(dot(g0, x0), dot(g1, x1), dot(g2, x2));
	float3 dw = -8 * www * gdotx;
	float2 dn0 = wwww.x * g0 + dw.x * x0,
	       dn1 = wwww.y * g1 + dw.y * x1,
	       dn2 = wwww.z * g2 + dw.z * x2;
	return { 10.9 * dot(wwww, gdotx), 10.9 * (dn0 + dn1 + dn2) };
}

PSRDNoise2D PSRDNoiseAdd(PSRDNoise2D n, PSRDNoise2D add, float add_mul = 1) {
	return { n.value + add.value * add_mul, n.gradient + add.gradient * add_mul };
}

inline half4 fragment_2d(
	constant FragmentUniforms &uniforms [[ buffer(0) ]],
	FragmentInput interpolated [[ stage_in ]]
) {
	float scale = 3;
	float aspect = float(uniforms.viewport.x) / float(uniforms.viewport.y);
	float3x2 uv_to_st = uniforms.viewport.x > uniforms.viewport.y
		? float3x2(scale * aspect, 0, 0, scale, -scale * aspect / 2, -scale / 2)
		: float3x2(scale, 0, 0, scale / aspect, -scale / 2, -scale / aspect / 2);
	float2 st = uv_to_st * float3(interpolated.uv, 1);

	PSRDNoise2D n = { 0, 0 };
	n = PSRDNoiseAdd(n, psrdnoise(1 * st + 0.0, 8, uniforms.time / 2), 0.8);
	n = PSRDNoiseAdd(n, psrdnoise(2 * st + 0.0, 16, uniforms.time / 4), 0.4);
	n = PSRDNoiseAdd(n, psrdnoise(4 * st + 0.0, 32, uniforms.time / 8), 0.2);
	n = PSRDNoiseAdd(n, psrdnoise(8 * st + 0.0, 64, uniforms.time / 16), 0.1);
	n = PSRDNoiseAdd(n, psrdnoise(16 * st + 0.0, 128, uniforms.time / 32), 0.05);
	return (half4(1 + n.value, n.gradient.x, n.gradient.y, 2)) / 2;
}


#pragma mark - 3D

struct PSRDNoise3D {
	float value;
	float3 gradient;
};

constant float3x3 _3D_M = float3x3(0, 1, 1, 1, 0, 1, 1, 1, 0);
constant float3x3 _3D_MI = float3x3(-0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, -0.5);

/// Adapted from: https://github.com/stegu/psrdnoise/blob/4d627ff/src/psrdnoise3-min.glsl#L5
/// psrdnoise (c) Stefan Gustavson and Ian McEwan
/// Ver. 2021-12-02, published under the MIT license:
/// https://github.com/stegu/psrdnoise/
float4 permute(float4 x) {
	float4 xm = fmod(x, 289);
	return fmod((xm * 34 + 10) * xm, 289);
}

/// Adapted from: https://github.com/stegu/psrdnoise/blob/4d627ff/src/psrdnoise3-min.glsl#L10
/// psrdnoise (c) Stefan Gustavson and Ian McEwan
/// Ver. 2021-12-02, published under the MIT license:
/// https://github.com/stegu/psrdnoise/
PSRDNoise3D psrdnoise(float3 x, float3 period, float alpha) {
	float3 uvw = _3D_M * x;
	float3 i0 = floor(uvw), f0 = fract(uvw);
	float3 g, l; {
		float3 g0 = step(f0.xyx, f0.yzz), l0 = 1 - g0;
		g = float3(l0.z, g0.xy);
		l = float3(l0.xy, g0.z);
	}
	float3 i1 = i0 + min(g, l),
	       i2 = i0 + max(g, l),
	       i3 = i0 + 1;
	float3 v0 = _3D_MI * i0, x0 = x - v0,
	       v1 = _3D_MI * i1, x1 = x - v1,
	       v2 = _3D_MI * i2, x2 = x - v2,
	       v3 = _3D_MI * i3, x3 = x - v3;
	if (any(period > 0)) {
		float4 vx = float4(v0.x, v1.x, v2.x, v3.x),
		       vy = float4(v0.y, v1.y, v2.y, v3.y),
		       vz = float4(v0.z, v1.z, v2.z, v3.z);
		if(period.x > 0) { vx = fmod(vx, period.x); }
		if(period.y > 0) { vy = fmod(vy, period.y); }
		if(period.z > 0) { vz = fmod(vz, period.z); }
		i0 = floor(_3D_M * float3(vx.x, vy.x, vz.x) + 0.5);
		i1 = floor(_3D_M * float3(vx.y, vy.y, vz.y) + 0.5);
		i2 = floor(_3D_M * float3(vx.z, vy.z, vz.z) + 0.5);
		i3 = floor(_3D_M * float3(vx.w, vy.w, vz.w) + 0.5);
	}
	float4 hash = permute(permute(permute(
		  float4(i0.z, i1.z, i2.z, i3.z))
		+ float4(i0.y, i1.y, i2.y, i3.y))
		+ float4(i0.x, i1.x, i2.x, i3.x));
	float4 theta = hash * 3.883222077, // 2 * pi / phi (golden ratio)
	       sz = hash * -0.006920415 + 0.996539792; // 1 - (hash + 1/2) * 2 / 289
	float4 ct = cos(theta), st = sin(theta);
	float4 sz_prime = sqrt(1 - sz * sz); // S is a point on the unit fib sphere
	float4 gx = ct * sz_prime,
	       gy = st * sz_prime,
	       gz = sz;
	if(alpha != 0) {
		float4 psi = hash * 0.108705628; // 10 * pi / 289, chosen to avoid correlation
		float4 sp = sin(psi), cp = cos(psi); // q' from psi on equator
		float4 ctp = st * sp - ct * cp; // q = rotate(cross(s, n), dot(s,n))(q')
		float4 qx = mix(ctp * st, sp, sz),
		       qy = mix(-ctp * ct, cp, sz),
		       qz = -(gy * cp + gx * sp);
		float4 sa = sin(alpha), ca = cos(alpha); // psi and alpha in different planes
		gx = ca * gx + sa * qx;
		gy = ca * gy + sa * qy;
		gz = ca * gz + sa * qz;
	}
	float3 g0 = float3(gx.x, gy.x, gz.x),
	       g1 = float3(gx.y, gy.y, gz.y),
	       g2 = float3(gx.z, gy.z, gz.z),
	       g3 = float3(gx.w, gy.w, gz.w);
	float4 w = max(0.5 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0),
	       ww = w * w,
	       www = ww * w;
	float4 gdotx = float4(dot(g0, x0), dot(g1, x1), dot(g2, x2), dot(g3, x3));
	float n = dot(www, gdotx);
	float4 dw = -6 * ww * gdotx;
	float3 dn0 = www.x * g0 + dw.x * x0,
	       dn1 = www.y * g1 + dw.y * x1,
	       dn2 = www.z * g2 + dw.z * x2,
	       dn3 = www.w * g3 + dw.w * x3;
	return (PSRDNoise3D){
		.value = 39.5 * n,
		.gradient = 39.5 * (dn0 + dn1 + dn2 + dn3)
	};
}

PSRDNoise3D PSRDNoiseAdd(PSRDNoise3D n, PSRDNoise3D add, float add_mul = 1) {
	return { n.value + add.value * add_mul, n.gradient + add.gradient * add_mul };
}

float _3d_dist(float3 p) {
	float3 cq = abs(p - float3(0, 1, 0)) - 1;
	float cd = length(fmax(cq, 0)) + fmin(fmax(cq.x, fmax(cq.y, cq.z)), 0);
	float pd = p.y;
	return min(cd, pd);
}

float3 _3d_norm(float3 p) {
	float2 e = float2(0.01, 0);
	float d = _3d_dist(p);
	return normalize(float3(
		d - _3d_dist(p - e.xyy),
		d - _3d_dist(p - e.yxy),
		d - _3d_dist(p - e.yyx)));
}

#define _3D_RAY_MARCH_MAX_STEPS 100
#define _3D_RAY_MARCH_MAX_DIST 100
#define _3D_RAY_MARCH_SURF_DIST 0.005

float _3d_ray_march(float3 ro, float3 rd) {
	float d = 0;
	for (int i = 0; i < _3D_RAY_MARCH_MAX_STEPS; i++) {
		float3 p = ro + d * rd;
		float ds = _3d_dist(p);
		d += ds;
		if (ds < _3D_RAY_MARCH_SURF_DIST || ds > _3D_RAY_MARCH_MAX_DIST) break;
	}
	return d;
}

float3 _3d_light(float3 p, float alpha) {
	float3 col;
	if (p.y > _3D_RAY_MARCH_SURF_DIST && all(abs(p.zx) < float2(2))) {
		PSRDNoise3D n = { 0, 0 };
		n = PSRDNoiseAdd(n, psrdnoise(1 * p + 0, 8, 10 * alpha / 2), 0.8);
		n = PSRDNoiseAdd(n, psrdnoise(2 * p + 0, 16, 10 * alpha / 4), 0.4);
		n = PSRDNoiseAdd(n, psrdnoise(4 * p + 0, 32, 10 * alpha / 8), 0.2);
		n = PSRDNoiseAdd(n, psrdnoise(8 * p + 0, 64, 10 * alpha / 16), 0.1);
		n = PSRDNoiseAdd(n, psrdnoise(16 * p + 0, 128, 10 * alpha / 32), 0.05);
		col = (1 + n.value + n.gradient) / 2;
	} else {
		col = float3(0.1, 0.15, 0.2);
	}

	float3 n = _3d_norm(p);

	float amb = 0.5 + 0.5 * n.y;
	col += amb * float3(0.1, 0.15, 0.2);

	float3 l = float3(4, 5, 6) - p;
	float ld = length(l);
	l /= ld;
	float dif = fmax(0, dot(l, n));
	if (_3d_ray_march(p + n * 2 * _3D_RAY_MARCH_SURF_DIST , l) < ld) { dif /= 10; }
	col += dif * float3(1, 0.97, 0.85);

	float bac = fmax(0, 0.2 - 0.8 * dot(n, l)) / 5;
	col += bac;

	return 0.5 * (0.3 * col + 0.7 * sqrt(col));
}

inline half4 fragment_3d(
	constant FragmentUniforms &uniforms [[ buffer(0) ]],
	FragmentInput interpolated [[ stage_in ]]
) {
	float aspect = (float)uniforms.viewport.x / (float)uniforms.viewport.y;
	float2 uv = (interpolated.uv - 0.5) * float2(aspect, -1);

	float3 ro = float3(0, 3, 0);
	float a = uniforms.time / 4;
	ro.zx += 5 * float2(cos(a), sin(a));
	float3 vz = normalize(float3(0, 1, 0) - ro);
	float3 vx = cross(float3(0, 1, 0), vz);
	float3 rd = float3x3(vx, cross(vz, vx), vz) * normalize(float3(uv, 1));
	float d = _3d_ray_march(ro, rd);
	float3 p = ro + d * rd;

	float3 value = _3d_light(p, uniforms.time / 4);

	return half4(half3(value), 1);
}


#pragma mark - Fragment

fragment half4 fragment_main(
	constant FragmentUniforms &uniforms [[ buffer(0) ]],
	FragmentInput interpolated [[ stage_in ]]
) {
	if (int(uniforms.time) % 2 == 0) {
		return fragment_2d(uniforms, interpolated);
	} else {
		return fragment_3d(uniforms, interpolated);
	}
}
