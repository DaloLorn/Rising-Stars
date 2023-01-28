import statuses;
import abilities;
import ability_effects;
import trait_effects;
import traits;
import hooks;
import bonus_effects;
import generic_effects;
import pickups;
import pickup_effects;
import status_effects;
import target_filters;
import requirement_effects;
import orbitals;
import resources;
import building_effects;
import buildings;
import generic_hooks;
import repeat_hooks;
import constructions;
from constructions import ConstructionHook;
#section server
import empire;
import influence_global;
import victory;
#section all

class IfAtWar : IfHook {
	Document doc("Only applies the inner hook if the empire owning the object is currently at war with another player empire.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	
	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}
	
#section server
	bool condition(Object& obj) const override {
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(!other.major || owner is other)
				continue;
			if(owner.isHostile(other))
				return true;
		}
		return false;
	}
#section all
}

class IfNotAtWar : IfHook {
	Document doc("Only applies the inner hook if the empire owning the object is not currently at war with another player empire.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	
	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}
	
#section server
	bool condition(Object& obj) const override {
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(!other.major || owner is other)
				continue;
			if(owner.isHostile(other))
				return false;
		}
		return true;
	}
#section all
}

class AllyRemnants : TraitEffect {
	Document doc("Empires with this trait cannot attack or be attacked by the Remnants.");

#section server
	void postInit(Empire& emp, any@ data) const override {
		Creeps.setHostile(emp, false);
		emp.setHostile(Creeps, false);
	}
#section all
}

class AllyPirates : TraitEffect {
	Document doc("Empires with this trait cannot attack or be attacked by the Dread Pirate.");

#section server
	void postInit(Empire& emp, any@ data) const override {
		Pirates.setHostile(emp, false);
		emp.setHostile(Pirates, false);
	}
#section all
}

class ConvertRemnants : AbilityHook {
	Document doc("Takes control of the target Remnant object. Also takes control of any support ships in the area.");
	Argument objTarg(TT_Object);

	string getFailReason(const Ability@ abl, uint index, const Target@ targ) const override {
		return "Must target Remnants.";
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(abl.emp is null)
			return false;
		return isCreepEmpire(targ.obj.owner);
	}

#section server	
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ targ = objTarg.fromConstTarget(targs).obj;
		if(targ is null)
			return;
		if(targ.owner !is Creeps)
			return;
		if(targ.hasLeaderAI) {
			targ.takeoverFleet(abl.emp, 1, false);
		}
		else
			@targ.owner = abl.emp;
	}
#section all
}

class CostFromSize : AbilityHook {
	Document doc("Modifies the energy cost of this ability by comparing the object's size to another, fixed size.");
	Argument targ(TT_Object);
	Argument size(AT_Decimal, "256.0", doc="The size the object is being compared to.");
	Argument factor(AT_Decimal, "1.0", doc="The factor by which the size ratio is multiplied.");
	Argument min_pct(AT_Decimal, "0", doc="The smallest ratio allowed. If the actual ratio is lower than this, this number is used instead.");
	Argument max_pct(AT_Decimal, "1000.0", doc="The highest ratio allowed. If the actual ratio exceeds this, this number is used instead.");

	void modEnergyCost(const Ability@ abl, const Targets@ targs, double& cost) const override {
		if(targs is null)
			return;
		const Target@ trigTarg = targ.fromConstTarget(targs);
		if(trigTarg is null || trigTarg.obj is null)
			return;

		double theirScale = sqr(trigTarg.obj.radius);
		if(trigTarg.obj.isShip)
			theirScale = cast<Ship>(trigTarg.obj).blueprint.design.size;

		double rat = theirScale / size.decimal;
		cost *= clamp(rat * factor.decimal, min_pct.decimal, max_pct.decimal);
	}
}

class StealResources : AbilityHook {
	Document doc("Steals all the native resources of a target planet and gives them to itself.");
	Argument objTarg(TT_Object);
	Argument takeUnstealables(AT_Boolean, "False", doc="Whether to take resources defined as unstealable.");
	Argument abortIfCannotTransfer(AT_Boolean, "True", doc="Whether to cancel the process if the resources cannot be transferred to the origin object, or continue and completely destroy the target's resources.");
	Argument turnToBarren(AT_Boolean, "True", doc="Whether to turn the planet into a barren planet once complete.");

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ targ = objTarg.fromConstTarget(targs).obj;
		if(targ is null || targ is abl.obj)
			return;
		if(!targ.hasResources)
			return;
		
		if(!(abl.obj !is null && abl.obj.hasResources) && abortIfCannotTransfer.boolean) {
			return;
		}
		else {
			int count = targ.nativeResourceCount;
			for(int i = count - 1; i >= 0; --i) { // We have to count from the last resource or risk causing trouble.
				const ResourceType@ type = getResource(targ.nativeResourceType[i]);
				if(type !is null && (type.stealable || takeUnstealables.boolean)) {
					if(abl.obj !is null && abl.obj.hasResources)
						abl.obj.createResource(type.id);
					targ.removeResource(i);
				}
			}
			if(targ.isPlanet && turnToBarren.boolean) {
				auto@ barren = getStatusType("Barren");
				if(barren !is null)
					targ.addStatus(barren.id);
				auto@ barrenType = getPlanetType("Barren");
				if(barrenType !is null)
					cast<Planet>(targ).PlanetType = barrenType.id;
			}
		}
	}
#section all
}

class MineCargoFromPlanet : AbilityHook {
	Document doc("Creates cargo from a target planet, dealing damage based on the amount of cargo mined.");
	Argument objTarg(TT_Object);
	Argument cargoType(AT_Cargo, doc="Type of cargo to mine.");
	Argument amount(AT_SysVar, doc="Maximum amount of cargo to mine per second.");
	Argument damageMult(AT_Decimal, "10000.0", doc="Amount of damage dealt per unit of cargo.");
//	Argument powerUse(AT_SysVar, "0", doc="Amount of Power to drain per second.");
	Argument quiet(AT_Boolean, "False", doc="Whether to destroy the planet 'quietly' or not.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		return abl.obj !is null && abl.obj.hasCargo;
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		return targ.obj.isPlanet;
	}

#section server
	void tick(Ability@ abl, any@ data, double time) const override {
		const CargoType@ type = getCargoType(cargoType.integer);
		if(type is null)
			return;
		if(abl.obj is null || !abl.obj.hasCargo)
			return;

		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return;

		Planet@ target = cast<Planet>(storeTarg.obj);
		if(target is null)
			return;

		double miningRate = min(amount.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time, (abl.obj.cargoCapacity - abl.obj.cargoStored) / type.storageSize);

		abl.obj.addCargo(cargoType.integer, miningRate);
		if(damageMult.decimal != 0) {
			if(target.Health <= miningRate * damageMult.decimal && quiet.boolean)
				target.destroyQuiet();
			else
				target.dealPlanetDamage(miningRate * damageMult.decimal);
		}
	}
#section all
}
		

class CannotOverrideProtection: PickupHook {
	Document doc("This pickup cannot be picked up if it is still protected, regardless of overrides such as those found in the Progenitor race. DEPRECATED.");
	Argument allow_same(AT_Boolean, "True", doc="Whether the pickup can still be picked up if it is owned by the empire trying to pick it up.");
	
#section server
	bool canPickup(Pickup& pickup, Object& obj) const override {
		return pickup.isPickupProtected || (allow_same.boolean && pickup.owner is obj.owner);
	}
#section all
}

class GenerateResearchInCombat : StatusHook {
	Document doc("Objects with this status generate research when in combat.");
	Argument amount(AT_Decimal, doc="How much research is generated each second.");
	
#section server
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		bool inCombat = false;
		data.retrieve(inCombat);
		if(inCombat)
			obj.owner.modResearchRate(-amount.decimal);
		data.store(false);
	}
	
	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		bool inCombat = false;
		data.retrieve(inCombat);
		
		if(inCombat && !obj.inCombat)
			obj.owner.modResearchRate(-amount.decimal);
		else if(!inCombat && obj.inCombat)
			obj.owner.modResearchRate(+amount.decimal);
		data.store(obj.inCombat);
		return true;
	}
	
	void save(Status@ status, any@ data, SaveFile& file) override {
		bool inCombat = false;
		data.retrieve(inCombat);

		file << inCombat;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		bool inCombat = false;
		
		file >> inCombat;
		data.store(inCombat);
	}
#section all
}

class IfStatusHook: StatusHook {
	GenericEffect@ hook;

	bool withHook(const string& str) {
		@hook = cast<GenericEffect>(parseHook(str, "planet_effects::"));
		if(hook is null) {
			error("If<>(): could not find inner hook: "+escape(str));
			return false;
		}
		return true;
	}

	bool condition(Object& obj, Status@ status) const {
		return false;
	}

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		IfData info;
		info.enabled = condition(obj, status);
		data.store(@info);

		if(info.enabled)
			hook.onCreate(obj, status, info.data);
	}

	void onDestroy(Object& obj, Status@ status, any@ data) override {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.onDestroy(obj, status, info.data);
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		IfData@ info;
		data.retrieve(@info);

		bool cond = condition(obj, status);
		if(cond != info.enabled) {
			if(info.enabled)
				hook.onDestroy(obj, status, info.data);
			else
				hook.onCreate(obj, status, info.data);
			info.enabled = cond;
		}
		if(info.enabled)
			hook.onTick(obj, status, info.data, time);
		data.store(@info);
		return true;
	}

	bool onOwnerChange(Object& obj, Status@ status, any@ data, Empire@ prevOwner, Empire@ newOwner) override {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.onOwnerChange(obj, status, info.data, prevOwner, newOwner);
		return true;
	}

	bool onRegionChange(Object& obj, Status@ status, any@ data, Region@ fromRegion, Region@ toRegion) override {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.onRegionChange(obj, status, info.data, fromRegion, toRegion);
		return true;
	}

	void save(Status@ status, any@ data, SaveFile& file) override {
		IfData@ info;
		data.retrieve(@info);

		file << info.enabled;
		if(info.enabled)
			hook.save(status, info.data, file);
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		IfData info;
		data.store(@info);

		file >> info.enabled;
		if(info.enabled)
			hook.load(status, info.data, file);
	}
#section all
};


class IfAlliedWithOriginEmpire : IfStatusHook {
	Document doc("Only apply the inner hook if the owner of this object is allied to the status' origin empire.");
	Argument hookID(AT_Hook);
	Argument allow_null(AT_Boolean, "True", doc="Whether the hook executes if the status has no origin empire.");
	Argument allow_self(AT_Boolean, "True", doc="Whether the hook executes if the object owner is the origin empire.");
	
	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return StatusHook::instantiate();
	}
	
#section server
	bool condition(Object& obj, Status@ status) const override {
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;
		Empire@ origin = status.originEmpire;
		if(origin is null)
			return allow_null.boolean;
		if(origin is owner)
			return allow_self.boolean;
		return (origin.ForcedPeaceMask & owner.mask != 0) && (owner.ForcedPeaceMask & origin.mask != 0); 
	}
#section all
}

class GivesTradeToOriginEmpire : StatusHook {
	Document doc("Objects with this status grant trade to the status' origin empire, as the GiveTrade() hook.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		Empire@ owner = status.originEmpire;
		Region@ region = obj.region;
		if(region !is null && owner !is null && owner.valid)
			region.grantTrade(owner);
	}

	void onDestroy(Object& obj, Status@ status, any@ data) override {
		Empire@ owner = status.originEmpire;
		Region@ region = obj.region;
		if(region !is null && owner !is null && owner.valid)
			region.revokeTrade(owner);
	}

	// No onOwnerChange is needed, since this keys to the origin instead.

	bool onRegionChange(Object& obj, Status@ status, any@ data, Region@ fromRegion, Region@ toRegion) override {
		Empire@ owner = status.originEmpire;
		if(owner !is null && owner.valid) {
			if(fromRegion !is null)
				fromRegion.revokeTrade(owner);
			if(toRegion !is null)
				toRegion.grantTrade(owner);
		}
		return true;
	}
#section all
}

class TargetFilterOwnedStatus : TargetFilter {
	Document doc("Restricts target to objects with a particular status applied by the caster's empire.");
	Argument objTarg(TT_Object);
	Argument status("Status", AT_Status, doc="Status to require.");

	string statusName = "DUMMY";

	bool instantiate() override {
		if(status.integer == -1) {
			error("Invalid argument: "+status.str);
			return false;
		}
		statusName = getStatusType(status.integer).name;
		return TargetFilter::instantiate();
	}

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Target must have had the '" + statusName + "' status applied by your empire.";
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasStatuses)
			return false;
		if(targ.obj.getStatusStackCount(status.integer, null, emp) > 0)
			return true;
		return false;
	}
};

class TargetFilterNotOwnedStatus : TargetFilter {
	Document doc("Restricts target to objects without a particular status applied by the caster's empire.");
	Argument objTarg(TT_Object);
	Argument status("Status", AT_Status, doc="Status to prohibit.");

	string statusName = "DUMMY";

	bool instantiate() override {
		if(status.integer == -1) {
			error("Invalid argument: "+status.str);
			return false;
		}
		statusName = getStatusType(status.integer).name;
		return TargetFilter::instantiate();
	}

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Target must not have had the '" + statusName + "' status applied by your empire.";
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasStatuses)
			return true;
		if(targ.obj.getStatusStackCount(status.integer, null, emp) > 0)
			return false;
		return true;
	}
};

class CorruptPlanet : StatusHook {
	Document doc("When applied to a planet, this status sets its origin object as the planet's shadowport.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		Empire@ owner = status.originEmpire;
		Planet@ planet = cast<Planet>(obj);
		if(planet !is null && owner !is null && owner.valid && status.originObject !is null && status.originObject.valid)
			planet.setShadowport(status.originObject);
	}

	void onDestroy(Object& obj, Status@ status, any@ data) override {
		Empire@ owner = status.originEmpire;
		Planet@ planet = cast<Planet>(obj);
		if(planet !is null && owner !is null && owner.valid && status.originObject !is null)
			planet.setShadowport(null);
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		Empire@ owner = status.originEmpire;
		Object@ origin = status.originObject;
		if(owner !is null && origin !is null && (!origin.valid || origin.owner !is owner))
			return false;
		return true;
	}
#section all
}

class ProtectPlanet : GenericEffect {
	Document doc("Planets affected by this status cannot be captured.");
	
#section server
	void disable(Object& obj, any@ data) const override {
		if(obj.hasSurfaceComponent)
			obj.clearProtectedFrom();
	}

	void tick(Object& obj, any@ data, double time) const override {
		uint mask = ~0;
		if(obj.hasSurfaceComponent)
			obj.protectFrom(mask);
	}
#section all
}

class TargetFilterNotRace : TargetFilter {
	Document doc("Only allow targets that have an empire that is of a particular race.");
	Argument targID(TT_Any);
	Argument trait(AT_Trait, doc="Trait to select for on human empires.");
	Argument name(AT_Locale, doc="Race name to require for AI empires.");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return format(locale::NTRG_REQUIRE, getTrait(trait.integer).name);
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(targID.integer))
			return true;
		Empire@ check;
		if(targ.type == TT_Empire) {
			@check = targ.emp;
		}
		else if(targ.type == TT_Object) {
			if(targ.obj is null)
				return false;
			@check = targ.obj.owner;
		}
		if(check is null)
			return false;
		if(check.isAI)
			return check.RaceName != name.str;
		else
			return !check.hasTrait(trait.integer);
	}
};

class TargetFilterRemnants : TargetFilter {
	Document doc("Only allow targets belonging to the Remnants.");
	Argument targID(TT_Object);
	
	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Must target Remnants.";
	}
	
	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(targID.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.owner is null)
			return false;
		else
			return isCreepEmpire(targ.obj.owner);
	}
};

class IfRace : IfHook {
	Document doc("Only apply the inner hook if the owner of this object is of a particular race.");
	Argument hookID(AT_Hook, "generic_effects::GenericEffect");
	Argument trait(AT_Trait, doc="Trait to search for on human empires.");
	Argument name(AT_Locale, doc="Race name to require for AI empires.");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}
	
#section server
	bool condition(Object& obj) const override {
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;
		if(owner.isAI)
			return owner.RaceName == name.str;
		else
			return owner.hasTrait(trait.integer);
	}
#section all
};

class IfInUnownedSpace : IfHook {
	Document doc("Only applies the inner hook if the current object is in an unowned system; in other words, a system where the player owns no planets.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	Argument allow_allies(AT_Boolean, "False", doc="Whether to count systems with allied planets as owned.");
	Argument allow_space(AT_Boolean, "True", doc="Whether to count interstellar space as an unowned system.");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		Region@ region = obj.region;
		if(region is null)
			return allow_space.boolean;
		if(allow_allies.boolean)
			return region.PlanetsMask & obj.owner.ForcedPeaceMask.value == 0;
		else
			return region.PlanetsMask & obj.owner.mask == 0;
	}
#section all
};

class EmpireOnEmpireAttributeGTE : EmpireEffect {
	BonusEffect@ hook;

	Document doc("Trigger a bonus effect when an empire attribute is at least the specified value. Designed for traits and other empire-wide effects.");
	Argument attribute(AT_EmpAttribute);
	Argument value(AT_Decimal);
	Argument function(AT_Hook, "bonus_effects::BonusEffect");

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(function.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("OnEnable(): could not find inner hook: "+escape(function.str));
			return false;
		}
		return GenericEffect::instantiate();
	}

#section server
	void tick(Empire& emp, any@ data, double time) const override {
		if(emp is null || !emp.valid)
			return;
		if(emp.getAttribute(attribute.integer) >= value.decimal)
			hook.activate(emp.HomeObj, emp);
	}
#section all
};

class EmpireOnEmpireAttributeLT : EmpireEffect {
	BonusEffect@ hook;

	Document doc("Trigger a bonus effect when an empire attribute is lower than the specified value. Designed for traits and other empire-wide effects.");
	Argument attribute(AT_EmpAttribute);
	Argument value(AT_Decimal);
	Argument function(AT_Hook, "bonus_effects::BonusEffect");

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(function.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("OnEnable(): could not find inner hook: "+escape(function.str));
			return false;
		}
		return GenericEffect::instantiate();
	}

#section server
	void tick(Empire& emp, any@ data, double time) const override {
		if(emp is null || !emp.valid)
			return;
		if(emp.getAttribute(attribute.integer) < value.decimal)
			hook.activate(emp.HomeObj, emp);
	}
#section all
};

class RequireNotUnlockTag : Requirement {
	Document doc("This requires the empire to not have a specific unlock tag.");
	Argument tag(AT_UnlockTag, doc="The unlock tag to check. Unlock tags can be named any arbitrary thing, and will be created as specified. Use the same tag value in the UnlockTag() or similar hook that should unlock it.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		Empire@ owner = obj.owner;
		if(owner is null || !owner.valid)
			return false;
		return !owner.isTagUnlocked(tag.integer);
	}
};

class RequireAttributeLT : Requirement {
	Document doc("This requires the empire's attribute to be less than a certain value.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to check.");
	Argument value(AT_Decimal, "1", doc="Value to test against.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		Empire@ owner = obj.owner;
		if(owner is null || !owner.valid)
			return false;
		return owner.getAttribute(attribute.integer) < value.decimal;
	}
};

class SelfDestructOnOwnerChange : BuildingHook {
	Document doc("When the planet containing this building is captured, the building will destroy itself.");
	Argument undevelop(AT_Boolean, "False", doc="Whether to undevelop the tiles the building is on.");

#section server
	void ownerChange(Object& obj, SurfaceBuilding@ bld, Empire@ prevOwner, Empire@ newOwner, any@ data) const override {
		if(obj.hasSurfaceComponent)
			obj.forceDestroyBuilding(vec2i(bld.position), undevelop.boolean);
	}
#section all
};

class TimeBasedRepeat : GenericRepeatHook {
	Document doc("Repeat a hook a certain amount of times, with a repeat count dependent on the game time.");
	Argument hookID("Hook", AT_Hook, "planet_effects::GenericEffect");
	Argument base(AT_Decimal, "0", doc="Base amount of repeats to perform.");
	Argument per_gametime_bonus(AT_Decimal, "-1", doc="Adds/removes repeats for every minute of game time. Accepts negative values, unlike RepeatExtended.");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	uint getRepeats(Object& obj, any@ data) const override {
		double cnt = base.decimal;
		cnt += per_gametime_bonus.decimal * (gameTime / 60.0);
		return max(cnt, 0.0);
	}

	uint getRepeats(Empire& emp, any@ data) const override {
		double cnt = base.decimal;
		cnt += per_gametime_bonus.decimal * (gameTime / 60.0);
		return max(cnt, 0.0);
	}
#section all
};

class TriggerOnGenerate : ResourceHook {
	Document doc("Executes a hook during planet generation as opposed to performing it when the resource is added to the planet. DISCLAIMER: This is a very dangerous hook if misused. Exercise extreme caution.");
	Argument hookID("Hook", AT_Hook, "planet_effects::GenericEffect");
	GenericEffect@ hook;

	bool withHook(const string& str) {
		@hook = cast<GenericEffect>(parseHook(str, "planet_effects::"));
		if(hook is null) {
			error("If<>(): could not find inner hook: "+escape(str));
			return false;
		}
		return true;
	}

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return ResourceHook::instantiate();
	}

#section server
	void onGenerate(Object& obj, Resource@ native, any@ data) const override {
		hook.enable(obj, data);
	}
#section all
};

class TriggerSelfPeriodic : AbilityHook {
	BonusEffect@ hook;

	Document doc("Trigger a bonus effect every set interval on the object casting the ability, so long as it's still being performed on the same target.");
	Argument objTarg(TT_Object, doc="The target being checked.");
	Argument function(AT_Hook, "bonus_effects::BonusEffect");
	Argument interval(AT_Decimal, "60", doc="Interval in seconds between triggers.");
	Argument max_triggers(AT_Integer, "-1", doc="Maximum amount of times to trigger the hook before stopping. -1 indicates no maximum triggers.");
	Argument trigger_immediate(AT_Boolean, "False", doc="Whether to first trigger the effect right away before starting the timer.");

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(function.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("TriggerSelfPeriodic(): could not find inner hook: "+escape(function.str));
			return false;
		}
		return AbilityHook::instantiate();
	}

#section server
	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if(index != uint(objTarg.integer))
			return;
		if(oldTarget.obj is newTarget.obj)
			return;

		PeriodicData@ dat;
		data.retrieve(@dat);

		if(dat !is null) {
			if(trigger_immediate.boolean)
				dat.timer = interval.decimal;
			else
				dat.timer = 0;
			dat.count = 0;
		}
	}

	void create(Ability@ abl, any@ data) const override {
		PeriodicData dat;
		data.store(@dat);

		if(trigger_immediate.boolean)
			dat.timer = interval.decimal;
		else
			dat.timer = 0;
		dat.count = 0;
	}

	void tick(Ability@ abl, any@ data, double time) const override {
		PeriodicData@ dat;
		data.retrieve(@dat);

		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(abl.obj is null || storeTarg is null || storeTarg.obj is null) {
			if(trigger_immediate.boolean)
				dat.timer = interval.decimal;
			else
				dat.timer = 0;
			dat.count = 0;
			return;
		}

		Object@ target = abl.obj;
		if(dat.timer >= interval.decimal) {
			if(max_triggers.integer < 0 || dat.count < uint(max_triggers.integer)) {
				if(hook !is null)
					hook.activate(target, target.owner);
				dat.count += 1;
			}
			dat.timer = 0.0;
		}
		else {
			dat.timer += time;
		}
	}

	void save(Ability@ abl, any@ data, SaveFile& file) const override {
		PeriodicData@ dat;
		data.retrieve(@dat);

		file << dat.timer;
		file << dat.count;
	}

	void load(Ability@ abl, any@ data, SaveFile& file) const override {
		PeriodicData dat;
		data.store(@dat);

		file >> dat.timer;
		if(file >= SV_0096)
			file >> dat.count;
	}
#section all
};

class TriggerTargetForCasterPeriodic : AbilityHook {
	BonusEffect@ hook;

	Document doc("Trigger a bonus effect every set interval on the target, performing it for the caster's empire.");
	Argument objTarg(TT_Object, doc="The target to trigger the effect on.");
	Argument function(AT_Hook, "bonus_effects::BonusEffect");
	Argument interval(AT_Decimal, "60", doc="Interval in seconds between triggers.");
	Argument max_triggers(AT_Integer, "-1", doc="Maximum amount of times to trigger the hook before stopping. -1 indicates no maximum triggers.");
	Argument trigger_immediate(AT_Boolean, "False", doc="Whether to first trigger the effect right away before starting the timer.");

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(function.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("TriggerTargetForCasterPeriodic(): could not find inner hook: "+escape(function.str));
			return false;
		}
		return AbilityHook::instantiate();
	}

#section server
	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if(index != uint(objTarg.integer))
			return;
		if(oldTarget.obj is newTarget.obj)
			return;

		PeriodicData@ dat;
		data.retrieve(@dat);

		if(dat !is null) {
			if(trigger_immediate.boolean)
				dat.timer = interval.decimal;
			else
				dat.timer = 0;
			dat.count = 0;
		}
	}

	void create(Ability@ abl, any@ data) const override {
		PeriodicData dat;
		data.store(@dat);

		if(trigger_immediate.boolean)
			dat.timer = interval.decimal;
		else
			dat.timer = 0;
		dat.count = 0;
	}

	void tick(Ability@ abl, any@ data, double time) const override {
		PeriodicData@ dat;
		data.retrieve(@dat);

		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(abl.obj.owner is null || storeTarg is null || storeTarg.obj is null) {
			if(trigger_immediate.boolean)
				dat.timer = interval.decimal;
			else
				dat.timer = 0;
			dat.count = 0;
			return;
		}

		Object@ target = storeTarg.obj;
		if(dat.timer >= interval.decimal) {
			if(max_triggers.integer < 0 || dat.count < uint(max_triggers.integer)) {
				if(hook !is null)
					hook.activate(target, abl.obj.owner);
				dat.count += 1;
			}
			dat.timer = 0.0;
		}
		else {
			dat.timer += time;
		}
	}

	void save(Ability@ abl, any@ data, SaveFile& file) const override {
		PeriodicData@ dat;
		data.retrieve(@dat);

		file << dat.timer;
		file << dat.count;
	}

	void load(Ability@ abl, any@ data, SaveFile& file) const override {
		PeriodicData dat;
		data.store(@dat);

		file >> dat.timer;
		if(file >= SV_0096)
			file >> dat.count;
	}
#section all
};

class NotifyEmpire : EmpireTrigger {
	Document doc("Notify the target empire of an event.");
	Argument title("Title", AT_Custom, doc="Title of the notification.");
	Argument desc("Description", AT_Custom, EMPTY_DEFAULT, doc="Description of the notification.");
	Argument icon("Icon", AT_Sprite, EMPTY_DEFAULT, doc="Sprite specifier for the notification icon.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(emp !is null && emp.major) {
			emp.notifyGeneric(title.str, desc.str, icon.str, emp, obj);
		}
	}
#section all
};

class NotifyOwner : EmpireTrigger {
	Document doc("Notify the owner of the target object of an event.");
	Argument use_owner("Use Owner", AT_Boolean, "False", doc="Whether to localize the notification using the object's owner or the empire it is being called from.");
	Argument title("Title", AT_Custom, doc="Title of the notification.");
	Argument desc("Description", AT_Custom, EMPTY_DEFAULT, doc="Description of the notification.");
	Argument icon("Icon", AT_Sprite, EMPTY_DEFAULT, doc="Sprite specifier for the notification icon.");
	

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(obj !is null) {
			if(obj.owner !is null && obj.owner.major) {
				if(!use_owner.boolean)
					obj.owner.notifyGeneric(title.str, desc.str, icon.str, emp, obj);
				else
					obj.owner.notifyGeneric(title.str, desc.str, icon.str, obj.owner, obj);
			}
		}
	}
#section all
};

class ConsumeDistanceFTLWithOverride : AbilityHook {
	Document doc("Ability consumes FTL based on the distance to the target, or a flat sum if a system flag is present.");
	Argument targ(TT_Object);
	Argument base_cost(AT_Decimal, "0", doc="Base FTL Cost.");
	Argument distance_cost(AT_Decimal, "0", doc="FTL Cost per unit of distance.");
	Argument sqrt_cost(AT_Decimal, "0", doc="FTL Cost per square root unit of distance.");
	Argument obey_free_ftl(AT_Boolean, "True", doc="Whether to reduce the cost to 0 if departing from a free-FTL system.");
	Argument obey_block_ftl(AT_Boolean, "True", doc="Whether to disable the ability if departing or arriving in an FTL-blocked system.");
	Argument path_distance(AT_Boolean, "False", doc="If set, use total path distance taking into account gates, slipstreams and wormholes.");
	Argument obey_suppress_ftl(AT_Boolean, "True", doc="Whether to disable the ability if departing or arriving in an FTL-suppressed system.");
	Argument flat_cost(AT_Decimal, "0", doc="FTL Cost if the system flag is present.");
	Argument flag(AT_SystemFlag, doc="System flag to check for.");
	Argument check_origin(AT_Boolean, "True", doc="Whether to check for the system flag in the origin system. If both this and Check Destination are disabled, the hook will act as ConsumeDistanceFTL.");
	Argument check_destination(AT_Boolean, "True", doc="Whether to check for the system flag in the origin system.");
	Argument allow_space(AT_Boolean, "False", doc="Whether to treat deep space as having the system flag.");

	double getCost(const Ability@ abl, const Targets@ targs) const{
		double cost = base_cost.decimal;
		auto@ t = targ.fromConstTarget(targs);
		if(t !is null && t.obj !is null && abl.obj !is null) {
			bool hasFlagOrigin = !check_origin.boolean;
			bool hasFlagDest = !check_destination.boolean;
			if(!hasFlagOrigin)
				hasFlagOrigin = (allow_space.boolean && abl.obj.region is null) || (abl.obj.region !is null && abl.obj.region.getSystemFlag(abl.obj.owner, flag.integer));
			if(!hasFlagDest)
				hasFlagDest = (allow_space.boolean && t.obj.region is null) || (t.obj.region !is null && t.obj.region.getSystemFlag(abl.obj.owner, flag.integer));

			if(hasFlagOrigin && hasFlagDest && (check_origin.boolean || check_destination.boolean)) 
				cost = flat_cost.decimal;
			else {
				double dist = t.obj.position.distanceTo(abl.obj.position);
				if(path_distance.boolean) {
#section server
					dist = getPathDistance(abl.emp, t.obj.position, abl.obj.position);
#section client
					dist = getPathDistance(t.obj.position, abl.obj.position);
#section all
				}
				cost += distance_cost.decimal * dist;
				cost += sqrt_cost.decimal * sqrt(dist);
			}
		}
		if(obey_free_ftl.boolean && abl.emp !is null && abl.obj !is null) {
			Region@ myReg = abl.obj.region;
			if(myReg !is null && myReg.FreeFTLMask & abl.emp.mask != 0)
				return 0.0;
		}
		return cost;
	}

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		if(ignoreCost || targs is null)
			return true;
		if((obey_block_ftl.boolean || obey_suppress_ftl.boolean) && abl.emp !is null) {
			int mask = 0;
			auto@ t = targ.fromConstTarget(targs);
			if(t !is null && t.obj !is null && abl.obj !is null) {
				Region@ myReg = abl.obj.region;
				if(obey_block_ftl.boolean)
					mask |= myReg.BlockFTLMask.value;
				if(obey_suppress_ftl.boolean)
					mask |= myReg.SuppressFTLMask.value;
				if(myReg !is null && mask & abl.emp.mask != 0)
					return false;
				mask = 0;
				Region@ targReg = t.obj.region;
				if(obey_block_ftl.boolean)
					mask |= targReg.BlockFTLMask.value;
				if(obey_suppress_ftl.boolean)
					mask |= targReg.SuppressFTLMask.value;
				if(targReg !is null && mask & abl.emp.mask != 0)
					return false;
			}
		}
		return abl.emp.FTLStored >= getCost(abl, targs);
	}

	bool formatCost(const Ability@ abl, const Targets@ targs, string& value) const override {
		if(targs is null)
			return false;
		value = format(locale::FTL_COST, toString(getCost(abl, targs), 0));
		return true;
	}

#section server
	bool consume(Ability@ abl, any@ data, const Targets@ targs) const override {
		double cost = getCost(abl, targs);
		if(cost == 0)
			return true;
		if(abl.emp.consumeFTL(cost, partial=false) == 0.0)
			return false;
		return true;
	}

	void reverse(Ability@ abl, any@ data, const Targets@ targs) const override {
		abl.emp.modFTLStored(getCost(abl, targs));
	}
#section all
}

class GiveRandomUnlock : EmpireTrigger {
	Document doc("Gives a random unlock to this empire's research grid.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(emp !is null)
			emp.grantRandomUnlock();
	}
#section all
};

class TriggerTargetAccumulated : AbilityHook {
	BonusEffect@ hook;

	Document doc("Trigger a bonus effect on the target after filling a progress counter.");
	Argument objTarg(TT_Object, doc="Target to trigger the effect on.");
	Argument function(AT_Hook, "bonus_effects::BonusEffect");
	Argument threshold(AT_Decimal, "180", doc="The amount of progress required to trigger the effect.");
	Argument accumulatorStat(AT_SysVar, "1", doc="How quickly the counter accumulates per second of game time.");
	Argument loyaltyModified(AT_Boolean, "True", doc="If the target is a planet, whether to slow accumulation based on the planet's loyalty.");
	Argument triggerAsCaster(AT_Boolean, "True", doc="Whether to trigger the effect as the caster's empire or the empire owning the target.");

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(function.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("TriggerTargetAccumulated(): could not find inner hook: "+escape(function.str));
			return false;
		}
		return AbilityHook::instantiate();
	}

#section server
	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if(index != uint(objTarg.integer))
			return;
		if(oldTarget.obj is newTarget.obj)
			return;

		data.store(0.0);
	}

	void create(Ability@ abl, any@ data) const override {
		data.store(0.0);
	}

	void tick(Ability@ abl, any@ data, double time) const override {
		double accumulator;
		data.retrieve(accumulator);

		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null || storeTarg.obj is null) {
			data.store(0.0);
			return;
		}

		if(accumulator == INFINITY)
			return;

		Object@ target = storeTarg.obj;
		Empire@ emp;
		if(triggerAsCaster.boolean)
			@emp = abl.obj.owner;
		else
			@emp = target.owner;

		if(accumulator >= threshold.decimal) {
			if(hook !is null)
				hook.activate(target, emp);
			accumulator = INFINITY;
		}
		else {
			double accumulated = time * accumulatorStat.fromSys(abl.subsystem, efficiencyObj=abl.obj);
			if(loyaltyModified.boolean && storeTarg.obj.hasSurfaceComponent) {
				accumulated /= double(storeTarg.obj.getLoyaltyFacing(abl.emp));
			}
			accumulator += accumulated;
		}

		data.store(accumulator);
	}

	void save(Ability@ abl, any@ data, SaveFile& file) const override {
		double accumulator = 0.0;
		data.retrieve(accumulator);

		file << accumulator;
	}

	void load(Ability@ abl, any@ data, SaveFile& file) const override {
		double accumulator = 0.0;
		file >> accumulator;
		data.store(accumulator);
	}
#section all
};

class ConsumeInfluencePerPopulation : ConstructionHook {
	Document doc("Requires a payment of influence to build this construction, dependent on the planet's population.");
	Argument cost("Amount", AT_Integer, doc="Influence cost per billion inhabitants. (Fractional populations are always rounded up. Non-planets are treated as having 1B population.)");

	bool canBuild(Object& obj, const ConstructionType@ cons, const Targets@ targs, bool ignoreCost) const override {
		if(ignoreCost)
			return true;
		if(!obj.hasSurfaceComponent)
			return obj.owner.Influence >= cost.integer;
		return obj.owner.Influence >= ceil(obj.population) * cost.integer;
	}

	bool formatCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, string& value) const override {
		int price = cost.integer;
		if(obj.hasSurfaceComponent)
			price *= ceil(obj.population);
		value = format(locale::RESOURCE_INFLUENCE, toString(price, 0));
		return true;
	}

	bool getCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, string& value, Sprite& icon) const override {
		int price = cost.integer;
		if(obj.hasSurfaceComponent)
			price *= ceil(obj.population);
		value = standardize(price, true);
		icon = icons::Influence;
		return true;
	}

	bool getVariable(Object& obj, const ConstructionType@ cons, Sprite& sprt, string& name, string& value, Color& color) const override {
		int price = cost.integer;
		if(obj.hasSurfaceComponent)
			price *= ceil(obj.population);
		value = standardize(price, true);
		sprt = icons::Influence;
		name = locale::RESOURCE_INFLUENCE + " " + locale::COST;
		color = colors::Influence;
		return true;
	}

#section server
	bool consume(Construction@ cons, any@ data, const Targets@ targs) const override { 
		int price = cost.integer;
		if(cons.obj.hasSurfaceComponent)
			price *= ceil(cons.obj.population);
		data.store(price);
		return cons.obj.owner.consumeInfluence(price);
	}

	void reverse(Construction@ cons, any@ data, const Targets@ targs, bool cancel) const override { 
		int price;
		data.retrieve(price);
		if(!cancel)
			cons.obj.owner.modInfluence(price);
	}
#section all
};

class AddBuildCostPopulation : ConstructionHook {
	Document doc("Add build cost based on the planet's population (rounding up fractions).");
	Argument multiply(AT_Decimal, "1", doc="Multiply population by this much. If not a planet, population is assumed to be 1B.");
	Argument multiply_sqrt(AT_Decimal, "0", doc="Add cost based on the square root of the population multiplied by this.");

	void getBuildCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, int& cost) const override {
		int value = 1;
		if(obj.hasSurfaceComponent)
			value = ceil(obj.population);
		cost += value * multiply.decimal;
		if(multiply_sqrt.decimal != 0)
			cost += sqrt(value) * multiply_sqrt.decimal;
	}
};

tidy final class TriggerWithOriginEmpireWhenRemoved : StatusHook {
	Document doc("When this status is removed, trigger the effect with the empire set to its origin empire.");
	Argument hookID(AT_Hook, "bonus_effects::BonusEffect", doc="Hook to call.");

	BonusEffect@ hook;

	bool instantiate() override {
		if(hookID.str != "bonus_effects::BonusEffect")
			@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::"));
		return StatusHook::instantiate();
	}

#section server
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		if(hook !is null)
			hook.activate(obj, status.originEmpire);
	}
#section all
};

class GiveToPirates : BonusEffect {
	Document doc("Transfers control of the object to the Dread Pirate.");

	void activate(Object@ obj, Empire@ emp) const override {
		if(obj is null)
			return;
		if(obj.isPlanet)
			obj.takeoverPlanet(Pirates, 0.5);
		else if(obj.isShip && obj.hasLeaderAI)
			obj.takeoverFleet(Pirates, 1.0, false);
		else
			@obj.owner = emp;
	}
}

class OnlyUsableIfPiratesExist : AbilityHook {
	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		return config::ENABLE_DREAD_PIRATE != 0 && Pirates.name == locale::PIRATES;
	}
}

class RequirePiratesExist : Requirement {
	Document doc("Requires that pirates exist in the game (i.e. they haven't been replaced by custom scenarios such as the Invasion map). Checks the Enable Dread Pirate option, and the name of the pirate empire.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		return config::ENABLE_DREAD_PIRATE != 0 && Pirates.name == locale::PIRATES;
	}

	string getFailError(Object& obj, bool ignoreState = false) const override {
		return "Cannot be used if there are no pirates in the game.";
	}
}

class MaintainFromOriginEmpire : StatusHook {
	Document doc("Deducts a maintenance fee from the status' origin empire. Only applies to ships for now.");
	Argument percentage(AT_Decimal, "0", doc="How much of the object's maintenance cost to remove.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		if(status.originEmpire is null)
			return;
		if(!obj.isShip)
			return;
		
		data.store(0);
		updateMaintenance(obj, status.originEmpire, data);
	}

	void onDestroy(Object& obj, Status@ status, any@ data) override {
		if(status.originEmpire is null)
			return;
		if(!obj.isShip)
			return;

		int currentMaintenance;
		data.retrieve(currentMaintenance);
		Ship@ ship = cast<Ship>(obj);
		uint moneyType = MoT_Ships;
		if(ship.blueprint.design.hasTag(ST_Station))
			moneyType = MoT_Orbitals;
		emp.modMaintenance(-currentMaintenance, moneyType);
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		if(status.originEmpire is null)
			return true;
		if(!obj.isShip)
			return true;

		updateMaintenance(obj, status.originEmpire, data);
		return true;
	}

	void updateMaintenance(Object& obj, Empire@ emp, any@ data) {
		int currentMaintenance;
		data.retrieve(currentMaintenance);
		Ship@ ship = cast<Ship>(obj);
		uint moneyType = MoT_Ships;
		if(ship.blueprint.design.hasTag(ST_Station))
			moneyType = MoT_Orbitals;
		if(!ship.isFree) {
			int maint = max(ship.blueprint.design.total(HV_MaintainCost), 0.0);
			maint -= double(maint) * (emp.MaxLogistics / double(emp.LogisticsThreshold)) * double(clamp(emp.getBuiltShips(ship) - 1, 0, emp.LogisticsThreshold));
			maint = int(max(double(maint), ship.blueprint.getEfficiencySum(SV_MinimumMaintenance)));
			if(maint != currentMaintenance) {
				emp.modMaintenance(maint - currentMaintenance, moneyType);
				data.store(maint);
			}
		}
	}
	
	void save(Status@ status, any@ data, SaveFile& file) override {
		int currentMaintenance;
		data.retrieve(currentMaintenance);
		file << currentMaintenance;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		int currentMaintenance;
		file >> currentMaintenance;
		data.store(currentMaintenance);
	}
#section all

}

class AddOwnedStatusSelf : AbilityHook {
	Document doc("Add a status to the target object.");
	Argument type(AT_Status, doc="Type of status effect to add.");
	Argument duration(AT_SysVar, "-1", doc="Duration to add the status for, -1 for permanent.");
	Argument duration_efficiency(AT_Boolean, "False", doc="Whether the duration added should be dependent on subsystem efficiency state. That is, a damaged subsystem will create a shorter duration status.");
	Argument set_origin_object(AT_Boolean, "False", doc="Whether to record the object triggering this hook into the origin object field of the resulting status. If not set, any hooks that refer to Origin Object cannot not apply. Status effects with different origin objects set do not collapse into stacks.");

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ target = abl.obj;
		if(target is null)
			return;
		if(!target.hasStatuses)
			return;

		Empire@ origEmp = abl.emp;
		Object@ origObj = null;
		if(set_origin_object.boolean)
			@origObj = abl.obj;

		Object@ effObj = null;
		if(duration_efficiency.boolean)
			@effObj = abl.obj;
		target.addStatus(uint(type.integer), duration.fromSys(abl.subsystem, efficiencyObj=effObj), originEmpire=origEmp, originObject=origObj);
	}
#section all
};