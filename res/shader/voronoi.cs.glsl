#version 430
#include "inc/common.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

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

void main() {
	float val = voronoi(vec2(gl_GlobalInvocationID.xz) / 32) - float(gl_GlobalInvocationID.y) / params.chunkSize;
	val = clamp(0.5 + val/2, 0, 1);
	
	//val = 1 - distance(vec3(gl_GlobalInvocationID), vec3(64,64,64)) / 64;

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(uint(round(val * 255)), 0, 0, 0));
}