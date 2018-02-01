import buildings;
from buildings import IBuildingHook;
import resources;
import util.formatting;
import systems;
import saving;
import influence;
from influence import InfluenceStore;
from statuses import IStatusHook, Status, StatusInstance;
from resources import integerSum, decimalSum;
import orbitals;
from orbitals import IOrbitalEffect;
import attributes;
import hook_globals;
import research;
import empire_effects;
import repeat_hooks;
import planet_types;
#section server
import object_creation;
from components.ObjectManager import getDefenseDesign;
#section all

import generic_effects;
from generic_effects import GenericEffect;

class DisableSpacetimeDrag : GenericEffect {
	Document doc("Disables spacetime drag on the object.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.setSpacetimeDrag(false);
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.setSpacetimeDrag(true);
	}
#section all
};

class EnableRelativisticAcceleration : GenericEffect {
	Document doc("Enables relativistic acceleration for the object.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.setRelativisticAccel(true);
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.setRelativisticAccel(false);
	}
#section all
};