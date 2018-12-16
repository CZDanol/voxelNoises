module ac.client.gl.gltexture;

import ac.client.gl.glresourcemanager;
import ac.client.gl.glstate;
import ac.common.math.vector;
import bindbc.opengl;

final class GLTexture {

public:
	this(GLenum type) {
		type_ = type;
		textureId_ = glResourceManager.create(GLResourceType.texture);
	}

	/// Destroys the underlying opengl texture
	void release() {
		glResourceManager.release(GLResourceType.texture, textureId_);
	}

public:
	void bind(int activeTexture = 0) {
		glState.activeTexture = activeTexture;
		glBindTexture(type_, textureId_);
	}

	void unbind(int activeTexture = 0) {
		//glState.activeTexture = activeTexture;
		glBindTexture(type_, 0);
	}

public:
	/// Returns OpenGL id of the texture
	GLuint textureId() const {
		return textureId_;
	}

	/// Returns OpenGL type of the texture (GL_TEXTURE_2D, GL_TEXTURE_3D, ...)
	GLenum textureType() const {
		return type_;
	}

private:
	GLuint textureId_;
	GLenum type_;

}
