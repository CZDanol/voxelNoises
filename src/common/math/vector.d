module ac.common.math.vector;

import std.meta;
import std.functional;
import std.format;
import std.algorithm;
import std.conv;

alias Vec2F = Vector!(float, 2);
alias Vec3F = Vector!(float, 3);
alias Vec4F = Vector!(float, 4);

alias Vec2I = Vector!(int, 2);
alias Vec3I = Vector!(int, 3);
alias Vec4I = Vector!(int, 4);

struct Vector(T_, uint D_, string cookie = "") {

public:
	alias Vec = typeof(this);
	alias T = T_;
	enum D = D_;

	static if (__traits(compiles, T.min)) {
		enum max = Vec(T.max);
		enum min = Vec(T.min);
	}

public:
	this(Repeat!(D, T) vals) {
		static foreach (i; 0 .. D)
			val[i] = vals[i];
	}

	static if (D > 1) {
		this(T v) {
			val[] = v;
		}
	}

public:
	pragma(inline) ref T opIndex(uint i) {
		return val[i];
	}

	pragma(inline) T opIndex(uint i) const {
		return val[i];
	}

public:
	Vec opBinary(string op : "+")(Vec other) const {
		Vec result;
		static foreach (i; 0 .. D)
			result[i] = this[i] + other[i];

		return result;
	}

	Vec opBinary(string op : "-")(Vec other) const {
		Vec result;
		static foreach (i; 0 .. D)
			result[i] = this[i] - other[i];

		return result;
	}

	Vec opUnary(string op : "-")() const {
		Vec ret = this;
		foreach (i; 0 .. D)
			ret.val[i] *= -1;

		return ret;
	}

public:
	// vec + const
	Vec opBinary(string op : "+")(T v) const {
		Vec result;
		static foreach (i; 0 .. D)
			result[i] = this[i] + v;

		return result;
	}

	// vec - const
	Vec opBinary(string op : "-")(T v) const {
		Vec result;
		static foreach (i; 0 .. D)
			result[i] = this[i] - v;

		return result;
	}

	// vec * const
	Vec opBinary(string op : "*")(T v) const {
		Vec result;
		static foreach (i; 0 .. D)
			result[i] = this[i] * v;

		return result;
	}

	// vec / const
	Vec opBinary(string op : "/")(T v) const {
		Vec result;
		static foreach (i; 0 .. D)
			result[i] = this[i] / v;

		return result;
	}

	auto opCast(Vec2 : Vector!(T2, D, cookie2), T2, string cookie2)() const {
		Vec2 result;
		foreach (i; 0 .. D)
			result[i] = cast(T2) val[i];

		return result;
	}

	string toString() const {
		return "Vec%s!%s(%s)".format(D, T.stringof, val[].map!(x => x.to!string).joiner(", "));
	}

public:
	T[D] val = 0;

public:
	pragma(inline) ref T x() {
		return val[0];
	}

	pragma(inline) T x() const {
		return val[0];
	}

	static if (D > 1) {
		pragma(inline) ref T y() {
			return val[1];
		}

		pragma(inline) T y() const {
			return val[1];
		}
	}

	static if (D > 2) {
		pragma(inline) ref T z() {
			return val[2];
		}

		pragma(inline) T z() const {
			return val[2];
		}
	}

}

bool all(alias pred, Vec : Vector!(T, D, cookie), T, uint D, string cookie)(Vec v1, Vec v2) {
	static foreach (i; 0 .. D) {
		if (!binaryFun!(pred)(v1[i], v2[i]))
			return false;
	}

	return true;
}

bool any(alias pred, Vec : Vector!(T, D, cookie), T, uint D, string cookie)(Vec v1, Vec v2) {
	static foreach (i; 0 .. D) {
		if (binaryFun!(pred)(v1[i], v2[i]))
			return true;
	}

	return false;
}
