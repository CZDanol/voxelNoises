#version 430
#include "inc/common.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

float simplexContrib(vec3 offset) {
	//return pow(max(0, 0.6 - offset.x * offset.x - offset.y * offset.y - offset.z * offset.z),4);

	const float res1 = max(0, 0.6 - offset.x * offset.x - offset.y * offset.y - offset.z * offset.z);
	const float res2 = res1 * res1;

	return res2 * res2;
}

const vec3 simplexCoord1[8] = {
	vec3(0,0,1), // X !> Y,	X !> Z,	Y !> Z
	vec3(0,0,1), // X > Y,	X !> Z,	Y !> Z
	vec3(0,0,0), // X !> Y,	X > Z,	Y !> Z
	vec3(1,0,0), // X > Y,	X > Z,	Y !> Z
	vec3(0,1,0), // X !> Y,	X !> Z,	Y > Z
	vec3(0,0,0), // X > Y,	X !> Z,	Y > Z
	vec3(0,1,0), // X !> Y,	X > Z,	Y > Z
	vec3(1,0,0)  // X > Y,	X > Z,	Y > Z
};
const vec3 simplexCoord2[8] = {
	vec3(0,1,1), // X !> Y,	X !> Z,	Y !> Z
	vec3(1,0,1), // X > Y,	X !> Z,	Y !> Z
	vec3(0,0,0), // X !> Y,	X > Z,	Y !> Z
	vec3(1,0,1), // X > Y,	X > Z,	Y !> Z
	vec3(0,1,1), // X !> Y,	X !> Z,	Y > Z
	vec3(0,0,0), // X > Y,	X !> Z,	Y > Z
	vec3(1,1,0), // X !> Y,	X > Z,	Y > Z
	vec3(1,1,0)  // X > Y,	X > Z,	Y > Z
};

shared vec3 cachedSimplexGradients[3][3][3];
shared vec3 origAnchorPos;

float optimizedSimplex(vec3 normalizedCoord) {
	const vec3 skewedCoord = normalizedCoord + (normalizedCoord.x + normalizedCoord.y + normalizedCoord.z) * 0.3333333;

	const vec3 anchorNodePos = floor(skewedCoord);
	const vec3 unskewedAnchorNodePos = anchorNodePos - (anchorNodePos.x + anchorNodePos.y + anchorNodePos.z) * 0.1666666; // 1/6

	if(gl_LocalInvocationID == vec3(0,0,0))
		origAnchorPos = anchorNodePos;

	barrier();

	if(gl_LocalInvocationID.x < 3 && gl_LocalInvocationID.y < 3 && gl_LocalInvocationID.z < 3)
		cachedSimplexGradients[gl_LocalInvocationID.x][gl_LocalInvocationID.y][gl_LocalInvocationID.z] = nodeGradient(origAnchorPos + gl_LocalInvocationID);

	barrier();

	const vec3 offset = fract(skewedCoord);
	const vec3 unskewedOffset = normalizedCoord - unskewedAnchorNodePos;

	uint ix = uint(unskewedOffset.x > unskewedOffset.y) | uint(unskewedOffset.x > unskewedOffset.z) << 1 | uint(unskewedOffset.y > unskewedOffset.z) << 2;
	// TODO: cache in shared memory
	const vec3 coord1 = simplexCoord1[ix];
	const vec3 coord2 = simplexCoord2[ix];

	/*
		Unskewed = skewed - (x+y+z) * 1/6
		so
		unskewed = unskewedAnchor + coord - (cx+cy+cz) * 1/6

		unskewedOffset = normalizedCoord - unskewed
		unskewedOffset = unskewedOffset0 - coord + (coord.x+coord.y+coord.z)/6

		coord1 has +1 in one axis (cx+cy+cz = 1)
		coord2 has +1 in two axes (cx+cy+cz = 2)
		coord3 has +1 in all three axes (cx+cy+cz = 3)
	*/
	const vec3 unskewedOffset1 = unskewedOffset - coord1 + 0.1666666;
	const vec3 unskewedOffset2 = unskewedOffset - coord2 + 0.3333333; // 2/6 = 1/3
	const vec3 unskewedOffset3 = unskewedOffset - vec3(0.5,0.5,0.5); // 3/6 = 1/2; - 1 + 1/2

	const ivec3 anchorDiff = ivec3(anchorNodePos - origAnchorPos);

	const ivec3 gix0 = anchorDiff;
	const vec3 gradient0 = cachedSimplexGradients[gix0.x][gix0.y][gix0.z];

	const ivec3 gix1 = anchorDiff + ivec3(coord1);
	const vec3 gradient1 = cachedSimplexGradients[gix1.x][gix1.y][gix1.z];

	const ivec3 gix2 = anchorDiff + ivec3(coord2);
	const vec3 gradient2 = cachedSimplexGradients[gix2.x][gix2.y][gix2.z];

	const ivec3 gix3 = anchorDiff + ivec3(1,1,1);
	const vec3 gradient3 = cachedSimplexGradients[gix3.x][gix3.y][gix3.z];

	const float contrib0 = simplexContrib(unskewedOffset) * dot(unskewedOffset, gradient0);
	const float contrib1 = simplexContrib(unskewedOffset1) * dot(unskewedOffset1, gradient1);
	const float contrib2 = simplexContrib(unskewedOffset2) * dot(unskewedOffset2, gradient2);
	const float contrib3 = simplexContrib(unskewedOffset3) * dot(unskewedOffset3, gradient3);

	return (contrib0 + contrib1 + contrib2 + contrib3) * 27;
}

void main() {
	float val = 0;

	for(int i = 0; i < params.executionCount; i++)
		val = val * 0.000001 + optimizedSimplex(vec3(gl_GlobalInvocationID.xyz + (i+1) % params.executionCount) / params.octaveSize);

	val = clamp(0.5 + val/2, 0, 1);

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(uint(round(val * 255)), 0, 0, 0));
}
/*void main() {
	float val = 0;

	for(int i = 0; i < params.executionCount; i++) {
		const vec3 pos = vec3(gl_GlobalInvocationID.xyz + (i+1) % params.executionCount);

		float tmp = 0;
		for(int j = 0; j < OCTAVE_COUNT; j++)
			tmp += optimizedSimplex(pos / (16 << j)) * params.octaveWeight[j];

		val = val * 0.000001 + tmp;
	}

	val = clamp(0.5 + val/2, 0, 1);

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(uint(round(val * 255)), 0, 0, 0));
}*/