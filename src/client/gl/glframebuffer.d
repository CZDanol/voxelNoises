module ac.client.gl.glframebuffer;

import ac.client.gl.glresourcemanager;
import ac.client.gl.gltexture;
import ac.common.math.vector;
import bindbc.opengl;

final class GLFramebuffer {

public:
	this() {
		fboId_ = glResourceManager.create(GLResourceType.framebuffer);
	}

	/// Destroys the underlying opengl texture
	void release() {
		glResourceManager.release(GLResourceType.framebuffer, fboId_);
	}

public:
	void bind(GLenum target = GL_FRAMEBUFFER) {
		glBindFramebuffer(target, fboId_);
	}

	static void unbind(GLenum boundTarget = GL_FRAMEBUFFER) {
		glBindFramebuffer(boundTarget, 0);
	}

public:
	/// Attaches the provided texture to the framebuffer
	/// If doBind is true, automatically binds & unbinds the framebuffer, otherwise you have to do it manually
	void attach(GLenum attachment, GLTexture texture, bool doBind = true, GLenum bindTarget = GL_FRAMEBUFFER, GLint mipmapLevel = 0) {
		if (doBind)
			bind(bindTarget);

		glFramebufferTexture2D(bindTarget, attachment, texture.textureType, texture.textureId, mipmapLevel);

		if (doBind)
			unbind(bindTarget);
	}

private:
	GLuint fboId_;

}
