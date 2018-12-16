#version 430
#include "inc/common.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#define VORONOI_MAX_POINTS_PER_REGION 4
#define VORONOI_POINTS_RESOLUTION 1024

struct VoronoiRegion {
	uint fill;
	uint pointCount;
	vec3 points[VORONOI_MAX_POINTS_PER_REGION];
};

// Returns voronoi points for the given region
VoronoiRegion voronoiRegion(ivec3 regionPos) {
	uint h = hash(regionPos.x);
	h = hash(h ^ regionPos.y);
	h = hash(h ^ regionPos.z);

	VoronoiRegion result;
	result.pointCount = 1 + h % (VORONOI_MAX_POINTS_PER_REGION - 1);

	h = hash(h);
	result.fill = (h & 254) + 1;

	uint h2 = h ^ 97;
	uint h3 = h ^ 127;

	for(uint i = 0; i < result.pointCount; i++) {
		h = hash(h);
		h2 = hash(h2);
		h3 = hash(h3);

		result.points[i].x = float(h % VORONOI_POINTS_RESOLUTION) / VORONOI_POINTS_RESOLUTION;
		result.points[i].y = float(h2 % VORONOI_POINTS_RESOLUTION) / VORONOI_POINTS_RESOLUTION;
		result.points[i].z = float(h3 % VORONOI_POINTS_RESOLUTION) / VORONOI_POINTS_RESOLUTION;
	}

	return result;
}

struct VoronoiResult {
	float dist;
	uint fill;
};

float dist(vec3 a, vec3 b) {
	vec3 diff = abs(a-b);
	const float e = 1 + params.time;
	return pow(pow(diff.x, e) + pow(diff.y, e) + pow(diff.z, e), 1/e);
}

VoronoiResult voronoiNearestPointDistance(ivec3 regionPos, vec3 pointPos) {
	VoronoiRegion region = voronoiRegion(regionPos);

	VoronoiResult result;
	result.dist = dist(pointPos, region.points[0]);
	result.fill = region.fill;

	for(uint i = 1; i < region.pointCount; i++)
		result.dist = min(result.dist, dist(pointPos, region.points[i]));

	return result;
}

uint voronoi(vec3 normalizedCoord) {
	const ivec3 regionPos = ivec3(floor(normalizedCoord));
	const vec3 localPos = fract(normalizedCoord);

	VoronoiResult result;
	result.dist = 1000;
	ivec3 relPos;
	for(relPos.x = -1; relPos.x <= 1; relPos.x++) {
		for(relPos.y = -1; relPos.y <= 1; relPos.y++) {
			for(relPos.z = -1; relPos.z <= 1; relPos.z++) {
				VoronoiResult tmp = voronoiNearestPointDistance(regionPos + relPos, localPos - relPos);
				if(tmp.dist < result.dist)
					result = tmp;
			}
		}
	}

	return result.fill;
}

uniform int octaveSize;

void main() {
	uint val = voronoi(vec3(gl_GlobalInvocationID) / params.octaveSize);
	
	//val = 1 - distance(vec3(gl_GlobalInvocationID), vec3(64,64,64)) / 64;

	imageStore(world, ivec3(gl_GlobalInvocationID.xyz), uvec4(val, 0, 0, 0));
}