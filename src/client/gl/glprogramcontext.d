module ac.client.gl.glprogramcontext;

import ac.client.gl.glprogram;
import ac.client.gl.gltexture;
import ac.client.gl.glbuffer;
import ac.client.gl.glbindingsvao;
import ac.client.gl.glstate;
import ac.client.gl.glresourcemanager;
import ac.common.math.matrix;
import ac.common.math.vector;
import bindbc.opengl;

/// Program context - handles setting up everything: program, textures, buffers, uniforms, etc.
final class GLProgramContext {

public:
	this(GLProgram program = null) {
		bindingsVAO_ = new GLBindingsVAO();
		program_ = program;
	}

public:
	/// Binds the program and all the connected resources
	/// Functions like setUniform/bindXX/setProgram won't have any effect until bound again
	void bind() {
		program_.bind();
		bindingsVAO_.bind();

		foreach (setter; uniformSetters_.byValue)
			setter();

		foreach (pair; enables_.byKeyValue)
			glState.setEnabled(pair.key, pair.value);

		// If VAO bindings have changed
		if (bufferBindings_.length) {
			foreach (binding; bufferBindings_)
				binding();

			bufferBindings_.length = 0;
		}
	}

	/// Release all GL resources allocated by the context
	void release() {
		bindingsVAO_.release();

		foreach (ref UniformBlock block; uniformBlocks_.byValue)
			glResourceManager.release(GLResourceType.buffer, block.bufferId);
	}

public:
	void setProgram(GLProgram program) {
		program_ = program;
	}

	void bindBuffer(Buf : GLBuffer!Bx, Bx...)(string attributeName, Buf buffer) {
		bufferBindings_ ~= { //
			buffer.bind();
			GLint pos = program_.attributeLocation(attributeName);
			if (pos != -1) {
				glEnableVertexAttribArray(pos);
				glVertexAttribPointer(pos, buffer.D, buffer.GL_T, GL_FALSE, 0, null);
			}
		};
	}

	void bindTexture(string uniformName, GLTexture texture) {
		GLint id = usedTextureUnitCount_++;

		uniformSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName);
			if (pos != -1) {
				texture.bind(id);
				glUniform1i(pos, id);
			}
		};
	}

public:
	void enable(GLenum what) {
		enables_[what] = true;
	}

	void disable(GLenum what) {
		enables_[what] = false;
	}

public:
	void setUniformBlock(T)(string uniformBlockName, const ref T value) {
		UniformBlock block = uniformBlocks_.require(uniformBlockName, { //
			UniformBlock result;
			result.bufferId = glResourceManager.create(GLResourceType.buffer);
			result.bindingPoint = uniformBlockBindingCounter_++;

			uniformSetters_[uniformBlockName] = { //
				glUniformBlockBinding(program_.programId, program_.uniformBlockLocation(uniformBlockName), result.bindingPoint);
				glBindBufferBase(GL_UNIFORM_BUFFER, result.bindingPoint, result.bufferId);
			};

			return result;
		}());

		glState.bindBuffer(GL_UNIFORM_BUFFER, block.bufferId);
		glBufferData(GL_UNIFORM_BUFFER, T.sizeof, &value, GL_DYNAMIC_DRAW);
	}

	void setUniform(string uniformName, GLint value) {
		uniformSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName);
			if (pos != -1)
				glUniform1i(pos, value);
		};
	}

	void setUniform(string uniformName, GLfloat value) {
		uniformSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName);
			if (pos != -1)
				glUniform1f(pos, value);
		};
	}

	void setUniform(string uniformName, Vec3F value) {
		uniformSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName);
			if (pos != -1)
				glUniform3f(pos, value.x, value.y, value.z);
		};
	}

	void setUniform(string uniformName, const ref Matrix matrix) {
		uniformSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName);
			if (pos != -1)
				glUniformMatrix4fv(pos, 1, GL_FALSE, matrix.m.ptr);
		};
	}

private:
	struct UniformBlock {
		GLint bufferId;
		GLint bindingPoint;
	}

private:
	GLProgram program_;
	GLBindingsVAO bindingsVAO_;
	GLint usedTextureUnitCount_, uniformBlockBindingCounter_;
	bool[GLenum] enables_;
	UniformBlock[string] uniformBlocks_;

	/// Buffer bindings to the VAO (executing it when VAO is bound updates the VAO)
	void delegate()[] bufferBindings_;
	void delegate()[string] uniformSetters_;

}
