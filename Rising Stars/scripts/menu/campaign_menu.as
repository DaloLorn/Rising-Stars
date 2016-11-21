import menus;
import saving;
import dialogs.MessageDialog;
import dialogs.QuestionDialog;
import elements.GuiMarkupText;
import settings.game_settings;
import campaign;

class CampaignMenu : MenuBox {
	ScenarioBox box;
	int prevSelected = 1;

	void buildMenu() {
		title.text = "Campaign";
		selectable = true;
		items.required = true;

		reloadCampaignCompletion();
		items.addItem(MenuAction(Sprite(spritesheet::MenuIcons, 11), locale::MENU_BACK, 0));

		for(uint i = 0, cnt = getCampaignScenarioCount(); i < cnt; ++i) {
			auto@ scen = getCampaignScenario(i);

			MenuAction action(scen.icon, scen.name, i+1);
			action.disabled = !scen.isAvailable;
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
		description.text = scen.description;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes)
			cast<CampaignMenu>(campaign_menu).start();
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		if(evt.type == GUI_Clicked && evt.caller is startButton) {
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
