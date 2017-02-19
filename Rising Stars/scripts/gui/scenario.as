import dialogue;
import elements.BaseGuiElement;
import elements.GuiPanel;
import elements.GuiDraggable;
import elements.GuiBackgroundPanel;
import elements.GuiMarkupText;
import elements.GuiSkinElement;
import elements.GuiButton;
import dialogs.MessageDialog;
from gui import animate_time;

const double FLASH_TIME = 0.6;

class ScenarioWindow : GuiDraggable {
	GuiBackgroundPanel@ bg;
	vec2i prevScreenSize;
	recti prevSmallPos;
	recti prevBigPos;

	GuiButton@ minButton;
	bool expanded = true;

	Dialogue dialogue;
	Dialogue newDialogue;
	GuiMarkupText@ dialogueBox;
	
	GuiBackgroundPanel@ leftSpeakerBox;
	GuiBackgroundPanel@ rightSpeakerBox;

	Objective objective;
	Objective newObjective;

	GuiSkinElement@ objBG;
	GuiMarkupText@ objBox;

	GuiButton@ nextButton;
	double flashTimer = -1.0;

	ScenarioWindow() {
		super(null, recti(0,0,850,280));
		@bg = GuiBackgroundPanel(this, Alignment(Left+150, Top, Right-150, Bottom));
		bg.titleColor = Color(0xb3fe00ff);
		bg.titleStyle = SS_FullTitle;
		
		@leftSpeakerBox = GuiBackgroundPanel(this, Alignment(Left, Top, Left+150, Top-150));
		leftSpeakerBox.pictureColor = Color(0xffffffff);
		
		@rightSpeakerBox = GuiBackgroundPanel(this, Alignment(Right-150, Top, Right, Top-150));
		rightSpeakerBox.pictureColor = Color(0xffffffff);

		@dialogueBox = GuiMarkupText(bg, recti());

		@minButton = GuiButton(bg, Alignment(Right-30, Top+2, Right-4, Top+28));
		minButton.color = Color(0xff8080ff);
		minButton.setIcon(Sprite(material::Minus));

		@objBG = GuiSkinElement(bg, Alignment(Left+8, Top+188, Right-8, Bottom-8), SS_PlainBox);
		@objBox = GuiMarkupText(objBG, Alignment(Left+4, Top+4, Right-4, Bottom-4));

		@nextButton = GuiButton(bg, Alignment(Right-92, Bottom-36, Right-2, Bottom-2), locale::NEXT);

		updateAbsolutePosition();
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		if(evt.type == GUI_Clicked) {
			if(evt.caller is minButton) {
				toggleExpand();
				return true;
			}
			if(evt.caller is nextButton) {
				skipDialogueObjective();
				objective.id = -1;
				return true;
			}
		}
		return GuiDraggable::onGuiEvent(evt);
	}

	void toggleExpand() {
		expanded = !expanded;
		if(expanded) {
			minButton.color = Color(0xff8080ff);
			minButton.setIcon(Sprite(material::Minus));

			recti pos;
			if(rect == prevSmallPos && prevBigPos.width > 150)
				pos = prevBigPos;
			else
				pos = recti_area(vec2i(rect.topLeft.x+150, max(rect.botRight.y-280, 0)), vec2i(700, 280));

			animate_time(this, pos, 0.2);
			prevBigPos = pos;
			prevSmallPos = rect;
		}
		else {
			minButton.color = Color(0x80ff80ff);
			minButton.setIcon(Sprite(material::Plus));

			recti pos;
			if(rect == prevBigPos && prevSmallPos.width > 150)
				pos = prevSmallPos;
			else
				pos = recti_area(vec2i(rect.topLeft.x+150, max(rect.botRight.y-32, 0)), vec2i(700, 32));

			animate_time(this, pos, 0.2);
			prevSmallPos = pos;
			prevBigPos = rect;
		}
		
		leftSpeakerBox.visible = expanded && leftSpeakerBox.picture.valid;
		rightSpeakerBox.visible = expanded && rightSpeakerBox.picture.valid;
		dialogueBox.visible = expanded;
		objBG.visible = expanded;
		objBox.visible = expanded;
		nextButton.visible = expanded;
	}

	void updateAbsolutePosition() override {
		if(screenSize != prevScreenSize) {
			rect = recti_area(vec2i((screenSize.width - 850) / 2,
						screenSize.height - size.height - 12), vec2i(850, size.height));
			prevScreenSize = screenSize;
		}
		GuiDraggable::updateAbsolutePosition();
	}
	
	void processDialogueInheritance() {
		if(dialogue is null)
			return;
			
		if(newDialogue.inheritTitle) {
			newDialogue.title = dialogue.title;
		}
		if(newDialogue.inheritLeftSpeaker) {
			newDialogue.portraitLeft = dialogue.portraitLeft;
			newDialogue.nameLeft = dialogue.nameLeft;
		}
		if(newDialogue.inheritRightSpeaker) {
			newDialogue.portraitRight = dialogue.portraitRight;
			newDialogue.nameRight = dialogue.nameRight;
		}
	}

	void update() {
		if(!hasDialogue()) {
			remove();
			return;
		}
	
		if(!receive(getActiveDialogue(), newDialogue))
			return;

		if(!receive(getActiveDialogueObjective(), newObjective)) {
			newObjective.title = "";
			newObjective.id = -1;
		}
		if(newObjective.id != objective.id) {
			if(flashTimer >= FLASH_TIME || objective.id == -1 || !objBG.visible) {
				processDialogueInheritance();
				objective = newObjective;
				dialogue = newDialogue;
				flashTimer = -1.0;
			}
			else {
				if(flashTimer < 0.0) {
					flashTimer = 0.0;
					sound::confirm.play();
				}
			}
			if(!expanded)
				toggleExpand();
		}
		else {
			processDialogueInheritance();
			objective = newObjective;
			dialogue = newDialogue;
		}

		bg.title = dialogue.title;
		dialogueBox.text = dialogue.text;
		
		leftSpeakerBox.picture = dialogue.portraitLeft;
		leftSpeakerBox.title = dialogue.nameLeft;
		
		rightSpeakerBox.picture = dialogue.portraitRight;
		rightSpeakerBox.title = dialogue.nameRight;
		
		if(dialogue.currentSpeakerIsLeft) {
			leftSpeakerBox.titleColor = colors::Red;
			rightSpeakerBox.titleColor = Color(0xffffffff);
		}
		else {
			rightSpeakerBox.titleColor = colors::Red;
			leftSpeakerBox.titleColor = Color(0xffffffff);		
		}
		
		leftSpeakerBox.visible = expanded && leftSpeakerBox.picture.valid;
		rightSpeakerBox.visible = expanded && rightSpeakerBox.picture.valid;

		if(objective.title.length != 0) {
			objBG.visible = expanded;
			objBox.text = format("[b]$1[/b]\n$2", objective.title, objective.text);
			dialogueBox.rect = recti(8,36, 542,188);
			nextButton.text = locale::NEXT;
		}
		else {
			objBG.visible = false;
			dialogueBox.rect = recti(8,36, 542,272);
			if(dialogue.proceedText.length != 0)
				nextButton.text = dialogue.proceedText;
			else
				nextButton.text = locale::NEXT;
		}
	}

	void tick(double time) {
		update();
		if(flashTimer >= 0.0)
			flashTimer += time;
		nextButton.visible =
			(objective.id == -1 || objective.skippable)
			 && flashTimer < 0 && expanded;
	}

	void draw() override {
		GuiDraggable::draw();
		if(flashTimer >= 0.0) {
			double alpha = flashTimer / FLASH_TIME;
			Color color = colors::Green;
			color.a = uint(alpha * 140.0);

			recti pos = objBG.absolutePosition;
			drawRectangle(pos, color);
			objBox.draw();
		}
	}
};

ScenarioWindow@ window;
class ServerMessage {
	string title;
	string text;
	Color color;
};
Mutex msgMtx;
array<ServerMessage> messages;

void sendMessage(string title, string text, uint color) {
	Lock lck(msgMtx);
	ServerMessage msg;
	msg.title = localize(title);
	msg.text = localize(text);
	if(color != 0)
		msg.color = Color(color);
	messages.insertLast(msg);
}

void init() {
	if(hasDialogue())
		@window = ScenarioWindow();
}

void tick(double time) {
	if(window !is null) {
		if(window.parent is null)
			@window = null;
		else
			window.tick(time);
	}
	if(messages.length != 0) {
		Lock lck(msgMtx);
		for(uint i = 0, cnt = messages.length; i < cnt; ++i) {
			auto@ dialog = message(messages[i].text);
			dialog.addTitle(messages[i].title);
			dialog.titleColor = messages[i].color;
		}
		messages.length = 0;
	}
}
