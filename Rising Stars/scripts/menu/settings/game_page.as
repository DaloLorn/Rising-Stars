import util.settings_page;
import util.game_options;

GamePage page;
AdvancedGamePage advPage;
CrazyGamePage crazyPage;

class GamePage : GameSettingsPage {
	void makeSettings() {
		color = colors::Green;
		header = locale::NG_GAME_OPTIONS;
		icon = Sprite(material::TabPlanets);

		Title(locale::NG_UNIVERSE_GENERATION);
		Frequency(locale::NG_PLANET_FREQUENCY, "PLANET_FREQUENCY", min = 0.2, max = 3.0);
		Occurance(locale::NG_ANOMALY_OCCURANCE, "ANOMALY_OCCURANCE");
		Occurance(locale::NG_REMNANT_OCCURANCE, "REMNANT_OCCURANCE");
		Occurance(locale::NG_ASTEROID_OCCURANCE, "ASTEROID_OCCURANCE");
		Occurance(locale::NG_RESOURCE_ASTEROID_OCCURANCE, "RESOURCE_ASTEROID_OCCURANCE");
		Occurance(locale::NG_UNIQUE_SYSTEM_OCCURANCE, "UNIQUE_SYSTEM_OCCURANCE");
		Occurance(locale::NG_UNIQUE_RESOURCE_OCCURANCE, "UNIQUE_RESOURCE_OCCURANCE");
//		Occurance(locale::NG_ANOMALY_SYSTEM_OCCURANCE, "ANOMALY_SYSTEM_FREQ_MULT", tooltip=locale::NGTT_ANOMALY_SYSTEM_OCCURANCE, max = 10.0);
//		Occurance(locale::NG_BLACK_HOLE_OCCURANCE, "BLACK_HOLE_FREQ_MULT", tooltip=locale::NGTT_BLACK_HOLE_OCCURANCE, max = 10.0);
		Occurance(locale::NG_RESOURCE_SCARCITY, "RESOURCE_SCARCITY", max=2.0, tooltip=locale::NGTT_RESOURCE_SCARCITY);
		Occurance(locale::NG_CIVILIAN_TRADE, "CIVILIAN_TRADE_MULT", max=10.0, tooltip=locale::NGTT_CIVILIAN_TRADE);
		Frequency(locale::NG_ARTIFACT_FREQUENCY, "ARTIFACT_FREQUENCY", min = 0.2, max = 3.0);
		Frequency(locale::NG_SYSTEM_SIZE, "SYSTEM_SIZE", min = 0.2, max = 3.0);

		emptyline();
		Title(locale::NG_GAME_OPTIONS);
//		Occurance(locale::NG_RANDOM_EVENTS, "RANDOM_EVENT_OCCURRENCE", max=3.0);
		Toggle(locale::NG_ENABLE_DREAD_PIRATE, "ENABLE_DREAD_PIRATE", halfWidth=true, tooltip=locale::NGTT_ENABLE_DREAD_PIRATE);
		/*Toggle(locale::NG_ENABLE_CIVILIAN_TRADE, "ENABLE_CIVILIAN_TRADE", halfWidth=true);*/
		Toggle(locale::NG_ENABLE_INFLUENCE_EVENTS, "ENABLE_INFLUENCE_EVENTS", halfWidth=true, tooltip=locale::NGTT_ENABLE_INFLUENCE_EVENTS);
		Toggle(locale::NG_DISABLE_STARTING_FLEETS, "DISABLE_STARTING_FLEETS", halfWidth=true, tooltip=locale::NGTT_DISABLE_STARTING_FLEETS);
		Toggle(locale::NG_REMNANT_AGGRESSION, "REMNANT_AGGRESSION", halfWidth=true, tooltip=locale::NGTT_REMNANT_AGGRESSION);
		Toggle(locale::NG_ALLOW_TEAM_SURRENDER, "ALLOW_TEAM_SURRENDER", halfWidth=true, tooltip=locale::NGTT_ALLOW_TEAM_SURRENDER);
		Toggle(locale::NG_START_EXPLORED_MAP, "START_EXPLORED_MAP", halfWidth=true, tooltip=locale::NGTT_START_EXPLORED_MAP);

		auto@ tforming = Toggle(locale::NG_ENABLE_TERRAFORMING, "ENABLE_TERRAFORMING", halfWidth=true, tooltip=locale::NGTT_ENABLE_TERRAFORMING);
		if(hasDLC("Heralds")) {
			tforming.DefaultValue = false;
			tforming.set(false);
		}
//		Toggle(locale::NG_LEGACY_EXPLORATION, "LEGACY_EXPLORATION_MODE", halfWidth=true, tooltip=locale::NGTT_LEGACY_EXPLORATION);

		emptyline();
		Title(locale::NG_VICTORY_OPTIONS);
		Number(locale::NG_TIME_LIMIT, "GAME_TIME_LIMIT", tooltip=locale::NGTT_TIME_LIMIT, halfWidth=true, step=10);
		Toggle(locale::NG_ENABLE_REVENANT_PARTS, "ENABLE_REVENANT_PARTS", tooltip=locale::NGTT_ENABLE_REVENANT_PARTS);
		if(hasDLC("Heralds"))
			Toggle(locale::NG_ENABLE_INFLUENCE_VICTORY, "ENABLE_INFLUENCE_VICTORY", tooltip=locale::NGTT_ENABLE_INFLUENCE_VICTORY);

		//emptyline();
		//Title(locale::NG_SENSOR_OPTIONS);
	}
};

class AdvancedGamePage : GameSettingsPage {
	// Need GuiGameFrequency's functionality with a tooltip, so I'm improvising from util.settings_page::SettingsPage and hoping it'll work.
	// ... I have no idea what I'm doing, but it should work...
	GuiGameFrequency@ Frequency(const string& text, const string& configName, double min = 0.0, double max = 2.0, Alignment@ align = null, const string& tooltip = "") {
		if(align is null)
			@align = nextAlignment();
		GuiGameFrequency ele(cur, align, text, config(configName));
		ele.defaultValue = config::get(configName);
		ele.set(config::get(configName));
		ele.setMin(min);
		ele.setMax(max);
		if(tooltip.length != 0)
			setMarkupTooltip(ele, tooltip, width=300);
		options.insertLast(ele);
		return ele;
	}	

	void makeSettings() {
		color = colors::Orange;
		header = locale::NG_ADVANCED_OPTIONS;
		icon = Sprite(spritesheet::CardCategoryIcons, 5);

		Description(locale::NG_ADVANCED_OPTIONS_DESC, 4);
	
		Title(locale::NG_UNIVERSE_GENERATION);
		Occurance(locale::NG_PLANET_MOON_CHANCE, "PLANET_MOON_CHANCE", max = 0.5, tooltip=locale::NGTT_PLANET_MOON_CHANCE);
		Occurance(locale::NG_PLANET_CONDITION_CHANCE, "PLANET_CONDITION_CHANCE", max = 1.0, tooltip=locale::NGTT_PLANET_CONDITION_CHANCE);
		
		emptyline();
		Title(locale::NG_GAME_OPTIONS);
		Toggle(locale::NG_HIDE_EMPIRE_RELATIONS, "HIDE_EMPIRE_RELATIONS", halfWidth=true, tooltip=locale::NGTT_HIDE_EMPIRE_RELATIONS);
		Toggle(locale::NG_TEAMS_START_CLOSE, "TEAMS_START_CLOSE", halfWidth=true, tooltip=locale::NGTT_TEAMS_START_CLOSE);
		Toggle(locale::NG_FIRST_CONTACT, "FIRST_CONTACT", halfWidth=true, tooltip=locale::NGTT_FIRST_CONTACT);
		Number(locale::NG_CARD_STACK_INTERVAL, "CARD_STACK_DRAW_INTERVAL", step=15, min=15, max=360, tooltip=locale::NGTT_CARD_STACK_INTERVAL);
		Number(locale::NG_ENERGY_EFFICIENCY_STEP, "ENERGY_EFFICIENCY_STEP", step=25, min=100, max=5000, tooltip=locale::NGTT_ENERGY_EFFICIENCY_STEP);
		Number(locale::NG_ENERGY_PER_SEEDSHIP, "ENERGY_PER_SEEDSHIP", step=100, min=500, tooltip=locale::NGTT_ENERGY_PER_SEEDSHIP);
		Number(locale::NG_SIEGE_LOYALTY_TIME, "SIEGE_LOYALTY_TIME", step=15, min=30, tooltip=locale::NGTT_SIEGE_LOYALTY_TIME);
		Number(locale::NG_SIEGE_LOYALTY_COST, "SIEGE_LOYALTY_SUPPLY_COST", step=500, tooltip=locale::NGTT_SIEGE_LOYALTY_COST);
//		Number(locale::NG_SENSOR_MULT, "SENSOR_RANGE_MULT", tooltip=locale::NGTT_SENSOR_MULT, decimals=3, halfWidth=false, step=0.5);
//		Number(locale::NG_FTL_MULT, "FTL_MULT", tooltip=locale::NGTT_FTL_MULT, decimals=3, halfWidth=false, step=0.5);
//		Number(locale::NG_RANDOM_EVENT_INTERVAL, "RANDOM_EVENT_MIN_INTERVAL", min=30, step=30, tooltip=locale::NGTT_RANDOM_EVENT_INTERVAL);
		Number(locale::NG_FIRST_CONTACT_PRIZE, "INFLUENCE_CONTACT_BONUS", step=1, tooltip=locale::NGTT_FIRST_CONTACT_PRIZE);
		Number(locale::NG_LABOR_DUMP_TIME, "LABOR_STORAGE_DUMP_TIME", step=15, tooltip=locale::NGTT_LABOR_DUMP_TIME);
		Number(locale::NG_LEVEL_DECAY_TIME, "LEVEL_DECAY_TIMER", step=30, tooltip=locale::NGTT_LEVEL_DECAY_TIME);
		Occurance(locale::NG_RESEARCH_DECAY_MULT, "RESEARCH_EFFICIENCY_DECAY_MULT", max=10.0, tooltip=locale::NGTT_RESEARCH_DECAY_MULT);
		Frequency(locale::NG_DRYDOCK_BUILDCOST_FACTOR, "DRYDOCK_BUILDCOST_FACTOR", min=0.5, max=10.0, tooltip=locale::NGTT_DRYDOCK_BUILDCOST_FACTOR);
	}
};

class CrazyGamePage : GameSettingsPage {
	void makeSettings() {
		color = colors::Red;
		header = locale::NG_CRAZY_OPTIONS;
		icon = Sprite(material::SystemUnderAttack);

		Description(locale::NG_CRAZY_OPTIONS_DESC, 5);

		Title(locale::NG_UNIVERSE_GENERATION);
		Occurance(locale::NG_ASTEROID_PERMANENT_FREQ, "ASTEROID_PERMANENT_FREQ", max=5.0, tooltip=locale::NGTT_ASTEROID_PERMANENT_FREQ);
		Number(locale::NG_ASTEROID_MASS, "ASTEROID_MASS", step=500, tooltip=locale::NGTT_ASTEROID_MASS);
		Number(locale::NG_SYSTEMS_PER_WORMHOLE, "SYSTEMS_PER_WORMHOLE", min=5, step=5, tooltip=locale::NGTT_SYSTEMS_PER_WORMHOLE);
		Number(locale::NG_GALAXY_MIN_WORMHOLES, "GALAXY_MIN_WORMHOLES", max=15, step=1, tooltip=locale::NGTT_GALAXY_MIN_WORMHOLES);

		emptyline();
		Title(locale::NG_GAME_OPTIONS);
		Number(locale::NG_ARTIFACTS_SEEDSHIP_DEATH, "ARTIFACTS_SEEDSHIP_DEATH", max=30, step=1, tooltip=locale::NGTT_ARTIFACTS_SEEDSHIP_DEATH); 
		Occurance(locale::NG_ASTEROID_COST_STEP, "ASTEROID_COST_STEP", max=3.0, tooltip=locale::NGTT_ASTEROID_COST_STEP);
		Occurance(locale::NG_TERRAFORM_COST_STEP, "TERRAFORM_COST_STEP", max=3.0, tooltip=locale::NGTT_TERRAFORM_COST_STEP);
		Occurance(locale::NG_ORBITAL_LABOR_COST_STEP, "ORBITAL_LABOR_COST_STEP", max=3.0, tooltip=locale::NGTT_ORBITAL_LABOR_COST_STEP);
	}
};