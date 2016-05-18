import dialogue;
import elements.GuiButton;
import elements.GuiProgressbar;
import elements.GuiPanel;
import elements.GuiMarkupText;
import elements.GuiEmpire;
import elements.GuiOverlay;
import elements.GuiSkinElement;
import elements.GuiText;
import elements.MarkupTooltip;
import util.formatting;
import tabs.tabbar;
import attitudes;

from tabs.AttitudesTab import LevelMarker;

class GloryMarker : LevelMarker {

	GloryMarker(IGuiElement@ parent) {
		super(parent, recti(0,0, 26,29));
		noClip = true;
		auto@ tt = addLazyMarkupTooltip(this, width=300);
		tt.FollowMouse = false;
		tt.offset = vec2i(0, 5);
	}

	void draw() override {
		if(hovered) {
			drawLine(AbsolutePosition.topLeft + vec2i(size.width/2, 2),
					 AbsolutePosition.topLeft + vec2i(size.width/2, size.height-19),
					 Color(0xffffff40), 12);
		}

		drawLine(AbsolutePosition.topLeft + vec2i(size.width/2, 2),
				 AbsolutePosition.topLeft + vec2i(size.width/2, size.height),
				 Color(0x00000080), 5);

		drawLine(AbsolutePosition.topLeft + vec2i(size.width/2, 2),
				 AbsolutePosition.topLeft + vec2i(size.width/2, size.height),
				 color, 3);

		recti iconPos = recti_area(5,size.height-16, 16,16) + AbsolutePosition.topLeft;
		if(hovered)
			drawRectangle(iconPos.padded(-4), Color(0xffffff40));
		drawRectangle(iconPos.padded(-2), Color(0x00000080));
		drawRectangle(iconPos, color);

		lvl.icon.draw(iconPos.aspectAligned(lvl.icon.aspect));
		BaseGuiElement::draw();
	}

}

class GloryBar : BaseGuiElement {
	Attitude meter;
	GuiMarkupText@ progressText;
	GuiProgressbar@ bar;
	
	array<GloryMarker@> markers;
	
	GloryBar(IGuiElement@ parent) {
		super(parent, Alignment(Left+0.2-2, Top, Right-0.2f+2, Height=65));

		@progressText = GuiMarkupText(this, Alignment(Left+8, Top+2, Right-12, Top+31));
		progressText.defaultColor = Color(0x888888ff);
		progressText.defaultStroke = colors::Black;
		
		@bar = GuiProgressbar(this, Alignment(Left+14, Top+31, Right-14, Top+46));
		updateAbsolutePosition();
	}
	
	void update() {
		meter = Attitude();
		if(playerEmpire is null || !playerEmpire.valid) {
			return;
		}
		else {
			receive(playerEmpire.getGloryMeter(), @meter);
		}
		if(meter is null || meter.type is null) 
			return;
		updateAbsolutePosition();
		
		double curProgress = meter.progress;
		double nextProgress = meter.levels[meter.nextLevel].threshold;
		double finalProgress = meter.levels[meter.maxLevel].threshold;
		
		//Progress data
		// As if the code itself wasn't enough to explain that this is a simplified Attitude, I copy the comments too...
		if(nextProgress > curProgress) {
			progressText.text = format("[color=#aaa][b]$4 $1 $2:[/b][/color] $3",
				locale::LEVEL, toString(meter.nextLevel),
				format(meter.type.progress, toString(nextProgress-curProgress, 0)), meter.type.name);
		}
		else {
			progressText.text = format(locale::GLORY_MAXIMUM, meter.type.name);
		}
		bar.frontColor = meter.type.color;
		bar.progress = curProgress / finalProgress;
		
		//Level markers
		uint prevCnt = markers.length;
		uint newCnt = meter.type.levels.length;
		for(uint i = newCnt; i < prevCnt; ++i)
			markers[i].remove();
		markers.length = newCnt;
		for(uint i = prevCnt; i < newCnt; ++i)
			@markers[i] = GloryMarker(bar);
			
		for(uint i = 0; i < newCnt; ++i) {
			@markers[i].lvl = meter.type.levels[i];
			markers[i].update(meter);
		}
		
	}
	
	void draw() override {
		if(meter is null || meter.type is null)
			return;
		skin.draw(SS_PlainOverlay, SF_Normal, AbsolutePosition.padded(0, -1, 0, 0));
		BaseGuiElement::draw();
	}
}