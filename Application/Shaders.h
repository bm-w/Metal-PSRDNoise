//
//  Shaders.h
//  Metal-PSRDNoise
//

#ifndef Shaders_h
#define Shaders_h

#include <simd/simd.h>


struct FragmentUniforms {
	float time;
	simd_int2 viewport;
};

#endif /* Shaders_h */
