module ac.client.gl.glprogram;

import ac.client.gl.glresourcemanager;
import ac.client.gl.glbuffer;
import ac.client.gl.glstate;
import ac.common.math.matrix;
import ac.common.math.vector;
import bindbc.opengl;
import std.array;
import std.format;
import std.path;
import std.file;
import std.regex;
import std.string;
import std.exception;
import std.stdio;
import std.format;
import std.conv;

final class GLProgram {

public:
	this(string name = "(unnamed)") {
		name_ = name;
		programId_ = glResourceManager.create(GLResourceType.program);
	}

	/// Create a program and add shaders from files "$fileBaseName.$shSuffix.glsl", link the program
	// (for each item in shaders $shSuffix = [fragment => fs, geometry => gs, vertex => vs, compute => cs])
	this(string fileBaseName, GLProgramShader[] shaders...) {
		this(fileBaseName);

		foreach (sh; shaders)
			addShaderFromFile(sh, fileBaseName ~ glProgramShader_fileBaseNameSuffix[sh] ~ ".glsl");

		link();
	}

	/// Create a program and add shaders from files "$fileBaseName.$shSuffix.glsl", link the program
	// (for each item in shaders $shSuffix = [fragment => fs, geometry => gs, vertex => vs, compute => cs])
	this(string fileBaseName, GLProgramShader[] shaders, string[string] defines = null) {
		this(fileBaseName);

		foreach (string key, string val; defines)
			define(key, val);

		foreach (sh; shaders)
			addShaderFromFile(sh, fileBaseName ~ glProgramShader_fileBaseNameSuffix[sh] ~ ".glsl");

		link();
	}

public:
	/// OpenGL id of the program
	GLuint programId() {
		return programId_;
	}

public:
	void bind() {
		if (recompileRequired_)
			recompile();

		glState.activeProgram = programId_;
	}

	static void unbind() {
		glState.activeProgram = 0;
	}

	/// Destroys the underlying OpenGL program & releases resources
	void release() {
		glResourceManager.release(GLResourceType.program, programId_);
		glResourceManager.release(shaders_.values);
	}

public:
	void addShaderFromString(GLProgramShader shaderType, string baseCode) {
		GLResourceRecord resource = shaders_.require(shaderType, glResourceManager.createRecord(glProgramShader_glResourceType[shaderType]));
		GLuint shaderId = resource.id;

		string code = baseCode;

		string defines;
		foreach (string name, string value; defines_)
			defines ~= "#define %s %s\n".format(name, value);

		if (defines)
			code = code.replaceAll(ctRegex!"^(\\s*(?:#version[^\n]*\n))?", "$1\n" ~ defines);

		int lineNumberCorrection;

		string replaceFunction(Captures!string m) {
			const string filePath = m[1];

			const string absoluteFilePath = absolutePath(filePath, "../res/shader".absolutePath);
			enforce(absoluteFilePath.exists, "Shader file '%s' does not exist.".format(absoluteFilePath));

			const string code = includes_.require(absoluteFilePath, {
				string result = readText(absoluteFilePath);

				/*
					Does not work because of #defines and such which you cannot put more on the same line

				// Remove line comments (so that removing newlines doesn¨t screw things up)
				result = result.replaceAll(ctRegex!"//.*", "");

				// Remove newlines (so original file numbering is preserved)
				result = result.replace("\n", " ");

				*/

				lineNumberCorrection += result.count('\n') + 1;

				return result;
			}());
			return code;
		}

		code = code.replaceAll!(replaceFunction)(ctRegex!"#include \"([^\"]+)\"");

		const(char)* ptr = code.ptr;
		GLint len = cast(GLint) code.length;
		glShaderSource(shaderId, 1, &ptr, &len);
		glCompileShader(shaderId);

		GLint compileStatus = 0;
		glGetShaderiv(shaderId, GL_COMPILE_STATUS, &compileStatus);

		if (compileStatus == GL_FALSE) {
			GLint errorLength = 0;
			glGetShaderiv(shaderId, GL_INFO_LOG_LENGTH, &errorLength);

			char[] errorChars;
			errorChars.length = errorLength;
			glGetShaderInfoLog(shaderId, errorLength, &errorLength, errorChars.ptr);

			string errorStr = errorChars.to!string;

			// Correct lines misaligned by includes
			auto replFunc = (Captures!string m) { //
				return "0(%s) :".format(m[1].to!int - lineNumberCorrection);
			};
			errorStr = errorStr.replaceAll!(replFunc)(ctRegex!"\\b0\\(([0-9]+)\\) :");

			throw new Exception("Error compiling shader '%s': %s".format(name_, errorStr));
		}

		shaderCodes_[shaderType] = baseCode;
		glAttachShader(programId_, shaderId);
	}

	void addShaderFromFile(GLProgramShader shaderType, string filePath) {
		const string absoluteFilePath = absolutePath(filePath, "../res/shader".absolutePath);
		enforce(absoluteFilePath.exists, "Shader file '%s' does not exist.".format(absoluteFilePath));

		const string code = readText(absoluteFilePath);
		addShaderFromString(shaderType, code);
	}

	void link() {
		glLinkProgram(programId_);

		GLint linkStatus;
		glGetProgramiv(programId_, GL_LINK_STATUS, &linkStatus);
		if (linkStatus == GL_FALSE) {
			GLint errorLength = 0;
			glGetProgramiv(programId_, GL_INFO_LOG_LENGTH, &errorLength);

			char[] errorStr;
			errorStr.length = errorLength;
			glGetProgramInfoLog(programId_, errorLength, &errorLength, errorStr.ptr);

			throw new Exception("Error linking program: %s".format(errorStr));
		}

		attributeLocations_ = null;
		uniformLocations_ = null;
		uniformBlockLocations_ = null;
	}

	void recompile() {
		foreach (GLProgramShader shaderType, string code; shaderCodes_)
			addShaderFromString(shaderType, code);

		link();
		recompileRequired_ = false;
	}

public:
	/// Adds define to the shader
	/// The shader is automatically recompiled on first use
	void define(string name, string value) {
		if (name in defines_ && defines_[name] == value)
			return;

		defines_[name] = value;
		recompileRequired_ = true;
	}

	void define(string name, int value) {
		define(name, value.to!string);
	}

	void resetDefines() {
		defines_ = null;
		recompileRequired_ = true;
	}

public:
	void setUniform(string uniform, const ref Matrix matrix) {
		const auto loc = uniformLocation(uniform);
		if (loc == -1)
			return;

		glUniformMatrix4fv(loc, 1, GL_FALSE, matrix.m.ptr);
	}

	void setUniform(string uniform, GLint val) {
		const auto loc = uniformLocation(uniform);
		if (loc == -1)
			return;

		glUniform1i(loc, val);
	}

	void setUniform(string uniform, GLfloat val) {
		const auto loc = uniformLocation(uniform);
		if (loc == -1)
			return;

		glUniform1f(loc, val);
	}

	void setUniform(string uniform, Vec4F val) {
		const auto loc = uniformLocation(uniform);
		if (loc == -1)
			return;

		glUniform4f(loc, val[0], val[1], val[2], val[3]);
	}

	GLint attributeLocation(string name) {
		GLint result = attributeLocations_.require(name, glGetAttribLocation(programId_, name.toStringz));
		if (result == -1)
			writeln("Attribute '%s' doesn't exist in the shader '%s'".format(name, name_));

		return result;
	}

	GLint uniformLocation(string name) {
		GLint result = uniformLocations_.require(name, glGetUniformLocation(programId_, name.toStringz));
		if (result == -1)
			writeln("Uniform '%s' doesn't exist in the shader '%s'".format(name, name_));

		return result;
	}

	GLint uniformBlockLocation(string name) {
		GLint result = uniformBlockLocations_.require(name, glGetUniformBlockIndex(programId_, name.toStringz));
		if (result == -1)
			writeln("Uniform block '%s' doesn't exist in the shader '%s'".format(name, name_));

		return result;
	}

private:
	string name_;
	GLuint programId_;
	GLResourceRecord[GLProgramShader] shaders_;
	string[GLProgramShader] shaderCodes_;
	string[string] defines_;
	string[string] includes_; ///< Cached include files
	GLint[string] attributeLocations_, uniformLocations_, uniformBlockLocations_;
	bool recompileRequired_;

}

enum GLProgramShader {
	geometry,
	vertex,
	fragment,
	compute
}

immutable GLResourceType[GLProgramShader] glProgramShader_glResourceType;
immutable string[GLProgramShader] glProgramShader_fileBaseNameSuffix;

shared static this() {
	glProgramShader_glResourceType = [ //
	GLProgramShader.geometry : GLResourceType.geometryShader, //
		GLProgramShader.vertex : GLResourceType.vertexShader, //
		GLProgramShader.fragment : GLResourceType.fragmentShader, //
		GLProgramShader.compute : GLResourceType.computeShader, //
		];

	glProgramShader_fileBaseNameSuffix = [ //
	GLProgramShader.geometry : ".gs", //
		GLProgramShader.vertex : ".vs", //
		GLProgramShader.fragment : ".fs", //
		GLProgramShader.compute : ".cs" //
		];
}
