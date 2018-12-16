#version 430
#include "inc/common.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

float interpolationConst(float progress) {
	const float ppow2 = progress * progress;
	const float ppow4 = ppow2 * ppow2;

	return //
		6 * progress * ppow4 // 6 * t^5
		- 15 * ppow4 // - 15 * t^4
		+ 10 * ppow2 * progress; // + 10 * t^3
}

// Interpolation function 6*t^5 - 15 * t^4 + 10 * t^3
float interpolate(float v1, float v2, float progress) {
	const float val = interpolationConst(progress);
	return mix(v1, v2, interpolationConst(progress));
}

shared vec3 cachedGradients[8];

float optimizedPerlin(vec3 normalizedCoord) {
	const vec3 anchorNodePos = floor(normalizedCoord);

	if(gl_LocalInvocationID.x < 2 && gl_LocalInvocationID.y < 2 && gl_LocalInvocationID.z < 2)
		cachedGradients[gl_LocalInvocationID.x | gl_LocalInvocationID.y << 1 | gl_LocalInvocationID.z << 2] = nodeGradient(anchorNodePos + gl_LocalInvocationID);

	barrier();

	const vec3 offset = fract(normalizedCoord);

	const float dotProduct1 = dot(offset, cachedGradients[0]);
	const float dotProduct2 = dot(offset - vec3(1,0,0), cachedGradients[1]);

	const float dotProduct3 = dot(offset - vec3(0,1,0), cachedGradients[2]);
	const float dotProduct4 = dot(offset - vec3(1,1,0), cachedGradients[3]);
	
	const float dotProduct5 = dot(offset - vec3(0,0,1), cachedGradients[4]);
	const float dotProduct6 = dot(offset - vec3(1,0,1), cachedGradients[5]);
	
	const float dotProduct7 = dot(offset - vec3(0,1,1), cachedGradients[6]);
	const float dotProduct8 = dot(offset - vec3(1,1,1), cachedGradients[7]);

	const float xiplVal = interpolationConst(offset.x);
	const float xiplValInv = 1 - xiplVal;

	const vec4 interpolation1 = mix(
		vec4(dotProduct1, dotProduct3, dotProduct5, dotProduct7),
		vec4(dotProduct2, dotProduct4, dotProduct6, dotProduct8),
		interpolationConst(offset.x)
	);
	const vec2 interpolation2 = mix(
		vec2(interpolation1[0], interpolation1[2]),
		vec2(interpolation1[1], interpolation1[3]),
		interpolationConst(offset.y)
	);
	const float interpolation3 = mix(
		interpolation2.x,
		interpolation2.y,
		interpolationConst(offset.z)
	);
	return interpolation3;
}

void main() {
	float val = 0;

	for(int i = 0; i < params.executionCount; i++) {
		const vec3 pos = vec3(gl_GlobalInvocationID.xyz + (i+1) % params.executionCount);

		float tmp = 0;
		for(int j = 0; j < OCTAVE_COUNT; j++)
			tmp += optimizedPerlin(pos / (8 << j)) * params.octaveWeight[j];

		val = val * 0.000001 + tmp;
	}

	val = clamp(0.5 + val/2, 0, 1);

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(uint(round(val * 255)), 0, 0, 0));
}