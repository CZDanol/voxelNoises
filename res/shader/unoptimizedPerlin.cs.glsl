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

float unoptimizedPerlin(vec3 normalizedCoord) {
	const vec3 anchorNodePos = floor(normalizedCoord);
	const vec3 offset = fract(normalizedCoord);

	const float dotProduct1 = dot(offset, nodeGradient(anchorNodePos));
	const float dotProduct2 = dot(offset - vec3(1,0,0), nodeGradient(anchorNodePos + vec3(1,0,0)));

	const float dotProduct3 = dot(offset - vec3(0,1,0), nodeGradient(anchorNodePos + vec3(0,1,0)));
	const float dotProduct4 = dot(offset - vec3(1,1,0), nodeGradient(anchorNodePos + vec3(1,1,0)));
	
	const float dotProduct5 = dot(offset - vec3(0,0,1), nodeGradient(anchorNodePos + vec3(0,0,1)));
	const float dotProduct6 = dot(offset - vec3(1,0,1), nodeGradient(anchorNodePos + vec3(1,0,1)));
	
	const float dotProduct7 = dot(offset - vec3(0,1,1), nodeGradient(anchorNodePos + vec3(0,1,1)));
	const float dotProduct8 = dot(offset - vec3(1,1,1), nodeGradient(anchorNodePos + vec3(1,1,1)));

	/*const float xiplVal = interpolationConst(offset.x);
	const float xiplValInv = 1 - xiplVal;

	const float interpolation1 = dotProduct1 * xiplValInv + dotProduct2 * xiplVal;
	const float interpolation2 = dotProduct3 * xiplValInv + dotProduct4 * xiplVal;
	const float interpolation3 = dotProduct5 * xiplValInv + dotProduct6 * xiplVal;
	const float interpolation4 = dotProduct7 * xiplValInv + dotProduct8 * xiplVal;

	const float yiplVal = interpolationConst(offset.y);
	const float yiplValInv = 1 - yiplVal;

	const float interpolation5 = interpolation1 * yiplValInv + interpolation2 * yiplVal;
	const float interpolation6 = interpolation3 * yiplValInv + interpolation4 * yiplVal;

	const float interpolation7 = interpolate(interpolation5, interpolation6, offset.z);
	return interpolation7;*/

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
			tmp += unoptimizedPerlin(pos / (8 << j)) * params.octaveWeight[j];

		val = val * 0.000001 + tmp;
	}

	val = clamp(0.5 + val/2, 0, 1);

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(uint(round(val * 255)), 0, 0, 0));
}