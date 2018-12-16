module ac.client.gl.glbuffer;

import ac.client.gl.glresourcemanager;
import ac.client.gl.gltypes;
import ac.client.gl.glstate;
import ac.common.math.vector;
import bindbc.opengl;
import std.array;
import std.meta;

final class GLBuffer(Vec_ : Vector!(T_, D_, C_), T_, uint D_, string C_) {

public:
	alias Vec = Vec_;
	alias T = T_;
	alias D = D_;
	alias GL_T = GLType!T;

public:
	this() {
		bufferId_ = glResourceManager.create(GLResourceType.buffer);
		appender_ = appender(&data_);
	}

public:
	void bind(GLenum target = GL_ARRAY_BUFFER) {
		glState.bindBuffer(target, bufferId_);
	}

	static void unbind(GLenum boundTarget = GL_ARRAY_BUFFER) {
		glState.bindBuffer(boundTarget, 0);
	}

	/// Destroys the underlying OpenGL buffer
	void release() {
		glResourceManager.release(GLResourceType.buffer, bufferId_);
	}

public:
	void clear() {
		data_.length = 0;
	}

	/// Clears the local (CPU) buffer and the memory for the buffer
	void clearMore() {
		data_ = null;
	}

	/// Returns length of the uploaded buffer (number of vectors * vector dimension)
	/// Does not show length of the current buffer
	size_t length() {
		return uploadedLength_;
	}

	/// Returns point count of the uploaded buffer (number of vectors)
	size_t pointCount() {
		return uploadedLength_ / D;
	}

	/// Uploads the locally bulit data to the buffer, the data is uploaded using glBufferData
	/// If doBind is true, the buffer is bound to boundTarget and then unbound after upload (otherwise you have to bind it yourself)
	/// The local data is not cleared, you have to clear it manually using GLBuffer.clear
	void upload(GLenum usage, GLenum boundTarget = GL_ARRAY_BUFFER, bool doBind = true) {
		if (doBind)
			bind(boundTarget);

		glBufferData(boundTarget, T.sizeof * data_.length, data_.ptr, usage);
		uploadedLength_ = data_.length;

		if (doBind)
			unbind(boundTarget);
	}

public:
	void opOpAssign(string op : "~")(T_ val) {
		appender_ ~= val;
	}

	void opOpAssign(string op : "~")(Vec vec) {
		static foreach (i; 0 .. D)
			appender_ ~= vec[i];
	}

	void add(Repeat!(D, T) vals) {
		static foreach (i; 0 .. D)
			appender_ ~= vals[i];
	}

	/// Adds quad represented as two triangles
	void addTrianglesQuad(Vec lt, Vec rt, Vec lb, Vec rb) {
		this ~= lt;
		this ~= lb;
		this ~= rb;

		this ~= lt;
		this ~= rb;
		this ~= rt;
	}

private:
	GLint bufferId_;
	size_t uploadedLength_;
	T_[] data_;
	RefAppender!(T_[]) appender_;

}