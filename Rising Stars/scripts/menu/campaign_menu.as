import menus;
import saving;
import dialogs.MessageDialog;
import dialogs.QuestionDialog;
import elements.GuiMarkupText;
import settings.game_settings;
import campaign;

class CampaignAction : MenuAction {
	double indentOffset = 0.0;

	CampaignAction(const string& txt, int val, bool dis = false) {
		super(txt, val, dis);
	}
	
	CampaignAction(const Sprite& sprt, const string& txt, int val, bool dis = false) {
		super(sprt, txt, val, dis);
	}

	void draw(GuiListbox@ ele, uint flags, const recti& absPos) override {
		const Font@ font = ele.skin.getFont(ele.TextFont);
		int baseLine = font.getBaseline();
		vec2i textOffset(ele.horizPadding, (ele.lineHeight - baseLine) / 2);
		textOffset.x += (offset + indentOffset) * MENU_OFFSET;
		if(ele.itemStyle == SS_NULL)
			ele.skin.draw(SS_ListboxItem, flags, absPos);
		if(icon.valid) {
			int iSize = absPos.height - 6;
			recti iPos = recti_area(absPos.topLeft + vec2i(textOffset.x, 4), vec2i(iSize, iSize));
			iPos = iPos.aspectAligned(icon.aspect);
			icon.draw(iPos);
			textOffset.x += iSize + 8;
		}
		if(disabled)
			font.draw(absPos.topLeft + textOffset, text, Color(0x888888ff));
		else
			font.draw(absPos.topLeft + textOffset, text, color);
		if(flags & SF_Hovered != 0)
			offset = min(1.0, offset + (frameLength / MENU_OFFSET_TIME));
		else
			offset = max(0.0, offset - (frameLength / MENU_OFFSET_TIME));
	}
}

class CampaignMenu : MenuBox {
	ScenarioBox box;
	int prevSelected = 1;

	void buildMenu() {
		title.text = locale::CAMPAIGN;
		selectable = true;
		items.required = true;

		reloadCampaignCompletion();
		items.addItem(MenuAction(Sprite(spritesheet::MenuIcons, 11), locale::MENU_BACK, 0));

		for(uint i = 0, cnt = getCampaignScenarioCount(); i < cnt; ++i) {
			auto@ scen = getCampaignScenario(i);

			CampaignAction action(scen.icon, scen.name, i+1);
			if(!scen.isAvailable)
				action.color = Color(0x888888ff);
				
			action.indentOffset = scen.parentCount;
			
			items.addItem(action);
		}

		if(items.selected < 1)
			items.selected = prevSelected;
		update();
	}

	void update() {
		auto@ scen = getCampaignScenario(items.selected-1);
		if(scen !is null)
			box.update(scen);
	}

	void onSelected(const string& name, int value) {
		if(value == 0) {
			switchToMenu(main_menu, false);
			return;
		}
		else {
			prevSelected = value;
			items.selected = value;
			update();
		}
	}

	void animate(MenuAnimation type) {
		if(type == MAni_LeftOut || type == MAni_RightOut)
			showDescBox(null);
		MenuBox::animate(type);
	}

	void completeAnimation(MenuAnimation type) {
		if(type == MAni_LeftShow || type == MAni_RightShow)
			showDescBox(box);
		MenuBox::completeAnimation(type);
	}

	void start() {
		auto@ scen = getCampaignScenario(items.selected-1);
		if(scen is null)
			return;

		GameSettings settings;
		settings.defaults();
		settings.galaxies[0].map_id = scen.mapName;

		Message msg;
		settings.write(msg);
		startNewGame(msg);
		switchToMenu(main_menu);
	}
};

class ScenarioBox : DescBox, QuestionDialogCallback {
	GuiSprite@ picture;
	GuiMarkupText@ description;
	GuiButton@ startButton;
	bool isAvailable;
	bool isScenario;

	ScenarioBox() {
		super();

		@picture = GuiSprite(this, Alignment(Left, Top+44, Right, Top+244));

		@description = GuiMarkupText(this, Alignment(Left+16, Top+254, Right-16, Bottom-50));

		@startButton = GuiButton(this, Alignment(Left+0.5f-100, Bottom-50, Left+0.5f+100, Bottom-8), locale::START);
		startButton.color = colors::Green;
		startButton.font = FT_Subtitle;
		startButton.buttonIcon = Sprite(spritesheet::MenuIcons, 9);

		updateAbsolutePosition();
	}

	void update(const CampaignScenario@ scen) {
		title.text = scen.name;
		picture.desc = scen.picture;
		string descText = scen.description;
		isAvailable = scen.isAvailable;
		isScenario = scen.mapName != "";
		if(isAvailable) {
			if(isScenario) {
				startButton.color = colors::Green;
				startButton.disabled = false;
			}
			else {
				startButton.color = Color(0x888888ff);
				startButton.disabled = true;
				descText += format("\n\n$1", locale::NOT_A_SCENARIO);
			}
			picture.color = Color(0xffffffff);
		}
		else{
			startButton.color = colors::Red;
			startButton.disabled = true;
			descText = "[color=#f00][b]" + locale::SCENARIO_NOT_COMPLETED + "\n";
			for(uint i = 0, cnt = scen.dependencies.length; i < cnt; ++i) {
				auto@ other = getCampaignScenario(scen.dependencies[i]);
				if(other !is null && !other.completed)
					descText += format("\n$1", other.name);
			}
			descText += "[/b][/color]";
			picture.color = Color(0x444444ff);
		}
		description.text = descText;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes)
			cast<CampaignMenu>(campaign_menu).start();
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		if(evt.type == GUI_Clicked && evt.caller is startButton) {
			if(!isAvailable || !isScenario)
				return true;
			if(game_running)
				question(locale::PROMPT_START_NEW, this);
			else
				cast<CampaignMenu>(campaign_menu).start();
			return true;
		}
		return DescBox::onGuiEvent(evt);
	}
};

void init() {
	@campaign_menu = CampaignMenu();
}
