#version 430

in vec3 coord_;

out vec4 color;

int hash(int x) {
	x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = (x >> 16) ^ x;
  return x;
}

const float gridSize = 4;

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

vec3 nodeGradient(vec3 pos) {
	int t = hash(int(pos.x));
	t ^= hash(int(pos.y));

	return gradients[t % gradientCount];
}

// Interpolation function 6*t^5 - 15 * t^4 + 10 * t^3
float interpolate(float v1, float v2, float progress) {
	const float prog2 = progress * progress;
	const float prog4 = prog2 * prog2;

	const float val = 6 * progress * prog4 - 15 * prog4 + 10 * prog2 * progress;
	return v2 * val + v1 * (1-val);
	//return progress > 0.5 ? v2 : v1;
}

float perlin(vec3 normalizedCoord) {
	const vec3 anchorNodePos = floor(normalizedCoord);
	const vec3 offset = normalizedCoord - anchorNodePos;

	const float gradient1 = dot(offset, nodeGradient(anchorNodePos));
	const float gradient2 = dot(vec3(offset.x - 1, offset.y, offset.z), nodeGradient(anchorNodePos + vec3(1,0,0)));
	const float interpolation1 = interpolate(gradient1, gradient2, offset.x);

	const float gradient3 = dot(vec3(offset.x, offset.y - 1, offset.z), nodeGradient(anchorNodePos + vec3(0,1,0)));
	const float gradient4 = dot(vec3(offset.x - 1, offset.y - 1, offset.z), nodeGradient(anchorNodePos + vec3(1,1,0)));
	const float interpolation2 = interpolate(gradient3, gradient4, offset.x);

	return interpolate(interpolation1, interpolation2, offset.y);
}

void main() {
	color = vec4(perlin(coord_) * 0.20 + perlin(coord_/4) * 0.80, 0, 0,1);
	//color = vec4(nodeGradient(anchorNodePos), 1);
}