module ac.client.main;

import bindbc.opengl;
import dsfml.graphics;
import std.exception;
import std.format;
import std.stdio;
import std.algorithm;
import std.conv;
import ac.client.gl;
import ac.client.gui.guiresources;
import ac.client.gui.widgets;
import ac.common.math.vector;
import ac.common.math.matrix;
import ac.client.application;
import std.datetime : Duration;
import std.datetime.stopwatch;

enum chunkSize = 128;
enum blockSize = 512 / chunkSize;

// These two lines force the app to run on the dedicated graphics card by default
extern (C) export ulong NvOptimusEnablement = 0x00000001;
extern (C) export int AmdPowerXpressRequestHighPerformance = 1;

void main() {
	glResourceManager = new GLResourceManager();
	scope (exit)
		glResourceManager.releaseAll();

	glState = new GLState();
	guiResources = new GUIResources();

	application = new ClientApplication();
	application.initialize();
	application.run();
}

enum MAX_OCTAVE_COUNT = 8;

// std140 :/
struct GLFloatArrayItem {
	GLfloat val;
	GLfloat[3] padding;
	alias val this;
}

struct GenParams {
	GLFloatArrayItem[MAX_OCTAVE_COUNT] octaveWeight;
	GLint chunkSize, octaveSize, executionCount;
	GLfloat time;
}

class ClientApplication : Application {

public:
	this() {
		super("AnotherCraft");
	}

protected:
	override void drawGUI() {
		ui.fps.text = "FPS: %s".format(currentFps);
	}

	override void drawGL() {
		//Matrix m = Matrix.orthogonal(Vec2F(window.getSize.x, window.getSize.y));
		Matrix m = Matrix.perspective(cast(Vec2F) windowSize);

		//m *= Matrix.translation(window.getSize.x / 2, window.getSize.y / 2, chunkSize * blockSize);
		m *= Matrix.translation(0, 0, -chunkSize * 2);

		m *= viewManipulationMatrix;

		//m *= Matrix.scaling(blockSize);
		m *= Matrix.translation(-chunkSize / 2 - 0.5f, -chunkSize / 2 - 0.5f, -chunkSize / 2 - 0.5f);

		visualisationContext.setUniform("matrix", m);
		visualisationContext.bind();

		glDrawArrays(GL_POINTS, 0, cast(GLint) pointsBuffer.pointCount);
	}

protected:
	override void initialize() {
		super.initialize();
		prepareResources();
		createUi();
		generateChunk();
	}

	void prepareResources() {
		// Generation pipeline
		{
			genContext = new GLProgramContext();

			genPrograms = [ //
			new GLProgram("optimizedPerlin", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1"]), //
				new GLProgram("slightlyOptimizedPerlin", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1"]), //
				new GLProgram("unoptimizedPerlin", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1"]), //
				new GLProgram("ashima", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1"]), //
				new GLProgram("ashimasimplex", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1"]), //
				new GLProgram("optimizedPerlin", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1", "NOISE4D" : "true"]), //
				new GLProgram("2dOptimizedPerlin", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1"]), //
				new GLProgram("2dOptimizedPerlin", [GLProgramShader.compute], ["OCTAVE_COUNT" : "1", "NOISE3D": "true"]), //
				new GLProgram("perlin", GLProgramShader.compute), //
				new GLProgram("simplex", [GLProgramShader.compute], ["OCTAVE_COUNT": "1"]), //
				new GLProgram("voronoi", GLProgramShader.compute), //
				new GLProgram("3dvoronoi", GLProgramShader.compute) //
				];

			voxelTexture = new GLTexture(GL_TEXTURE_3D);
			voxelTexture.bind(0);

			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

			// Consider voxels outside the chunk empty (border color = 0)
			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);
			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

			glTexStorage3D(GL_TEXTURE_3D, 1, GL_R8UI, chunkSize, chunkSize, chunkSize);
		}

		// Visualisation pipeline
		{
			// Points buffer - each point represents one voxel. It is then expanded into appropriate faces in the geometry shader
			pointsBuffer = new GLBuffer!Vec3I();
			foreach (x; 0 .. chunkSize) {
				foreach (y; 0 .. chunkSize) {
					foreach (z; 0 .. chunkSize) {
						pointsBuffer ~= Vec3I(x, y, z);
					}
				}
			}
			pointsBuffer.upload(GL_STATIC_DRAW);

			renderProgram = new GLProgram("render", GLProgramShader.geometry, GLProgramShader.vertex, GLProgramShader.fragment);
			renderProgram.link();

			visualisationContext = new GLProgramContext(renderProgram);
			visualisationContext.enable(GL_DEPTH_TEST);
			visualisationContext.enable(GL_CULL_FACE);
			visualisationContext.bindBuffer("pos", pointsBuffer);
			visualisationContext.bindTexture("world", voxelTexture);
			visualisationContext.setUniform("chunkSize", chunkSize);
		}
	}

	void createUi() {
		auto bl = new BoxLayoutWidget(BoxLayoutWidget.Orientation.horizontal);
		bl.margin = 8;
		bl.addItem(new SpacerWidget(SpacerWidget.Orientation.horizontal));

		{
			auto bl2 = new BoxLayoutWidget(BoxLayoutWidget.Orientation.vertical);

			ui.genFunction = new ComboBoxWidget(["Opt. Perlin", "Hopt. Perlin", "Unopt. Perlin", "[Ashima]", "[Ashima simplex]", "3D+T Opt. Perlin", "2D Opt. Perlin", "2D+T Opt. Perlin", "1oct Perlin", "1oct Simplex", "2D Voronoi", "3D Voronoi"]);
			ui.genFunction.onCurrentItemChangedByUser = { //
				generateChunk();
			};
			bl2.addItem(ui.genFunction);

			ui.coloring = new ComboBoxWidget(["Terrain", "Clouds", "Noise value"]);
			ui.coloring.onCurrentItemChangedByUser = { //
				visualisationContext.setUniform("coloring", cast(int) ui.coloring.currentItem);
			};
			bl2.addItem(ui.coloring);

			ui.threshold = new SliderWidget(SliderWidget.Orientation.horizontal);
			ui.threshold.onValueChanged = { //
				visualisationContext.setUniform("threshold", round(ui.threshold.value * 255).to!int);
			};
			ui.threshold.value = 0.6;
			bl2.addItem(new LabelWidget("Threshold"));
			bl2.addItem(ui.threshold);

			ui.time = new SliderWidget(SliderWidget.Orientation.horizontal);
			ui.time.onValueChanged = { //
				generateChunk();
			};
			bl2.addItem(new LabelWidget("Time"));
			bl2.addItem(ui.time);

			ui.lightDirection = new SliderWidget(SliderWidget.Orientation.horizontal);
			ui.lightDirection.onValueChanged = { //
				Matrix m;
				m *= Matrix.rotationY(ui.lightDirection.value * 2 * PI);
				m *= Matrix.rotationX(0.25 * PI);

				visualisationContext.setUniform("lightDirection", m.transformed(Vec3F(0, 1, 0)));
			};
			ui.lightDirection.value = 0.1f;
			bl2.addItem(new LabelWidget("Light direction"));
			bl2.addItem(ui.lightDirection);

			ui.ambientLight = new SliderWidget(SliderWidget.Orientation.horizontal);
			ui.ambientLight.onValueChanged = { //
				visualisationContext.setUniform("ambientLight", ui.ambientLight.value);
			};
			ui.ambientLight.value = 0.2;
			bl2.addItem(new LabelWidget("Ambient light"));
			bl2.addItem(ui.ambientLight);

			ui.octaveSize = new SliderWidget(SliderWidget.Orientation.horizontal);
			ui.octaveSize.minValue = 0;
			ui.octaveSize.maxValue = 8;
			ui.octaveSize.onValueChangedByUser = { //
				ui.octaveSize.value = round(ui.octaveSize.value);
				generateChunk();
			};
			ui.octaveSize.onValueChanged = { //
				octaveSize_ = cast(int)(16 * pow(2, round(ui.octaveSize.value)));
				ui.octaveSizeLabel.text = "Octave size: %s".format(octaveSize_);
			};
			ui.octaveSizeLabel = new LabelWidget();
			ui.octaveSize.value = 1;
			bl2.addItem(ui.octaveSizeLabel);
			bl2.addItem(ui.octaveSize);

			ui.octaveCount = new SliderWidget(SliderWidget.Orientation.horizontal);
			ui.octaveCount.minValue = 1;
			ui.octaveCount.maxValue = 8;
			ui.octaveCount.onValueChangedByUser = { //
				ui.octaveCount.value = round(ui.octaveCount.value);

				foreach (prog; genPrograms)
					prog.define("OCTAVE_COUNT", cast(int) ui.octaveCount.value);

				generateChunk();
			};
			ui.octaveCount.onValueChanged = { //
				ui.octaveCountLabel.text = "Octave count: %s".format(ui.octaveCount.value);
			};
			ui.octaveCountLabel = new LabelWidget();
			ui.octaveCount.value = 1;
			bl2.addItem(ui.octaveCountLabel);
			bl2.addItem(ui.octaveCount);

			foreach (i, ref wgt; ui.octaveWeights) {
				wgt = new SliderWidget(SliderWidget.Orientation.horizontal);
				wgt.onValueChangedByUser = { //
					generateChunk();
				};
				wgt.value = 0.4 * pow(1.2, i);
				bl2.addItem(new LabelWidget("Octave %s weight".format(8 << i)));
				bl2.addItem(wgt);
			}

			ui.updateButton = new ButtonWidget("Benchmark");
			ui.updateButton.onClick = { //
				generateChunk(true);
			};
			bl2.addItem(ui.updateButton);

			ui.generationTime = new LabelWidget();
			bl2.addItem(ui.generationTime);

			ui.fps = new LabelWidget();
			bl2.addItem(ui.fps);

			bl2.addItem(new SpacerWidget(SpacerWidget.Orientation.vertical));
			bl.addItem(bl2);
		}

		mainWidget_ = bl;
		mainWidget_.recalculate(Vec2I(), windowSize);
	}

	void generateChunk(bool benchmark = false) {
		GLProgram genProgram = genPrograms[ui.genFunction.currentItem];

		genContext.setProgram(genProgram);

		GenParams params;
		params.chunkSize = chunkSize;
		params.octaveSize = octaveSize_;
		params.executionCount = benchmark ? 200 : 1;
		params.time = ui.time.value * 5;

		foreach (i; 0 .. MAX_OCTAVE_COUNT)
			params.octaveWeight[i] = ui.octaveWeights[i].value;

		genContext.setUniformBlock("Parameters", params);
		genContext.setUniform("world", 0);
		genContext.bind();

		glBindImageTexture(0, voxelTexture.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_R8UI);

		glFinish();
		auto sw = StopWatch(AutoStart.yes);

		enum localSize = 8;
		glDispatchCompute(chunkSize / localSize, chunkSize / localSize, chunkSize / localSize); // Make sure writing to the image if finished

		glFinish();

		ui.generationTime.text = benchmark ? "%s ms / 200 runs".format(sw.peek.total!"msecs") : "";
	}

protected:
	override void mouseButtonPressEvent(const ref Widget.MouseButtonEvent ev) {
		if (ev.button == Widget.MouseButton.left) {
			addMouseEventListener((const ref MouseEvent ev) { //
				if (!ev.buttonPressed[Mouse.Button.Left])
					return false;

				viewManipulationMatrix = viewManipulationMatrix * Matrix.rotationY(-ev.deltaPos.x * 0.003);
				viewManipulationMatrix = Matrix.rotationX(ev.deltaPos.y * 0.003) * viewManipulationMatrix;

				return true;
			});
		}
		else if (ev.button == Widget.MouseButton.wheel) {
			viewManipulationMatrix *= Matrix.scaling(1 + ev.wheelDelta * 0.05);
		}
	}

private:
	GLBuffer!Vec3I pointsBuffer;
	GLProgram renderProgram;
	GLProgram[] genPrograms;
	GLTexture voxelTexture;
	GLProgramContext visualisationContext, genContext;
	int octaveSize_;

private:
	Matrix viewManipulationMatrix;

private:
	static struct UI {
		ComboBoxWidget genFunction, coloring;
		SliderWidget threshold, time, lightDirection, ambientLight, octaveSize, octaveCount;
		SliderWidget[MAX_OCTAVE_COUNT] octaveWeights;
		ButtonWidget updateButton;
		LabelWidget fps, generationTime, octaveSizeLabel, octaveCountLabel;
	}

	UI ui;

}
