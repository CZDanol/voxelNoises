module ac.client.gui.labelwidget;

import ac.client.gui.devtoolkit;

final class LabelWidget : Widget {

public:
	this(string text = "") {
		optimalSize_ = Vec2I(150, 18);
		text_ = text;

		dtext_ = new Text();
		dtext_.setFont(guiResources.defaultFont);
		dtext_.setCharacterSize(guiResources.fontSize);
		dtext_.setColor(guiResources.fontColor);
	}

public:
	string text() {
		return text_;
	}

	void text(string set) {
		text_ = set;
	}

public:
	override void draw(RenderTarget rt, RenderStates rs) {
		dtext_.setString(text_);
		FloatRect b = dtext_.getLocalBounds();

		Vec2F pos = cast(Vec2F) pos_ + cast(Vec2F) size_ / 2 - Vec2F(b.left + b.width / 2, b.top + b.height / 2);
		dtext_.position = Vector2f(pos.x, pos.y);
		dtext_.position = Vector2f(cast(int) dtext_.position.x, cast(int) dtext_.position.y);
		dtext_.draw(rt, rs);
	}

private:
	Text dtext_;
	string text_;

}
