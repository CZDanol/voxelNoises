module ac.common.math.matrix;

import ac.common.math.vector;
import std.math;

struct Matrix {

public:
	alias T = float;

	// dfmt off
	enum : ubyte {
		xx, yx, zx, wx,
		xy, yy, zy, wy,
		xz, yz, zz, wz,
		xw, yw, zw, ww
	}
	// dfmt on

public:
	T[16] m = [ //
	1, 0, 0, 0, //
		0, 1, 0, 0, //
		0, 0, 1, 0, //
		0, 0, 0, 1 //
		];

public:
	this(T[16] m...) {
		this.m = m;
	}

	static Matrix identity() {
		return Matrix();
	}

	static Matrix translation(T x, T y, T z = 0) {
		return Matrix( //
				1, 0, 0, 0, //
				0, 1, 0, 0, //
				0, 0, 1, 0, //
				x, y, z, 1 //
				);
	}

	static Matrix translation(Vector!(T, 2) vec) {
		return Matrix( //
				1, 0, 0, 0, //
				0, 1, 0, 0, //
				0, 0, 1, 0, //
				vec.x, vec.y, 0, 1 //
				);
	}

	static Matrix translation(Vector!(T, 3) vec) {
		return Matrix( //
				1, 0, 0, 0, //
				0, 1, 0, 0, //
				0, 0, 1, 0, //
				vec.x, vec.y, vec.z, 1 //
				);
	}

	static Matrix rotationZ(float angle) {
		float asin = sin(angle), acos = cos(angle);
		return Matrix( //
				acos, asin, 0, 0, //
				-asin, acos, 0, 0, //
				0, 0, 1, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationY(float angle) {
		float asin = sin(angle), acos = cos(angle);
		return Matrix( //
				acos, 0, asin, 0, //
				0, 1, 0, 0, //
				-asin, 0, acos, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationX(float angle) {
		float asin = sin(angle), acos = cos(angle);
		return Matrix( //
				1, 0, 0, 0, //
				0, acos, asin, 0, //
				0, -asin, acos, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix scaling(T u) {
		return Matrix( //
				u, 0, 0, 0, //
				0, u, 0, 0, //
				0, 0, u, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix scaling(T x, T y, T z = 1) {
		return Matrix( //
				x, 0, 0, 0, //
				0, y, 0, 0, //
				0, 0, z, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix orthogonal(Vec2F screenSize, float near = 1, float far = 10_000) {
		return Matrix( //
				2f / screenSize.x, 0, 0, 0, //
				0, -2f / screenSize.y, 0, 0, //
				0, 0, 2.0f / (far - near), 0, //
				-1, 1, -(far + near) / (far - near), 1 //
				);
	}

	static Matrix perspective(Vec2F screenSize, float fovy = 0.3 * PI, float near = 1, float far = 10_000) {
		const float aspect = screenSize.x / screenSize.y;
		const float f = 1 / tan(fovy / 2);

		return Matrix( //
				f / aspect, 0, 0, 0, //
				0, f, 0, 0, //
				0, 0, (far + near) / (near - far), -1, //
				0, 0, 2 * far * near / (near - far), 1 //
				);
	}

public:
	Vec2F transformed(Vec2F v) {
		return Vec2F( //
				v.x * m[xx] + v.y * m[xy] + m[xw], //
				v.x * m[yx] + v.y * m[yy] + m[yw] //
		);
	}

	Vec3F transformed(Vec3F v) {
		return Vec3F( //
				v.x * m[xx] + v.y * m[xy] + v.z * m[xz] + m[xw], //
				v.x * m[yx] + v.y * m[yy] + v.z * m[yz] + m[yw], //
				v.x * m[zx] + v.y * m[zy] + v.z * m[zz] + m[zw] //
		);
	}

	Matrix transformed(Matrix mat) {
		Matrix result = void;
		T tmp;
		static foreach (x; 0 .. 4) {
			static foreach (y; 0 .. 4) {
				tmp = 0;
				static foreach (i; 0 .. 4)
					tmp += m[i * 4 + y] * mat.m[x * 4 + i];
				result.m[x * 4 + y] = tmp;
			}
		}
		return result;
	}

	Matrix transformed(T[16] mat...) {
		return Matrix(mat).transformed(this);
	}

public:
	Matrix inverted() {
		/* stolen from MESA */
		Matrix inv;
		float det;
		inv.m[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10];
		inv.m[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10];
		inv.m[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9];
		inv.m[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9];
		inv.m[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10];
		inv.m[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10];
		inv.m[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9];
		inv.m[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9];
		inv.m[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6];
		inv.m[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6];
		inv.m[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5];
		inv.m[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5];
		inv.m[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6];
		inv.m[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6];
		inv.m[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5];
		inv.m[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5];
		det = m[0] * inv.m[0] + m[1] * inv.m[4] + m[2] * inv.m[8] + m[3] * inv.m[12];
		if (det == 0)
			return Matrix();
		det = 1.0 / det;
		foreach (i; 0 .. 16)
			inv.m[i] = inv.m[i] * det;
		return inv;
	}

public:
	Matrix opBinary(string s : "*")(Matrix mat) {
		return this.transformed(mat);
	}

	void opOpAssign(string s : "*")(Matrix mat) {
		this = this * mat;
	}

}
