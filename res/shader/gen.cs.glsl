#version 430

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
layout(r8ui, binding = 0) uniform uimage3D world;
uniform int chunkSize;

uint rand(uint seed) {
	uint x = seed;
	x += ( x << 10u );
	x ^= ( x >>  6u );
	x += ( x <<  3u );
	x ^= ( x >> 11u );
	x += ( x << 15u );
	return x;
}

void setBlock(bool set) {
	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(set ? 255 : 0, 0, 0, 0));
}

bool mainFractal() {
	vec3 tmp = vec3(gl_GlobalInvocationID.xyz) / float(chunkSize);
	for(int d = 0; d < 7; d++) {
		if(tmp.x < 0.5 && tmp.y < 0.5 && tmp.z < 0.5)
			return false;

		if(tmp.x >= 0.5)
			tmp.x -= 0.5;

		if(tmp.y >= 0.5)
			tmp.y -= 0.5;

		if(tmp.z >= 0.5)
			tmp.z -= 0.5;

		tmp *= 2;
	}

	return true;
}

bool mainSphere() {
	return length(ivec3(gl_GlobalInvocationID.xyz) - ivec3(chunkSize/2, chunkSize/2, chunkSize/2)) < chunkSize / 2;
}

const int gradientCount = 16;
const vec3 gradients[gradientCount] = {
	vec3(0,1,1), vec3(0,1,-1),
	vec3(0,-1,1), vec3(0,-1,-1),
	vec3(1,0,1), vec3(1,0,-1),
	vec3(-1,0,1), vec3(-1,0,-1),
	vec3(1,1,0), vec3(1,-1,0),
	vec3(-1,1,0), vec3(-1,-1,0),

	// Added to round to 16 as suggested by Ken Perlin's Improving Noise article
	vec3(1,1,0), vec3(-1,1,0),
	vec3(0,-1,1), vec3(0,-1,-1)
};

uint hash(uint x) {
	x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = (x >> 16) ^ x;
  return x;
}

vec3 nodeGradient(vec3 pos) {
	uint t = hash(uint(pos.x));
	t = hash(t ^ uint(pos.y));
	t = hash(t ^ uint(pos.z));

	return gradients[t % gradientCount];
}

// Interpolation function 6*t^5 - 15 * t^4 + 10 * t^3
float interpolate(float v1, float v2, float progress) {
	const float ppow2 = progress * progress;
	const float ppow4 = ppow2 * ppow2;

	const float val = //
		6 * progress * ppow4 // 6 * t^5
		- 15 * ppow4 // - 15 * t^4
		+ 10 * ppow2 * progress; // + 10 * t^3

	return v2 * val + v1 * (1-val);
}

float interpolationConst(float progress) {
	const float ppow2 = progress * progress;
	const float ppow4 = ppow2 * ppow2;

	return //
		6 * progress * ppow4 // 6 * t^5
		- 15 * ppow4 // - 15 * t^4
		+ 10 * ppow2 * progress; // + 10 * t^3
}

float perlin(vec3 normalizedCoord) {
	const vec3 anchorNodePos = floor(normalizedCoord);
	const vec3 offset = normalizedCoord - anchorNodePos;

	const float gradient1 = dot(offset, nodeGradient(anchorNodePos));
	const float gradient2 = dot(offset - vec3(1,0,0), nodeGradient(anchorNodePos + vec3(1,0,0)));

	const float gradient3 = dot(offset - vec3(0,1,0), nodeGradient(anchorNodePos + vec3(0,1,0)));
	const float gradient4 = dot(offset - vec3(1,1,0), nodeGradient(anchorNodePos + vec3(1,1,0)));

	const float gradient5 = dot(offset - vec3(0,0,1), nodeGradient(anchorNodePos + vec3(0,0,1)));
	const float gradient6 = dot(offset - vec3(1,0,1), nodeGradient(anchorNodePos + vec3(1,0,1)));

	const float gradient7 = dot(offset - vec3(0,1,1), nodeGradient(anchorNodePos + vec3(0,1,1)));
	const float gradient8 = dot(offset - vec3(1,1,1), nodeGradient(anchorNodePos + vec3(1,1,1)));

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

shared vec3 cachedGradients[8];

float optimizedPerlin(vec3 normalizedCoord, float offsetIncrease) {
	const vec3 anchorNodePos = floor(normalizedCoord);

	if(gl_LocalInvocationID.x < 2 && gl_LocalInvocationID.y < 2 && gl_LocalInvocationID.z < 2)
		cachedGradients[gl_LocalInvocationID.x | gl_LocalInvocationID.y << 1 | gl_LocalInvocationID.z << 2] = nodeGradient(anchorNodePos + gl_LocalInvocationID);

	barrier();

	const vec3 offset = normalizedCoord - anchorNodePos;

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

float simplex(vec3 normalizedCoord) {
	const vec3 skewedCoord = normalizedCoord + (normalizedCoord.x + normalizedCoord.y + normalizedCoord.z) * 0.3333333;

	const vec3 anchorNodePos = floor(skewedCoord);

	const vec3 unskewedAnchorNodePos = anchorNodePos - (anchorNodePos.x + anchorNodePos.y + anchorNodePos.z) * 0.1666666; // 1/6

	const vec3 offset = skewedCoord - anchorNodePos;
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

	const vec3 gradient0 = nodeGradient(anchorNodePos);
	const vec3 gradient1 = nodeGradient(anchorNodePos + coord1);
	const vec3 gradient2 = nodeGradient(anchorNodePos + coord2);
	const vec3 gradient3 = nodeGradient(anchorNodePos + vec3(1,1,1));

	const float contrib0 = simplexContrib(unskewedOffset) * dot(unskewedOffset, gradient0);
	const float contrib1 = simplexContrib(unskewedOffset1) * dot(unskewedOffset1, gradient1);
	const float contrib2 = simplexContrib(unskewedOffset2) * dot(unskewedOffset2, gradient2);
	const float contrib3 = simplexContrib(unskewedOffset3) * dot(unskewedOffset3, gradient3);

	return (contrib0 + contrib1 + contrib2 + contrib3) * 27;
}

const uint optimizedSimplexCoord1[8] = {
	4, 4, 0, 1, 2, 0, 2, 1
};
const uint optimizedSimplexCoord2[8] = {
	6, 5, 0, 5, 6, 0, 3, 3
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

	const vec3 offset = skewedCoord - anchorNodePos;
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

	const ivec3 gix1 = anchorDiff + ivec3(simplexCoord1[ix]);
	const vec3 gradient1 = cachedSimplexGradients[gix1.x][gix1.y][gix1.z];

	const ivec3 gix2 = anchorDiff + ivec3(simplexCoord2[ix]);
	const vec3 gradient2 = cachedSimplexGradients[gix2.x][gix2.y][gix2.z];

	const ivec3 gix3 = anchorDiff + ivec3(1,1,1);
	const vec3 gradient3 = cachedSimplexGradients[gix3.x][gix3.y][gix3.z];

	const float contrib0 = simplexContrib(unskewedOffset) * dot(unskewedOffset, gradient0);
	const float contrib1 = simplexContrib(unskewedOffset1) * dot(unskewedOffset1, gradient1);
	const float contrib2 = simplexContrib(unskewedOffset2) * dot(unskewedOffset2, gradient2);
	const float contrib3 = simplexContrib(unskewedOffset3) * dot(unskewedOffset3, gradient3);

	return (contrib0 + contrib1 + contrib2 + contrib3) * 27;
}

#define VORONOI_MAX_POINTS_PER_REGION 2
#define VORONOI_POINTS_RESOLUTION 1024

struct VoronoiRegion {
	uint pointCount;
	vec2 points[VORONOI_MAX_POINTS_PER_REGION];
};

// Returns voronoi points for the given region
VoronoiRegion voronoiRegion(ivec2 regionPos) {
	uint h = hash(regionPos.x);
	h = hash(h ^ regionPos.y);

	VoronoiRegion result;
	result.pointCount = 1 + h % (VORONOI_MAX_POINTS_PER_REGION - 1);

	for(uint i = 0; i < result.pointCount; i++) {
		h = hash(h);
		result.points[i].x = float(h % VORONOI_POINTS_RESOLUTION) / VORONOI_POINTS_RESOLUTION;
		h = hash(h);
		result.points[i].y = float(h % VORONOI_POINTS_RESOLUTION) / VORONOI_POINTS_RESOLUTION;
	}

	return result;
}

float voronoiNearestPointDistance(ivec2 regionPos, vec2 pointPos) {
	VoronoiRegion region = voronoiRegion(regionPos);

	float result = distance(pointPos, region.points[0]);

	for(uint i = 1; i < region.pointCount; i++)
		result = min(result, distance(pointPos, region.points[i]));

	return result;
}

float voronoi(vec2 normalizedCoord) {
	const vec2 fregionPos = floor(normalizedCoord);
	const ivec2 regionPos = ivec2(fregionPos);

	const vec2 localPos = normalizedCoord - fregionPos;

	const float dist1 = min(
		voronoiNearestPointDistance(regionPos + ivec2(-1, -1), localPos + vec2(1, 1)),
		voronoiNearestPointDistance(regionPos + ivec2(0, -1), localPos + vec2(0, 1))
		);

	const float dist2 = min(
		voronoiNearestPointDistance(regionPos + ivec2(1, -1), localPos + vec2(-1, 1)),
		voronoiNearestPointDistance(regionPos + ivec2(-1, 0), localPos + vec2(1, 0))
		);

	const float dist3 = min(
		voronoiNearestPointDistance(regionPos + ivec2(0, 0), localPos + vec2(0, 0)),
		voronoiNearestPointDistance(regionPos + ivec2(1, 0), localPos + vec2(-1, 0))
		);

	const float dist4 = min(
		voronoiNearestPointDistance(regionPos + ivec2(-1, 1), localPos + vec2(1, -1)),
		voronoiNearestPointDistance(regionPos + ivec2(0, 1), localPos + vec2(0, -1))
		);

	const float dist5 = min(dist1, dist2);
	const float dist6 = min(dist3, dist4);

	const float dist7 = min(dist5, dist6);

	const float dist8 = min(
		dist7,
		voronoiNearestPointDistance(regionPos + ivec2(1, 1), localPos + vec2(-1, -1))
		);

	return dist8 / sqrt(2);
}

bool mainPerlin(vec3 pos) {
	return perlin(pos / 32) > 0.3;
}

bool mainOptimizedPerlin(vec3 pos) {
	return optimizedPerlin(pos / 32, 1.0 / 32.0) > 0.3;
}

bool mainSimplex(vec3 pos) {
	return simplex(pos / 64) > 0.3;
}

bool mainOptimizedSimplex(vec3 pos) {
	return optimizedSimplex(pos / 64) > 0.3;
}

bool mainVoronoi(vec3 pos) {
	//return max(0.1, voronoi(pos.xz / 32)) * 64 + 64 - distance(pos.xz, vec2(chunkSize / 2)) > pos.y;
	return max(0.1, min(1, pow(voronoi(pos.xz / 32), 2))) * 128 > pos.y;
}

void main() {
	//mainFractal();
	//mainSphere();
	bool result = false;

	for(int i = 0; i <= 0; i++) {
		result = mainVoronoi(gl_GlobalInvocationID.xyz + (i%500) * 1707);
	}

	/*if(!result)
		result = true;*/

	setBlock(result);
}