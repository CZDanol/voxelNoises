module ac.client.gui.guiresources;

import dsfml.graphics;

__gshared GUIResources guiResources;

final class GUIResources {

public:
	this() {
		defaultFont = new Font();
		defaultFont.loadFromFile("../res/font/FiraCode-Regular.ttf");
	}

public:
	Font defaultFont;

public:
	int outlineThickness = 1;
	int fontSize = 12;

	int sliderSize = 16;

public:
	Color fontColor = Color(255, 255, 255);
	Color outlineColor = Color(255, 255, 255, 128);
	Color inactiveFaceColor = Color(10, 10, 10, 200);
	Color hoveredFaceColor = Color(40, 40, 40, 200);
	Color pressedFaceColor = Color(70, 70, 70, 200);

}
