#version 430
#include "inc/common.glsl"

#ifdef NOISE3D
#define IFNOISE3D(x) x
#define IFENOISE3D(x, y) x
#else
#define IFNOISE3D(x)
#define IFENOISE3D(x, y) y
#endif

layout(local_size_x = 8, local_size_y = 8) in;

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


// OCTAVE_COUNT octaves, 4 gradients for each
// X<<0 | Y<<1 | Z<<2 | Oct<<3
shared IFENOISE3D(vec3, vec2) cachedGradients[OCTAVE_COUNT * 4];

// OCTAVE_COUNT octaves, 4 interpolations, 8 local size
// [interpolation][local<<0 | octave << 3]
shared IFENOISE3D(vec3, vec2) cachedDotData[4][OCTAVE_COUNT][8];

float moPerlin(ivec2 pos) {
	// Calculate node gradients: 4 for each octave, OCTAVE_COUNT octaves

	if(gl_LocalInvocationIndex < OCTAVE_COUNT * 4) {
		const int octaveSize = 8 << (gl_LocalInvocationIndex >> 2);
		const ivec2 octaveAnchorPos = pos / octaveSize; // Assuming workgroup size <= octave size
		
		const ivec2 offset = octaveAnchorPos + ivec2((gl_LocalInvocationIndex & 1), (gl_LocalInvocationIndex >> 1) & 1);

		#ifdef NOISE3D
			const int timeOrigin = int(floor(params.time));

			cachedGradients[gl_LocalInvocationIndex] = mix(
				nodeGradient(ivec3(offset, timeOrigin)),
				nodeGradient(ivec3(offset, timeOrigin + 1)),
				interpolationConstSimple(fract(params.time))
			);

		#else
			cachedGradients[gl_LocalInvocationIndex] = nodeGradient(offset);
		#endif
	}

	barrier();


	for(uint invoIndex = gl_LocalInvocationIndex; invoIndex < OCTAVE_COUNT * 32; invoIndex += 64) {
		const uint offsetId = (invoIndex & 7);
		const uint gradientId = (invoIndex >> 3) & 3;
		const uint octaveId = invoIndex >> 5;

		const uint octaveSize = 8 << octaveId;
		const vec2 offset = fract(vec2(pos - gl_LocalInvocationID.xy + offsetId) / octaveSize);

		const IFENOISE3D(vec3, vec2) gradient = cachedGradients[octaveId << 2 | gradientId];

		cachedDotData[gradientId][octaveId][offsetId] = IFENOISE3D(vec3, vec2)(
			(offset.x - (gradientId & 1)) * gradient.x,
			(offset.y - ((gradientId >> 1) & 1)) * gradient.y
#ifdef NOISE3D
			, gradient.z
#endif
		);
	}

	barrier();

	// Now for each pixel actually compute the noise value
	float result = 0;
	for(uint octaveId = 0; octaveId < OCTAVE_COUNT; octaveId++) {
		const uint octaveSize = 8 << octaveId;
		const vec2 offset = fract(vec2(pos) / octaveSize);

		const uvec2 locIx = gl_LocalInvocationID.xy;// | (octaveId << 3);

		const float dotProduct1 = cachedDotData[0][octaveId][locIx.x].x + cachedDotData[0][octaveId][locIx.y].y IFNOISE3D(+ cachedDotData[0][octaveId][0].z);
		const float dotProduct2 = cachedDotData[1][octaveId][locIx.x].x + cachedDotData[1][octaveId][locIx.y].y IFNOISE3D(+ cachedDotData[1][octaveId][0].z);

		const float dotProduct3 = cachedDotData[2][octaveId][locIx.x].x + cachedDotData[2][octaveId][locIx.y].y IFNOISE3D(+ cachedDotData[2][octaveId][0].z);
		const float dotProduct4 = cachedDotData[3][octaveId][locIx.x].x + cachedDotData[3][octaveId][locIx.y].y IFNOISE3D(+ cachedDotData[3][octaveId][0].z);

		const vec2 interpolation1 = mix(vec2(dotProduct1, dotProduct3), vec2(dotProduct2, dotProduct4), interpolationConst(offset.x));
		const float interpolation2 = mix(interpolation1.x, interpolation1.y, interpolationConst(offset.y));

		result += interpolation2 * params.octaveWeight[octaveId];
	}

	return result;
}

void main() {
	float val = 0;

	for(int i = 0; i < params.executionCount; i++)
		val = val * 0.000001 + moPerlin(ivec2(gl_GlobalInvocationID.xy) + (i+1) % params.executionCount * 1271);

	val = clamp(0.5 + val/2, 0, 1);
	const int rval = int(round(val * 255));

	for(int y = 0; y < params.chunkSize; y++)
		imageStore(world, ivec3(gl_GlobalInvocationID.x, y, gl_GlobalInvocationID.y), uvec4(uint(clamp(rval - y, 0, 255)), 0, 0, 0));

	//imageStore(world, ivec3(gl_GlobalInvocationID.xy,params.chunkSize-1), uvec4(uint(round(val * 255)), 0, 0, 0));
}