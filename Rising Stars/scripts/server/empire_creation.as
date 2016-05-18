import settings.map_lib;
import settings.game_settings;
import empire_data;
import ftl;
import orbitals;
import object_creation;
import traits;
import maps;
from empire import Creeps, Pirates, majorEmpireCount, initEmpireDesigns;

#priority init 5000
void init() {
	if(isLoadedSave)
		return;

	//Modify settings based on maps
	for(uint i = 0, cnt = gameSettings.galaxies.length; i < cnt; ++i) {
		Map@ desc = getMap(gameSettings.galaxies[i].map_id);
		if(desc !is null)
			desc.modSettings(gameSettings);
	}

	//Generate the empires
	EmpirePortraitCreation portraits;
	uint empCnt = gameSettings.empires.length;
	majorEmpireCount = empCnt;
	for(uint i = 0; i < empCnt; ++i) {
		EmpireSettings@ settings = gameSettings.empires[i];

		//Create the empire
		Empire@ emp = Empire();
		emp.name = settings.name;
		emp.major = true;
		emp.team = settings.team;
		emp.handicap = settings.handicap;
		emp.effectorSkin = settings.effectorSkin;
		emp.ContactMask.value = emp.mask;
		emp.TradeMask.value = emp.mask;
		@emp.shipset = getShipset(settings.shipset);
		emp.RaceName = settings.raceName;
		if(emp.shipset is null || !emp.shipset.available)
			@emp.shipset = getShipset(DEFAULT_SHIPSET);

		//Check if we have a player
		if(settings.playerId != -1) {
			Player@ pl = getPlayer(settings.playerId);
			if(pl.emp is null && emp.player is null)
				pl.linkEmpire(emp);
		}

		//Create the portrait from settings data
		portraits.apply(settings, emp);

		//First empire created is the player
		if(playerEmpire is null)
			@playerEmpire = emp;

		//Add all the traits
		int points = settings.getTraitPoints();
		for(uint n = 0, ncnt = settings.traits.length; n < ncnt; ++n) {
			auto@ trait = settings.traits[n];

			//Skip traits with conflicts
			if(trait.hasConflicts(settings.traits))
				continue;

			//Skip traits if the points are invalid
			if(points < 0) {
				if(trait.cost > 0) {
					points += trait.cost;
					continue;
				}
			}

			emp.addTrait(trait.id);
		}
	}

	//Create game empires
	{
		@Creeps = Empire();
		Creeps.name = locale::REMNANTS;
		Creeps.color = Color(0xaaaaaaff);
		Creeps.major = false;
		Creeps.visionMask = ~0;

		auto@ flag = getEmpireFlag(randomi(0, getEmpireFlagCount()-1));
		Creeps.flagDef = flag.flagDef;
		Creeps.flagID = flag.id;
		@Creeps.flag = getMaterial(Creeps.flagDef);
		@Creeps.shipset = getShipset("Tyrant");

		@Pirates = Empire();
		Pirates.name = locale::PIRATES;
		Pirates.color = Color(0xff0000ff);
		Pirates.visionMask = ~0;
		Pirates.major = false;
		@flag = getEmpireFlag(randomi(0, getEmpireFlagCount()-1));
		Pirates.flagDef = flag.flagDef;
		Pirates.flagID = flag.id;
		@Pirates.flag = getMaterial(Creeps.flagDef);
		@Pirates.shipset = getShipset("Tyrant");

		//Everyone hates creeps and pirates
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(other !is Creeps) {
				Creeps.setHostile(other, true);
				other.setHostile(Creeps, true);
			}
			if(other !is Pirates) {
				Pirates.setHostile(other, true);
				other.setHostile(Pirates, true);
			}
		}

		auto@ hd = getSubsystemDef("Hyperdrive");
		for(uint i = 0, cnt = getSubsystemDefCount(); i < cnt; ++i) {
			auto@ def = getSubsystemDef(i);
			if(def !is hd)
				Creeps.setUnlocked(def, true);
			Pirates.setUnlocked(def, true);
			
			for(uint n = 0, ncnt = def.moduleCount; n < ncnt; ++n) {
				Creeps.setUnlocked(def, def.modules[n], true);
				Pirates.setUnlocked(def, def.modules[n], true);
			}
		}

		spectatorEmpire.ContactMask.value = int(~0);
		defaultEmpire.ContactMask.value = int(~0);
		Creeps.ContactMask.value = int(~0);
		Pirates.ContactMask.value = int(~0);
	}

	//Pre-initialize traits
	for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i)
		getEmpire(i).preInitTraits();

	// Apply First Contact Mode if necessary
	if(config::FIRST_CONTACT == 0) {
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ emp = getEmpire(i);
			if(emp.major) {
				for(uint j = 0; j < cnt; ++j) {
					Empire@ other = getEmpire(j);
					if(other.major)
						emp.ContactMask |= other.mask;
				}
			}
		}
	}

	//Initialize default designs into empires
	initEmpireDesigns();
}
