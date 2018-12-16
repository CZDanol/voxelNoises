#version 430

uniform mat4 matrix;

in vec3 vertexPos;
in vec3 coord;

out vec3 coord_;

void main() {
	gl_Position = matrix * vec4(vertexPos, 1);
	coord_ = coord;
}