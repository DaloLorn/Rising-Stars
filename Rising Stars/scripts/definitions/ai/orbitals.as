import hooks;
import orbitals;

import ai.consider;

from traits import getTraitID;

interface AIOrbitals : ConsiderComponent {
	Empire@ get_empire();
	Considerer@ get_consider();

	bool isBuilding(const OrbitalModule& type);

	void registerUse(OrbitalUse use, const OrbitalModule& type);
};

enum OrbitalUse {
	OU_Shipyard,
	OU_EconomyCore,
	OU_TradeStation,
	OU_CommandPost
};

const array<string> OrbitalUseName = {
	"Shipyard",
	"EconomyCore",
	"TradeStation",
	"CommandPost"
};

class OrbitalAIHook : Hook, ConsiderHook {
	double consider(Considerer& cons, Object@ obj) const {
		return 0.0;
	}

	void register(AIOrbitals& orbitals, const OrbitalModule& type) const {
	}

	//Return a system or a planet to build this orbital in/around
	Object@ considerBuild(AIOrbitals& orbitals, const OrbitalModule& type) const {
		return null;
	}
	
	Object@ considerBuild(AIOrbitals& orbitals, const OrbitalModule& type, const ref@ param) const {
		return null;
	}
};

class RegisterForUse : OrbitalAIHook {
	Document doc("Register this orbital for a particular use. Only one orbital can be used for a specific specialized use.");
	Argument use(AT_Custom, doc="Specialized usage for this orbital.");

	void register(AIOrbitals& orbitals, const OrbitalModule& type) const override {
		Empire@ emp = orbitals.empire;

		for(uint i = 0, cnt = OrbitalUseName.length; i < cnt; ++i) {
			if(OrbitalUseName[i] == use.str) {
				if(use.str == "CommandPost") {
					//Evangelical lifestyle doesn't use command posts
					if (type.ident == "CommandPost" && emp.hasTrait(getTraitID("Evangelical")))
						continue;
					//Non Evangelical lifestyles don't use temples
					if (type.ident == "Temple" && !emp.hasTrait(getTraitID("Evangelical")))
						continue;
				}
				orbitals.registerUse(OrbitalUse(i), type);
				return;
			}
		}
	}
};

class RegisterForTradeUse : OrbitalAIHook {
	Document doc("This module is used in a specific way to create a trade route between territories. Only one orbital can be used for a specific specialized use.");
	Argument use(AT_Custom, doc="Specialized usage for this orbital.");
	
	void register(AIOrbitals& orbitals, const OrbitalModule& type) const override {
		Empire@ emp = orbitals.empire;

		for(uint i = 0, cnt = OrbitalUseName.length; i < cnt; ++i) {
			if(OrbitalUseName[i] == use.str) {
				orbitals.registerUse(OrbitalUse(i), type);
				return;
			}
		}
	}
	
	#section server
		double consider(Considerer& cons, Object@ obj) const override {
			return 1.0;
		}
	
		Object@ considerBuild(AIOrbitals& orbitals, const OrbitalModule& type, const ref@ param) const override {
			@orbitals.consider.component = orbitals;
			@orbitals.consider.module = type;
			
			const Territory@ territory = cast<Territory>(param);
			if (territory !is null)
				return orbitals.consider.SystemsInTerritory(this, territory);
			return null;
		}
	#section all
};
