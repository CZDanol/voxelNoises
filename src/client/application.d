module ac.client.application;

import bindbc.opengl;
import dsfml.graphics;
import std.exception;
import std.format;
import std.stdio;
import std.algorithm;
import std.conv;
import std.datetime : Duration;
import std.datetime.stopwatch;
import ac.client.gl;
import ac.client.gui.widget;
import ac.common.math.vector;

__gshared Application application;

/// How many seconds passed between current and previous frame
__gshared float deltaTime;

abstract class Application {

public:
	alias MouseEventListener = bool delegate(const ref MouseEvent);

	struct MouseEvent {
		Vec2I pos, deltaPos;
		bool[Mouse.Button.Count] buttonPressed;
		int wheelDelta;
	}

	alias OverlayDraw = bool delegate(RenderTarget, RenderStates);

public:
	this(string windowTitle) {
		windowTitle_ = windowTitle;
	}

public:
	size_t currentFps() {
		return currentFps_;
	}

	Vec2I windowSize() {
		return windowSize_;
	}

	RenderWindow window() {
		return window_;
	}

public:
	/// When overriding, call the parent function first
	void initialize() {
		ContextSettings settings = ContextSettings(24, 8, 4, 3, 0);
		window_ = new RenderWindow(VideoMode(1280, 720), windowTitle_, Window.Style.DefaultStyle, settings);
		windowSize_ = Vec2I(window_.getSize.x, window_.getSize.y);

		GLSupport glSupport = loadOpenGL();
		enforce(glSupport != GLSupport.noLibrary, "OpenGL library failed to load");
		enforce(glSupport != GLSupport.badLibrary, "OpenGL bad library");
		enforce(glSupport != GLSupport.noContext, "OpenGL context was not created");
		enforce(glSupport >= GLSupport.gl43, "This application requires at least OpenGL v4.3 to run (currently %s)".format(glSupport));
	}

	void run() {
		appTimer_ = StopWatch(AutoStart.yes);
		fpsTimer_ = StopWatch(AutoStart.yes);

		Event event;
		mainLoop: while (true) {
			while (window_.pollEvent(event)) {
				switch (event.type) {

				case Event.EventType.Closed:
					break mainLoop;

				case Event.EventType.Resized:
					windowSize_ = Vec2I(event.size.width, event.size.height);

					glViewport(0, 0, windowSize_.x, windowSize_.y);
					window_.view = new View(Rect!float(0, 0, windowSize_.x, windowSize_.y));
					mainWidget_.recalculate(Vec2I(), windowSize_);
					break;

				case Event.EventType.MouseButtonPressed:
					pressedMouseButtons_[event.mouseButton.button] = true;
					{
						MouseEvent ev = MouseEvent(mousePos_, Vec2I(), pressedMouseButtons_, 0);
						emitMouseEvent(ev);
					}
					{
						Widget.MouseButtonEvent ev;
						ev.pos = mousePos_;
						ev.button = cast(Widget.MouseButton) event.mouseButton.button;

						if (!mainWidget_.mouseButtonPressEvent(ev))
							mouseButtonPressEvent(ev);
					}
					break;

				case Event.EventType.MouseButtonReleased:
					pressedMouseButtons_[event.mouseButton.button] = false;

					MouseEvent ev = MouseEvent(mousePos_, Vec2I(), pressedMouseButtons_, 0);
					emitMouseEvent(ev);
					break;

				case Event.EventType.MouseMoved:
					Vec2I prevMousePos = mousePos_;
					mousePos_ = Vec2I(event.mouseMove.x, event.mouseMove.y);

					{
						MouseEvent ev = MouseEvent(mousePos_, mousePos_ - prevMousePos, pressedMouseButtons_, 0);
						emitMouseEvent(ev);
					}
					{
						Widget.MouseMoveEvent ev;
						ev.pos = mousePos_;
						ev.deltaPos = mousePos_ - prevMousePos;

						mainWidget_.mouseMoveEvent(ev);
					}
					break;

				case Event.EventType.MouseWheelMoved: {
						MouseEvent ev = MouseEvent(mousePos_, Vec2I(), pressedMouseButtons_, event.mouseWheel.delta);
						emitMouseEvent(ev);
					}
					{
						Widget.MouseButtonEvent ev;
						ev.pos = mousePos_;
						ev.button = Widget.MouseButton.wheel;
						ev.wheelDelta = event.mouseWheel.delta;

						if (!mainWidget_.mouseButtonPressEvent(ev))
							mouseButtonPressEvent(ev);
					}
					break;

				default:
					break;

				}
			}

			window_.clear();
			glClear(GL_DEPTH_BUFFER_BIT);
			drawGL();

			glState.reset();
			window_.resetGLStates();

			mainWidget_.draw(window_, RenderStates());
			drawGUI();
			{
				OverlayDraw[] newOverlayDraws;
				foreach (OverlayDraw draw; overlayDraws_) {
					if (draw(window_, RenderStates()))
						newOverlayDraws ~= draw;
				}
				overlayDraws_ = newOverlayDraws;
			}

			window_.display();
			glResourceManager.cleanup();
			glState.forget();

			// Time measurement stuff
			{
				frameCounter_++;
				if (fpsTimer_.peek >= 1.seconds) {
					fpsTimer_.reset;
					currentFps_ = frameCounter_;
					frameCounter_ = 0;
				}

				Duration appTimerValue = appTimer_.peek;
				deltaTime = float((lastFrameDuration_ - appTimerValue).total!"usecs") / 1_000_000;
				lastFrameDuration_ = appTimerValue;
			}
		}
	}

public:
	/// Calls the listener for any mouse event until the function returns false
	void addMouseEventListener(MouseEventListener listener) {
		mouseEventListeners_ ~= listener;
	}

	/// Calls the draw function atop the GUI draw until the function returns false
	void addOverlayDraw(OverlayDraw draw) {
		overlayDraws_ ~= draw;
	}

public:
	void mouseButtonPressEvent(const ref Widget.MouseButtonEvent ev) {

	}

protected:
	void drawGUI() {
	}

	void drawGL() {

	}

private:
	void emitMouseEvent(const ref MouseEvent ev) {
		MouseEventListener[] newMouseEventListeners;

		foreach (MouseEventListener listener; mouseEventListeners_) {
			if (listener(ev))
				newMouseEventListeners ~= listener;
		}

		mouseEventListeners_ = newMouseEventListeners;
	}

private:
	RenderWindow window_;
	string windowTitle_;
	Vec2I windowSize_;

protected:
	Widget mainWidget_;

private:
	StopWatch appTimer_, fpsTimer_;
	Duration lastFrameDuration_;
	size_t frameCounter_, currentFps_;

private:
	bool[Mouse.Button.Count] pressedMouseButtons_;
	Vec2I mousePos_;
	MouseEventListener[] mouseEventListeners_;
	OverlayDraw[] overlayDraws_;

}
