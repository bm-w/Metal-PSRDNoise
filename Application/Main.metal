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


struct PSRDNoise {
	float value;
	float2 gradient;
};

/// Adapted from: https://github.com/stegu/psrdnoise/blob/4d627ff/src/psrdnoise2-min.glsl#L5
/// psrdnoise (c) Stefan Gustavson and Ian McEwan
/// Ver. 2021-12-02, published under the MIT license:
/// https://github.com/stegu/psrdnoise/
PSRDNoise psrdnoise(float2 x, float2 period, float alpha) {
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

PSRDNoise PSRDNoiseAdd(PSRDNoise n, PSRDNoise add, float add_mul = 1) {
	return { n.value + add.value * add_mul, n.gradient + add.gradient * add_mul };
}

fragment half4 fragment_main(
	constant FragmentUniforms &uniforms [[ buffer(0) ]],
	FragmentInput interpolated [[ stage_in ]]
) {
	float scale = 3;
	float aspect = float(uniforms.viewport.x) / float(uniforms.viewport.y);
	float3x2 uv_to_st = uniforms.viewport.x > uniforms.viewport.y
		? float3x2(scale * aspect, 0, 0, scale, -scale * aspect / 2, -scale / 2)
		: float3x2(scale, 0, 0, scale / aspect, -scale / 2, -scale / aspect / 2);
	float2 st = uv_to_st * float3(interpolated.uv, 1);

	PSRDNoise n = { 0, 0 };
	n = PSRDNoiseAdd(n, psrdnoise(1 * st + 0.0, 8, uniforms.modifier / 2), 0.8);
	n = PSRDNoiseAdd(n, psrdnoise(2 * st + 0.0, 16, uniforms.modifier / 4), 0.4);
	n = PSRDNoiseAdd(n, psrdnoise(4 * st + 0.0, 32, uniforms.modifier / 8), 0.2);
	n = PSRDNoiseAdd(n, psrdnoise(8 * st + 0.0, 64, uniforms.modifier / 16), 0.1);
	n = PSRDNoiseAdd(n, psrdnoise(16 * st + 0.0, 128, uniforms.modifier / 32), 0.05);
	return (half4(1 + n.value, n.gradient.x, n.gradient.y, 2)) / 2;
}
