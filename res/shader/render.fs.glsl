#version 430

in vec3 color_;

out vec4 color;

void main() {
	color = vec4(color_.rgb, 1);
}