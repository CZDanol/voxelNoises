module ac.client.gl.glbindingsvao;

import ac.client.gl.glresourcemanager;
import ac.client.gl.glprogram;
import ac.client.gl.glbuffer;
import ac.client.gl.glstate;
import ac.common.math.vector;
import bindbc.opengl;

final class GLBindingsVAO {

public:
	this() {
		vaoId_ = glResourceManager.create(GLResourceType.vao);
	}

public:
	pragma(inline) static GLBindingsVAO boundVao() {
		return boundVAO_;
	}

public:
	void bind() {
		boundVAO_ = this;
		glState.boundVAO = vaoId_;
	}

	static void unbind() {
		boundVAO_ = null;
		glState.boundVAO = 0;
	}

	/// Binds provided buffer to attribute attributeName (which is expected to be a vector of dimensions dimensions) of program program
	/// Assumes the current vao is bound
	/// Binds the buffer internally to GL_ARRAY_BUFFER (and then unbinds it)
	void bindBuffer(Buf : GLBuffer!Bx, Bx...)(GLProgram program, string attributeName, Buf buffer) {
		debug assert(boundVAO_ is this);

		buffer.bind(GL_ARRAY_BUFFER);

		GLint pos = program.attributeLocation(attributeName);
		glEnableVertexAttribArray(pos);
		glVertexAttribPointer(pos, buffer.D, buffer.GL_T, GL_FALSE, 0, null);

		buffer.unbind(GL_ARRAY_BUFFER);
	}

	/// Destroys the underlying opengl object
	void release() {
		glResourceManager.release(GLResourceType.vao, vaoId_);
	}

private:
	GLuint vaoId_;
	__gshared GLBindingsVAO boundVAO_;

}
