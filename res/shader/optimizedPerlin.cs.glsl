#version 430
#include "inc/common.glsl"

#ifdef NOISE4D
#define IFNOISE4D(x) x
#define IFENOISE4D(x, y) x
#else
#define IFNOISE4D(x)
#define IFENOISE4D(x, y) y
#endif

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

float interpolationConst(float progress) {
	const float ppow2 = progress * progress;
	const float ppow4 = ppow2 * ppow2;

	return //
		6 * progress * ppow4 // 6 * t^5
		- 15 * ppow4 // - 15 * t^4
		+ 10 * ppow2 * progress; // + 10 * t^3
}

float interpolationConstSimple(float progress) {
	const float ppow2 = progress * progress;

	return //
		3 * ppow2 // 3 * t^2
		- 2 * ppow2 * progress; // - 2 * t^3
}

// Interpolation function 6*t^5 - 15 * t^4 + 10 * t^3
float interpolate(float v1, float v2, float progress) {
	const float val = interpolationConst(progress);
	return mix(v1, v2, interpolationConst(progress));
}


// OCTAVE_COUNT octaves, 8 gradients for each
// X<<0 | Y<<1 | Z<<2 | Oct<<3
shared IFENOISE4D(vec4, vec3) cachedGradients[OCTAVE_COUNT * 8];

// 8 interpolations, OCTAVE_COUNT octaves, 8 local size
shared IFENOISE4D(vec4, vec3) cachedDotData[8][OCTAVE_COUNT][8];

// 3 dimensions (round to 4), 4 octaves, 8 invocations in each
//shared float cachedInterpolationConstants[3][4][8];

float moPerlin(ivec3 pos) {
	// Calculate node gradients: 8 for each octave, OCTAVE_COUNT octaves

	if(gl_LocalInvocationIndex < 8 * OCTAVE_COUNT) {
		const int octaveSize = 8 << (gl_LocalInvocationIndex >> 3); // Smallest octave size is 8, doubles each octave
		const ivec3 octaveAnchorPos = pos / octaveSize; // Assuming workgroup size <= octave size

		const ivec3 offset = octaveAnchorPos + ivec3((gl_LocalInvocationIndex & 1), (gl_LocalInvocationIndex >> 1) & 1, (gl_LocalInvocationIndex >> 2) & 1);
		
		#ifdef NOISE4D
			const int timeOrigin = int(floor(params.time));

			cachedGradients[gl_LocalInvocationIndex] = mix(
				nodeGradient(ivec4(offset, timeOrigin)),
				nodeGradient(ivec4(offset, timeOrigin + 1)),
				interpolationConstSimple(fract(params.time))
			);

		#else
			cachedGradients[gl_LocalInvocationIndex] = nodeGradient(offset);
		#endif

		//cachedGradients[gl_LocalInvocationIndex] = nodeGradient(octaveAnchorPos + gradientOffsetVectors[gl_LocalInvocationIndex & 7]);
	}

	barrier();

	/*
		Optimize the dot product used in the noise
		The dot product is used as: dot(offset + vec3(C, C, C), cachedGradients[C]); where C are constants
		Dot is: Lx*Rx + Ly*Ry + Lz*Rz

		For each X, Y, Z planes in the workgroup, the Ld*Rd part is same (d - dimesion)
		So we can precalculate it
	*/
	if(gl_LocalInvocationIndex < OCTAVE_COUNT * 64) {
		const uint offsetId = (gl_LocalInvocationIndex & 7);
		const uint gradientId = (gl_LocalInvocationIndex >> 3) & 7;
		const uint octaveId = gl_LocalInvocationIndex >> 6;

		const uint octaveSize = 8 << octaveId;
		const vec3 offset = fract(vec3(pos - gl_LocalInvocationID + offsetId) / octaveSize); // pos - gl_LocalInvocationID = workgroup origin

		const IFENOISE4D(vec4, vec3) gradient = cachedGradients[octaveId << 3 | gradientId];

		cachedDotData[gradientId][octaveId][offsetId] = IFENOISE4D(vec4, vec3)(
			(offset.x - (gradientId & 1)) * gradient.x,
			(offset.y - ((gradientId >> 1) & 1)) * gradient.y,
			(offset.z - ((gradientId >> 2) & 1)) * gradient.z
#ifdef NOISE4D
			, gradient.w
#endif
		);
	}

	/*if(gl_LocalInvocationIndex < 96) {
		const uint offsetId = gl_LocalInvocationIndex & 7;
		const uint octaveId = (gl_LocalInvocationIndex >> 3) & 3;
		const uint dimensionId = (gl_LocalInvocationIndex >> 5) & 3;

		const uint octaveSize = 16 << octaveId;

		const float offset = fract(float(pos[dimensionId] - gl_LocalInvocationID[dimensionId] + offsetId) / octaveSize);
		cachedInterpolationConstants[dimensionId][octaveId][offsetId] = interpolationConst(offset);
	}*/

	barrier();

	// Now for each pixel actually compute the noise value
	float result = 0;
	for(uint octaveId = 0; octaveId < OCTAVE_COUNT; octaveId++) {
		const uint octaveSize = 8 << octaveId;
		const vec3 offset = fract(vec3(pos) / octaveSize);

		const uvec3 locIx = gl_LocalInvocationID;// | (octaveId << 3);

		const float dotProduct1 = cachedDotData[0][octaveId][locIx.x].x + cachedDotData[0][octaveId][locIx.y].y + cachedDotData[0][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[0][octaveId][0].w);
		const float dotProduct2 = cachedDotData[1][octaveId][locIx.x].x + cachedDotData[1][octaveId][locIx.y].y + cachedDotData[1][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[1][octaveId][0].w);

		const float dotProduct3 = cachedDotData[2][octaveId][locIx.x].x + cachedDotData[2][octaveId][locIx.y].y + cachedDotData[2][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[2][octaveId][0].w);
		const float dotProduct4 = cachedDotData[3][octaveId][locIx.x].x + cachedDotData[3][octaveId][locIx.y].y + cachedDotData[3][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[3][octaveId][0].w);

		const float dotProduct5 = cachedDotData[4][octaveId][locIx.x].x + cachedDotData[4][octaveId][locIx.y].y + cachedDotData[4][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[4][octaveId][0].w);
		const float dotProduct6 = cachedDotData[5][octaveId][locIx.x].x + cachedDotData[5][octaveId][locIx.y].y + cachedDotData[5][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[5][octaveId][0].w);

		const float dotProduct7 = cachedDotData[6][octaveId][locIx.x].x + cachedDotData[6][octaveId][locIx.y].y + cachedDotData[6][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[6][octaveId][0].w);
		const float dotProduct8 = cachedDotData[7][octaveId][locIx.x].x + cachedDotData[7][octaveId][locIx.y].y + cachedDotData[7][octaveId][locIx.z].z IFNOISE4D(+ cachedDotData[7][octaveId][0].w);

		/*const float xiplVal = interpolationConst(offset.x);
		//const float xiplVal = cachedInterpolationConstants[0][octaveId][gl_LocalInvocationID.x];
		const float xiplValInv = 1 - xiplVal;

		const float interpolation1 = dotProduct1 * xiplValInv + dotProduct2 * xiplVal;
		const float interpolation2 = dotProduct3 * xiplValInv + dotProduct4 * xiplVal;
		const float interpolation3 = dotProduct5 * xiplValInv + dotProduct6 * xiplVal;
		const float interpolation4 = dotProduct7 * xiplValInv + dotProduct8 * xiplVal;

		const float yiplVal = interpolationConst(offset.y);
		//const float yiplVal = cachedInterpolationConstants[1][octaveId][gl_LocalInvocationID.y];
		const float yiplValInv = 1 - yiplVal;

		const float interpolation5 = interpolation1 * yiplValInv + interpolation2 * yiplVal;
		const float interpolation6 = interpolation3 * yiplValInv + interpolation4 * yiplVal;

		const float interpolation7 = interpolate(interpolation5, interpolation6, offset.z);

		result += interpolation7 * params.octaveWeight[octaveId];*/

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

		result += interpolation3 * params.octaveWeight[octaveId];
	}

	return result;
}

void main() {
	float val = 0;

	// Weirds constants there are to make sure that each execution is different
	for(int i = 0; i < params.executionCount; i++)
		val = val * 0.000001 + moPerlin(ivec3(gl_GlobalInvocationID.xyz) + (i+1) % params.executionCount * 1271);

	val = clamp(0.5 + val/2, 0, 1);

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(uint(round(val * 255)), 0, 0, 0));
}