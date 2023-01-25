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


fragment half4 fragment_main(
	constant FragmentUniforms &uniforms [[ buffer(0) ]],
	FragmentInput interpolated [[ stage_in ]]
) {
	return half4(half2(interpolated.uv), 0.5 + 0.5 * cos(uniforms.modifier), 1);
}
