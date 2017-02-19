#priority init 1501
import maps;
import empire_data;

#section game
import dialogue;
#section all

#section server
import object_creation;
import influence;
import tile_resources;
import scenario;
from influence import InfluenceStore;
from influence_global import influenceLock, cardStack, deck, nextStackId, StackInfluenceCard;
import systems;
import map_loader;
#section all

Mono1 _map;
class Mono1 : Map {
	Mono1() {
		super();
		
		isListed = false;
		isScenario = true;
	}

#section server
	void prepareSystem(SystemData@ data, SystemDesc@ desc) {
		@data.homeworlds = null;
		Map::prepareSystem(data, desc);
	}
	
	bool canHaveHomeworld(SystemData@ data, Empire@ emp) {
		return false;
	}
	
	void preGenerate() {
		Map::preGenerate();
		radius = 10000;
	}
	
	void placeSystems() {
		loadMap("maps/Campaign/Mono/Mono1.txt").generate(this);
	}
	
	void modSettings(GameSettings& settings) {
		settings.empires.length = 1;
		settings.empires[0].name = locale::CAMPAIGN_MONO_PLAYEREMP;
		settings.empires[0].shipset = "Mechanica";
		getRacePreset(7).apply(settings.empires[0]); // This could change if more presets are added before Mono. Must correct this somehow.
		settings.empires[0].color = Color(0x303030ff);
		settings.empires[0].flag = "flag19";
		config::ENABLE_UNIQUE_SPREADS = 0.0;
		config::DISABLE_STARTING_FLEETS = 1.0;
		config::ENABLE_DREAD_PIRATE = 0.0;
		config::ENABLE_INFLUENCE_EVENTS = 0.0;
		config::START_EXPLORED_MAP = 1.0;
		config::IS_SCENARIO = 1.0;
	}
	
	const SystemDesc@ arith;
	Planet@ node00;
	Planet@ node01;
	
	void init() {
		@arith = systems[0];
		@node00 = systemData[0].planets[0];
		@node01 = systemData[0].planets[1];
		
		@node00.owner = playerEmpire;
		node00.addPopulation(1.0);
		@playerEmpire.Homeworld = node00;
		playerEmpire.Victory = -3;
		
		initDialogue();
	}
	
	void postInit() {
		@arith = systems[0];
		@node00 = systemData[0].planets[0];
		@node01 = systemData[0].planets[1];
	}
	
	void initDialogue() {
		Dialogue("MONO1_INTRO", false, false)
			.onPass(GUIAction("Mono1.Mono1::HideGUI"));
		Dialogue("MONO1_INTRO2")
			.setSpeaker(Sprite(material::emp_portrait_mono), "Unit-00", true);
		Dialogue("MONO1_INTRO3", false)
			.setSpeaker(Sprite(material::emp_portrait_mono), "Unit-3682");
		//Dialogue("")
	}
	
	void save(SaveFile& file) {
		file << node00;
		file << node01;
		saveDialoguePosition(file);
	}
	
	void load(SaveFile& file) {
		file >> node00;
		file >> node01;
		@arith = getSystem(0);
		
		initDialogue();
		loadDialoguePosition(file);
	}
	
#section all	
};

#section server
class CheckBuiltFactory : ObjectiveCheck {
	bool check() {
		return false;
	}
}
	
#section gui
from tabs.tabbar import tabBar, globalBar, closeTab, tabs, newTab, ActiveTab;
from tabs.GlobalBar import GlobalBar;
from tabs.GalaxyTab import GalaxyTab;
from tabs.PlanetsTab import createPlanetsTab;
from tabs.ResearchTab import createResearchTab, ResearchTab;
from tabs.DiplomacyTab import createDiplomacyTab;
from community.Home import createCommunityHome;
from tabs.DesignOverviewTab import createDesignOverviewTab;
from tabs.DesignEditorTab import DesignEditor;
from navigation.SmartCamera  import CAM_PANNED, CAM_ZOOMED, CAM_ROTATED;
from overlays.PlanetInfoBar import PlanetInfoBar;
from overlays.Supports import SupportOverlay;
from overlays.Construction import OrbitalTarget;
from targeting.targeting import mode;
from targeting.ObjectTarget import AbilityTargetObject, ObjectMode;
from targeting.PointTarget import PointTargetMode;
from overlays.TimeDisplay import ShowTimeDisplay;

class HideGUI : DialogueAction {
	void call() {
		//Global bar
		auto@ gbar = cast<GlobalBar>(globalBar);
		gbar.energy.visible = false;
		gbar.defense.visible = false;
		gbar.influence.visible = false;
		gbar.research.visible = false;

		//Tab bar
		tabBar.goButton.visible = false;
		tabBar.newButton.visible = false;
		tabBar.homeButton.visible = false;

		for(uint i = 1, cnt = tabs.length; i < cnt; ++i)
			closeTab(tabs[1]);
		tabs[0].locked = true;
	}
}

class ZoomHomeworld : DialogueAction {
	void call() {
		auto@ gtab = cast<GalaxyTab>(tabs[0]);
		gtab.zoomTo(playerEmpire.planetList[0]);
	}
};
#section all