module ac.client.gui.comboboxwidget;

import ac.client.gui.devtoolkit;
import std.algorithm;

final class ComboBoxWidget : Widget {

public:
	this(string[] items) {
		optimalSize_ = Vec2I(150, 20);
		items_ = items;

		text_ = new Text();
		text_.setFont(guiResources.defaultFont);
		text_.setCharacterSize(guiResources.fontSize);
		text_.setColor(guiResources.fontColor);

		rect_ = new RectangleShape(Vector2f(0, 0));
		rect_.outlineColor = guiResources.outlineColor;
		rect_.outlineThickness = guiResources.outlineThickness;

		triangle_ = new CircleShape(2, 3);
		triangle_.outlineColor = guiResources.outlineColor;
		triangle_.outlineThickness = guiResources.outlineThickness;
		triangle_.rotation = 180;
	}

public:
	int currentItem() {
		return currentItem_;
	}

	void currentItem(int set) {
		currentItem_ = min(items_.length - 1, max(0, set));
	}

public:
	override void draw(RenderTarget rt, RenderStates rs) {
		rect_.fillColor = hovered_ ? guiResources.hoveredFaceColor : guiResources.inactiveFaceColor;
		rect_.size = Vector2f(size_.x - guiResources.outlineThickness * 2, size_.y - guiResources.outlineThickness * 2);
		rect_.position = Vector2f(pos_.x + guiResources.outlineThickness, pos_.y + guiResources.outlineThickness);
		rect_.draw(rt, rs);

		triangle_.position = Vector2f(pos_.x + size_.x - guiResources.outlineThickness * 2 - 8, pos_.y + cast(int)(size_.y / 2.0f + triangle_.radius / sqrt(2.0f)));
		triangle_.draw(rt, rs);

		text_.setString(items_[currentItem_]);
		FloatRect b = text_.getLocalBounds();
		text_.position = rect_.position + rect_.size / 2 - Vector2f(b.left + b.width / 2, b.top + b.height / 2);
		text_.position = Vector2f(cast(int) text_.position.x, cast(int) text_.position.y);
		text_.draw(rt, rs);
	}

	bool overlayDraw(RenderTarget rt, RenderStates rs) {
		foreach (int i, string item; items_) {
			rect_.fillColor = i == currentItem_ ? guiResources.pressedFaceColor : guiResources.inactiveFaceColor;
			rect_.position = Vector2f(pos_.x + guiResources.outlineThickness, pos_.y + guiResources.outlineThickness + (i + 1) * size_.y);
			rect_.draw(rt, rs);

			text_.setString(items_[i]);
			FloatRect b = text_.getLocalBounds();
			text_.position = rect_.position + rect_.size / 2 - Vector2f(b.left + b.width / 2, b.top + b.height / 2);
			text_.position = Vector2f(cast(int) text_.position.x, cast(int) text_.position.y);
			text_.draw(rt, rs);
		}

		return pressed_;
	}

public:
	override bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		if (ev.button != MouseButton.left)
			return true;

		pressed_ = true;
		pressedItem_ = currentItem_;

		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (!mev.buttonPressed[Mouse.Button.Left]) {
				pressed_ = false;
				return false;
			}

			int oldCurrentItem = currentItem_;

			int newItem = min(items_.length - 1, max(-1, cast(int) floor(float(mev.pos.y - pos_.y - size_.y) / size_.y)));

			if (newItem >= 0)
				currentItem_ = newItem;

			if (oldCurrentItem != currentItem_ && onCurrentItemChangedByUser)
				onCurrentItemChangedByUser();

			return true;
		});
		application.addOverlayDraw(&overlayDraw);

		return true;
	}

	override void mouseMoveEvent(const ref MouseMoveEvent ev) {
		watchForHover(ev, hovered_);
	}

public:
	void delegate() onCurrentItemChangedByUser = null;

private:
	string[] items_;
	int currentItem_;

private:
	RectangleShape rect_;
	CircleShape triangle_;
	Text text_;
	string label_;
	bool hovered_, pressed_;

	int pressedItem_;

}
