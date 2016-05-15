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

class GloryBar : BaseGuiElement {
	Attitude meter;
	
	GuiMarkupText@ title;
	GuiMarkupText@ progressText;
	GuiProgressbar@ bar;
	
	array<LevelMarker@> markers;
	
	GloryBar(IGuiElement@ parent) {
		super(parent, Alignment(Left+0.2-14, Top+1, Right-0.2f+14, Height=150));
		
		@title = GuiMarkupText(this, Alignment(Left+12, Top+8, Right-12, Top+40));
		title.defaultFont = FT_Medium;
		title.defaultStroke = colors::Black;

		@progressText = GuiMarkupText(this, Alignment(Left+20, Top+36, Right-12, Top+65));
		progressText.defaultColor = Color(0x888888ff);
		progressText.defaultStroke = colors::Black;
		
		@bar = GuiProgressbar(this, Alignment(Left+26, Top+65, Right-26, Top+110));
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
			progressText.text = format("[color=#aaa][b]$1 $2:[/b][/color] $3",
				locale::LEVEL, toString(meter.nextLevel),
				format(meter.type.progress, toString(nextProgress-curProgress, 0)));
		}
		else {
			progressText.text = format(locale::GLORY_MAXIMUM, meter.type.name);
		}
		
		title.text = meter.type.name;
		bar.frontColor = meter.type.color;
		bar.progress = curProgress / finalProgress;
		
		//Level markers
		uint prevCnt = markers.length;
		uint newCnt = meter.type.levels.length;
		for(uint i = newCnt; i < prevCnt; ++i)
			markers[i].remove();
		markers.length = newCnt;
		for(uint i = prevCnt; i < newCnt; ++i)
			@markers[i] = LevelMarker(bar);
			
		for(uint i = 0; i < newCnt; ++i) {
			@markers[i].lvl = meter.type.levels[i];
			markers[i].update(meter);
		}
		
	}
	
	void draw() override {
		if(meter is null || meter.type is null)
			return;
		skin.draw(SS_PlainOverlay, SF_Normal, AbsolutePosition.padded(0, -2, 0, 0));
		BaseGuiElement::draw();
	}
}