module ac.client.gui.buttonwidget;

import ac.client.gui.devtoolkit;

final class ButtonWidget : Widget {

public:
	this(string label = "") {
		optimalSize_ = Vec2I(150, 20);
		text_ = label;

		dtext_ = new Text();
		dtext_.setFont(guiResources.defaultFont);
		dtext_.setCharacterSize(guiResources.fontSize);
		dtext_.setColor(guiResources.fontColor);
		dtext_.setString(text_);

		rect_ = new RectangleShape(Vector2f(0, 0));
		rect_.outlineColor = guiResources.outlineColor;
		rect_.outlineThickness = guiResources.outlineThickness;
	}

public:
	override void draw(RenderTarget rt, RenderStates rs) {
		rect_.fillColor = pressed_ ? guiResources.pressedFaceColor : hovered_ ? guiResources.hoveredFaceColor : guiResources.inactiveFaceColor;
		rect_.size = Vector2f(size_.x - guiResources.outlineThickness * 2, size_.y - guiResources.outlineThickness * 2);
		rect_.position = Vector2f(pos_.x + guiResources.outlineThickness, pos_.y + guiResources.outlineThickness);
		rect_.draw(rt, rs);

		FloatRect b = dtext_.getLocalBounds();
		dtext_.position = rect_.position + rect_.size / 2 - Vector2f(b.left + b.width / 2, b.top + b.height / 2);
		dtext_.position = Vector2f(cast(int) dtext_.position.x, cast(int) dtext_.position.y);
		dtext_.draw(rt, rs);
	}

public:
	override bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		if (ev.button != MouseButton.left)
			return true;

		if (onClick)
			onClick();

		pressed_ = true;
		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (!mev.buttonPressed[Mouse.Button.Left]) {
				pressed_ = false;
				return false;
			}

			return true;
		});

		return true;
	}

	override void mouseMoveEvent(const ref MouseMoveEvent ev) {
		watchForHover(ev, hovered_);
	}

public:
	void delegate() onClick;

private:
	RectangleShape rect_;
	Text dtext_;
	string text_;
	bool hovered_, pressed_;

}
