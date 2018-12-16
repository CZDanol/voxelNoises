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
	return v2 * val + v1 * (1-val);
}

shared vec3 cachedGradients[8];

float optimizedPerlin(vec3 normalizedCoord) {
	const vec3 anchorNodePos = floor(normalizedCoord);

	if(gl_LocalInvocationID.x < 2 && gl_LocalInvocationID.y < 2 && gl_LocalInvocationID.z < 2)
		cachedGradients[gl_LocalInvocationID.x | gl_LocalInvocationID.y << 1 | gl_LocalInvocationID.z << 2] = nodeGradient(anchorNodePos + gl_LocalInvocationID);

	barrier();

	const vec3 offset = fract(normalizedCoord);

	const float gradient1 = dot(offset, cachedGradients[0]);
	const float gradient2 = dot(offset - vec3(1,0,0), cachedGradients[1]);

	const float gradient3 = dot(offset - vec3(0,1,0), cachedGradients[2]);
	const float gradient4 = dot(offset - vec3(1,1,0), cachedGradients[3]);
	
	const float gradient5 = dot(offset - vec3(0,0,1), cachedGradients[4]);
	const float gradient6 = dot(offset - vec3(1,0,1), cachedGradients[5]);
	
	const float gradient7 = dot(offset - vec3(0,1,1), cachedGradients[6]);
	const float gradient8 = dot(offset - vec3(1,1,1), cachedGradients[7]);

	const float xiplVal = interpolationConst(offset.x);
	const float xiplValInv = 1 - xiplVal;

	const float interpolation1 = gradient1 * xiplValInv + gradient2 * xiplVal;
	const float interpolation2 = gradient3 * xiplValInv + gradient4 * xiplVal;
	const float interpolation3 = gradient5 * xiplValInv + gradient6 * xiplVal;
	const float interpolation4 = gradient7 * xiplValInv + gradient8 * xiplVal;

	const float yiplVal = interpolationConst(offset.y);
	const float yiplValInv = 1 - yiplVal;

	const float interpolation5 = interpolation1 * yiplValInv + interpolation2 * yiplVal;
	const float interpolation6 = interpolation3 * yiplValInv + interpolation4 * yiplVal;

	const float interpolation7 = interpolate(interpolation5, interpolation6, offset.z);
	return interpolation7;
}

void main() {
	float val = 0;

	for(int i = 0; i < params.executionCount; i++)
		val = val * 0.000001 + optimizedPerlin(vec3(gl_GlobalInvocationID.xyz + (i+1) % params.executionCount) / params.octaveSize);

	val = clamp(0.5 + val/2, 0, 1);

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(uint(round(val * 255)), 0, 0, 0));
}