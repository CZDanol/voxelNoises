#define MAX_OCTAVE_COUNT 8

layout(std140) uniform Parameters {
	float octaveWeight[MAX_OCTAVE_COUNT];
	int chunkSize, octaveSize, executionCount;
	float time;
} params;

layout(r8ui, binding = 0) uniform uimage3D world;

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

	vec3 result = vec3(1 - float((t << 1) & 2), 1 - float(t & 2), 1 - float((t >> 1) & 2));
	result[(t >> 3) % 3] = 0; // One dimension is always 0
	return result;

	//return gradients[t % gradientCount];
}

vec2 nodeGradient(ivec2 pos) {
	uint t = hash(uint(pos.x));
	t = hash(t ^ uint(pos.y));

	float x = float(t & 65535) / 65535 * 2 * 3.141592;
	return vec2(sin(x), -cos(x));
}

vec3 nodeGradient(ivec3 pos) {
	uint t = hash(uint(pos.x));
	t = hash(t ^ uint(pos.y));
	t = hash(t ^ uint(pos.z));

	vec3 result = vec3(
		1 - float((t << 1) & 2),
		1 - float(t & 2),
		1 - float((t >> 1) & 2)
		);
		
	result[(t >> 3) % 3] = 0; // One dimension is always 0
	return result;

	//return gradients[t % gradientCount];
}

vec4 nodeGradient(ivec4 pos) {
	uint t = hash(uint(pos.x));
	t = hash(t ^ uint(pos.y));
	t = hash(t ^ uint(pos.z));
	t = hash(t ^ uint(pos.w));

	vec4 result = vec4(1 - float((t << 1) & 2), 1 - float(t & 2), 1 - float((t >> 1) & 2), 1 - float((t >> 2) & 2));
	result[(t >> 4) & 3] = 0; // One dimension is always 0
	return result;

	//return gradients[t % gradientCount];
}