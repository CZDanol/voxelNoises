module ac.client.gui.sliderwidget;

import ac.client.gui.devtoolkit;
import std.algorithm;

final class SliderWidget : Widget {

public:
	alias Orientation = HVOrientation;

public:
	this(Orientation orientation) {
		orientation_ = orientation;
		optimalSize_ = Vec2I(20, 20);
		optimalSize_[uint(orientation)] = 150;

		rect_ = new RectangleShape(Vector2f(0, 0));
		rect_.outlineColor = guiResources.outlineColor;
		rect_.outlineThickness = guiResources.outlineThickness;

		lineRect_ = new RectangleShape(Vector2f(0, 0));
		lineRect_.outlineColor = guiResources.outlineColor;
		lineRect_.outlineThickness = guiResources.outlineThickness;
	}

public:
	float value() {
		return value_;
	}

	void value(float set) {
		if (value_ == set)
			return;

		value_ = clamp(set, minValue_, maxValue_);

		if (onValueChanged)
			onValueChanged();
	}

	float minValue() {
		return minValue_;
	}

	void minValue(float set) {
		minValue_ = set;
	}

	float maxValue() {
		return maxValue_;
	}

	void maxValue(float set) {
		maxValue_ = set;
	}

public:
	override void draw(RenderTarget rt, RenderStates rs) {
		const float normalizedValue = (value_ - minValue_) / (maxValue_ - minValue_);
		const int sliderSize = guiResources.sliderSize;
		const int outlineThickness = guiResources.outlineThickness;

		if (orientation_ == Orientation.horizontal) {
			rect_.size = Vector2f(sliderSize, size_.y - outlineThickness * 2);
			rect_.position = Vector2f(pos_.x + outlineThickness + cast(int)(normalizedValue * (size_.x - outlineThickness * 2 - sliderSize)), pos_.y + outlineThickness);

			lineRect_.size = Vector2f(size_.x - outlineThickness * 2 - sliderSize, 2);
			lineRect_.position = Vector2f(pos_.x + outlineThickness + sliderSize / 2, pos_.y + (size_.y - lineRect_.size.y) / 2);
		}
		else {
			rect_.size = Vector2f(size_.x - outlineThickness * 2, sliderSize);
			rect_.position = Vector2f(pos_.x + outlineThickness, pos_.y + outlineThickness + cast(int)(normalizedValue * (size_.y - outlineThickness * 2 - sliderSize)));

			lineRect_.size = Vector2f(2, size_.y - outlineThickness * 2 - sliderSize);
			lineRect_.position = Vector2f(pos_.x + (size_.x - lineRect_.size.x) / 2, pos_.y + outlineThickness + sliderSize / 2);
		}

		//rect_.size = Vector2f(size_.x - guiResources.outlineThickness * 2, size_.y - guiResources.outlineThickness * 2);
		//rect_.position = Vector2f(pos_.x + outlineThickness, pos_.y + guiResources.outlineThickness);

		lineRect_.draw(rt, rs);

		rect_.fillColor = pressed_ ? guiResources.pressedFaceColor : hovered_ ? guiResources.hoveredFaceColor : guiResources.inactiveFaceColor;
		rect_.draw(rt, rs);
	}

public:
	override bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		if (ev.button != MouseButton.left)
			return true;

		if (ev.pos.x < rect_.position.x || ev.pos.y < rect_.position.y || ev.pos.x > rect_.position.x + rect_.size.x || ev.pos.y > rect_.position.y + rect_.size.y)
			return true;

		const int sliderSize = guiResources.sliderSize;
		const int outlineThickness = guiResources.outlineThickness;

		pressed_ = true;
		pressOffset_ = orientation_ == Orientation.horizontal ? ev.pos.x - rect_.position.x : ev.pos.y - rect_.position.y;
		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (!mev.buttonPressed[Mouse.Button.Left]) {
				pressed_ = false;
				return false;
			}

			const float normalizedValue = orientation_ == Orientation.horizontal //
			 ? float((mev.pos.x - pressOffset_) - (pos_.x + outlineThickness)) / (size_.x - outlineThickness * 2 - sliderSize) //
			 : float((mev.pos.y - pressOffset_) - (pos_.y + outlineThickness)) / (size_.y - outlineThickness * 2 - sliderSize);

			value_ = minValue_ + clamp(normalizedValue, 0.0f, 1.0f) * (maxValue_ - minValue_);

			if (onValueChanged)
				onValueChanged();

			if (onValueChangedByUser)
				onValueChangedByUser();

			return true;
		});

		return true;
	}

	override void mouseMoveEvent(const ref MouseMoveEvent ev) {
		if (hovered_ || ev.pos.x < rect_.position.x || ev.pos.y < rect_.position.y || ev.pos.x > rect_.position.x + rect_.size.x || ev.pos.y > rect_.position.y + rect_.size.y)
			return;

		hovered_ = true;
		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (mev.pos.any!((a, b) => a < b)(pos_) || mev.pos.any!((a, b) => a >= b)(pos_ + size_)) {
				hovered_ = false;
				return false;
			}

			return true;
		});
	}

public:
	void delegate() onValueChangedByUser = null;
	void delegate() onValueChanged = null;

private:
	Orientation orientation_;

private:
	float value_ = 0, minValue_ = 0, maxValue_ = 1;

private:
	RectangleShape rect_, lineRect_;
	bool hovered_, pressed_;
	float pressOffset_;

}
