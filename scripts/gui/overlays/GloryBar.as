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
import ABEM_glory;

class MilestoneMarker : BaseGuiElement {
	const GloryMilestone@ lvl;
	Color color;
	bool reached;
	bool hovered = false;
	
	MilestoneMarker(IGuiElement@ parent) {
		super(parent, recti(0,0, 42,70));
		noClip = true;
		auto@ tt = addLazyMarkupTooltip(this, width=300);
		tt.FollowMouse = false;
		tt.offset = vec2i(0, 5);
	}
	
	string get_tooltip() {
		string tt;
		tt += lvl.gloryType.description;
		tt += lvl.description;
		return tt;
	}
	
	void update(GloryMeter@ meter) {
		double finalProgress = meter.milestones[meter.maxMilestone].threshold;
		double pct = clamp(lvl.threshold / finalProgress, 0.0, 1.0);
		
		reached = meter.milestone >= lvl.milestone+1;
		position = vec2i(parent.size.x * pct - size.width / 2, 0);
		
		if(reached)
			color = Color(0x000000ff).interpolate(meter.type.color, 0.4);
		else
			color = Color(0x666666ff);
	}
	
	bool onGuiEvent(const GuiEvent& evt) {
		switch(evt.type) {
			case GUI_Mouse_Entered:
				if(evt.caller is this)
					hovered = true;
			break;
			case GUI_Mouse_Left:
				if(evt.caller is this)
					hovered = false;
			break;
		}
		return BaseGuiElement::onGuiEvent(evt);
	}
	
	void draw() override {
		if(hovered) {
			drawLine(AbsolutePosition.topLeft + vec2i(size.width/2, 2),
					 AbsolutePosition.topLeft + vec2i(size.width/2, size.height-35),
					 Color(0xffffff40), 12);
		}

		drawLine(AbsolutePosition.topLeft + vec2i(size.width/2, 2),
				 AbsolutePosition.topLeft + vec2i(size.width/2, size.height),
				 Color(0x00000080), 5);

		drawLine(AbsolutePosition.topLeft + vec2i(size.width/2, 2),
				 AbsolutePosition.topLeft + vec2i(size.width/2, size.height),
				 color, 3);

		recti iconPos = recti_area(5,size.height-32, 32,32) + AbsolutePosition.topLeft;
		if(hovered)
			drawRectangle(iconPos.padded(-4), Color(0xffffff40));
		drawRectangle(iconPos.padded(-2), Color(0x00000080));
		drawRectangle(iconPos, color);

		lvl.icon.draw(iconPos.aspectAligned(lvl.icon.aspect));
		BaseGuiElement::draw();
	}
}

class GloryBar : BaseGuiElement {
	GloryMeter@ meter;
	
	GuiMarkupText@ title;
	GuiMarkupText@ progressText;
	GuiProgressbar@ bar;
	
	array<MilestoneMarker@> markers;
	
	GloryBar(IGuiElement@ parent) {
		super(parent, Alignment(Left+0.2, Top+TAB_HEIGHT+GLOBAL_BAR_HEIGHT+1, Right-0.2f, Height=150));
		
		@title = GuiMarkupText(this, Alignment(Left+12, Top+8, Right-12, Top+40));
		title.defaultFont = FT_Medium;
		title.defaultStroke = colors::Black;

		@progressText = GuiMarkupText(this, Alignment(Left+20, Top+36, Right-12, Top+65));
		progressText.defaultColor = Color(0x888888ff);
		progressText.defaultStroke = colors::Black;
		
		@bar = GuiProgressbar(this, Alignment(Left+12, Top+65, Right-12, Top+110));
		updateAbsolutePosition();
	}
	
	void update() {
		if(playerEmpire is null || !playerEmpire.valid)
			return;
		else {
			meter = playerEmpire.getGloryMeter();
		}
		if(meter is null || meter.type is null) 
			return;
		updateAbsolutePosition();
		
		double curProgress = meter.progress;
		double nextProgress = meter.milestones[meter.nextMilestone].threshold;
		double finalProgress = meter.milestones[meter.maxMilestone].threshold;
		
		//Progress data
		// As if the code itself wasn't enough to explain that this is a simplified Attitude, I copy the comments too...
		if(nextProgress > curProgress) {
			progressText.text = format("[color=#aaa][b]$1 $2:[/b][/color] $3",
				locale::LEVEL, toString(meter.nextMilestone),
				format(meter.type.progress, toString(nextProgress-curProgress, o)));
		}
		else {
			progressText.text = format(locale::GLORY_MAXIMUM, meter.type.name);
		}
		
		title.text = meter.type.name;
		bar.frontColor = meter.type.color;
		bar.progress = curProgress / finalProgress;
		
		//Level markers
		uint prevCnt = markers.length;
		uint newCnt = meter.type.milestones.length;
		for(uint i = newCnt; i < prevCnt; ++i)
			markers[i].remove();
		markers.length = newCnt;
		for(uint i = prevCnt; i < newCnt; ++i)
			@markers[i] = MilestoneMarker(bar);
			
		for(uint i = 0; i < newCnt; ++i) {
			@markers[i].lvl = meter.type.milestones[i];
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