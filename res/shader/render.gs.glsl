#version 430

layout(points) in;
layout(triangle_strip, max_vertices=36) out;

uniform mat4 matrix;
uniform int chunkSize;
uniform int threshold;
uniform usampler3D world;
uniform vec3 lightDirection;
uniform float ambientLight;
uniform int coloring;

out vec3 color_;

void emitQuad(vec3 lt, vec3 rt, vec3 lb, vec3 rb, vec3 color, vec3 normal) {
	color = color * clamp(clamp(dot(normal, lightDirection), 0, 1) + ambientLight, 0, 1);

	color_ = color;
	gl_Position = matrix * (gl_in[0].gl_Position + vec4(lb,0));
	EmitVertex();

	color_ = color;
	gl_Position = matrix * (gl_in[0].gl_Position + vec4(rb,0));
	EmitVertex();

	color_ = color;
	gl_Position = matrix * (gl_in[0].gl_Position + vec4(lt,0));
	EmitVertex();

	color_ = color;
	gl_Position = matrix * (gl_in[0].gl_Position + vec4(rt,0));
	EmitVertex();
	EndPrimitive();
}

bool isVoxelAt(float relX, float relY, float relZ) {
	return texture(world, (gl_in[0].gl_Position.xyz + vec3(relX, relY, relZ)) / float(chunkSize)).r > threshold;
}

void main() {
	float thisVoxelValue = texture(world, gl_in[0].gl_Position.xyz / float(chunkSize)).r;

	if(thisVoxelValue <= threshold)
		return;

	const bool voxelAtFront = isVoxelAt(0,0,-1);
	const bool voxelAtBack = isVoxelAt(0,0,1);
	const bool voxelAtLeft = isVoxelAt(-1,0,0);
	const bool voxelAtRight =isVoxelAt(1,0,0);
	const bool voxelAtTop = isVoxelAt(0,-1,0);
	const bool voxelAtBottom = isVoxelAt(0,1,0);

	vec3 color;
	if(coloring == 0) {
		if(!voxelAtTop)
			color = vec3(0.4,0.4,0.4); // Nothing below : rock (gray)
		else if(voxelAtBottom)
			color = vec3(0.42,0.18,0.03); // Something on top : dirt (brown)
		else
			color =  vec3(0.28, 0.58, 0.04); // Otherwise : grass (green)
	}
	else if(coloring == 1) {
		color = vec3(0.9, 0.9, 0.9);
	} else {
		if(threshold == 255)
			color = vec3(1);
		else
			color = vec3(float(thisVoxelValue)/255);
	}
	

	// Front face
	if(!voxelAtFront)
		emitQuad(vec3(0,0,0), vec3(1,0,0), vec3(0,1,0), vec3(1,1,0), color, vec3(0, 0, -1));

	// Back face
	if(!voxelAtBack)
		emitQuad(vec3(1,0,1), vec3(0,0,1), vec3(1,1,1), vec3(0,1,1), color, vec3(0, 0, 1));

	// Left face
	if(!voxelAtLeft)
		emitQuad(vec3(0,0,1), vec3(0,0,0), vec3(0,1,1), vec3(0,1,0), color, vec3(-1, 0, 0));

	// Right face
	if(!voxelAtRight)
		emitQuad(vec3(1,0,0), vec3(1,0,1), vec3(1,1,0), vec3(1,1,1), color, vec3(1,0,0));

	// Top face
	if(!voxelAtTop)
		emitQuad(vec3(0,0,1), vec3(1,0,1), vec3(0,0,0), vec3(1,0,0), color, vec3(0,-1,0));

	// Bottom face
	if(!voxelAtBottom)
		emitQuad(vec3(0,1,0), vec3(1,1,0), vec3(0,1,1), vec3(1,1,1), color, vec3(0,1,0));
}