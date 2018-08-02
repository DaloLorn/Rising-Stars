import hooks;
import constructions;
import resources;

import ai.consider;

interface AIConstructions : ConsiderComponent {
	Empire@ get_empire();
	Considerer@ get_consider();

	bool isBuilding(Planet@ planet, const ConstructionType@ type);

	void registerUse(ConstructionUse use, const ConstructionType& type);
};

enum ConstructionUse {
	CU_MoonBase,
};

const array<string> ConstructionUseName = {
	"MoonBase",
};

class ConstructionAIHook : Hook, ConsiderHook {
	double consider(Considerer& cons, Object@ obj) const {
		return 0.0;
	}

	void register(AIConstructions& constructions, const ConstructionType& type) const {
	}

	//Return the planet to build this construction on
	Object@ considerBuild(AIConstructions& constructions, const ConstructionType& type) const {
		return null;
	}
};

class RegisterForUse : ConstructionAIHook {
	Document doc("Register this construction for a particular use. Only one construction can be used for a specific specialized use.");
	Argument use(AT_Custom, doc="Specialized usage for this construction.");

	void register(AIConstructions& constructions, const ConstructionType& type) const override {
		for(uint i = 0, cnt = ConstructionUseName.length; i < cnt; ++i) {
			if(ConstructionUseName[i] == use.str) {
				constructions.registerUse(ConstructionUse(i), type);
				return;
			}
		}
	}
};
