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

class ConvertRemnants : AbilityHook {
	Document doc("Takes control of the target Remnant object. Also takes control of any support ships in the area.");
	Argument objTarg(TT_Object);

	string getFailReason(const Ability@ abl, uint index, const Target@ targ) const override {
		return "Must target Remnants.";
	}

#section server	
	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(abl.emp is null)
			return false;
		return targ.obj.owner is Creeps;
	}
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
	Document doc("Creates cargo from a target planet, dealing damage based on the amount of cargo mined and optionally draining Power.");
	Argument objTarg(TT_Object);
	Argument cargoType(AT_Cargo, doc="Type of cargo to mine.");
	Argument amount(AT_SysVar, doc="Maximum amount of cargo to mine per second.");
	Argument damageMult(AT_Decimal, "10000.0", doc="Amount of damage dealt per unit of cargo.");
	Argument powerUse(AT_SysVar, "0", doc="Amount of Power to drain per second.");
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
			
		Ship@ ship;
		double percent = 1;
		if(abl.obj.isShip)
		{
			@ship = cast<Ship>(abl.obj);
			percent = clamp(ship.Energy / (time * powerUse.fromSys(abl.subsystem, efficiencyObj=abl.obj)), 0, 1);
		}
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return;

		Planet@ target = cast<Planet>(storeTarg.obj);
		if(target is null)
			return;

		// Diminish the mined cargo by the percentage of the consumed power.
		if(abl.obj.isShip)
			ship.consumeEnergy(time * powerUse.fromSys(abl.subsystem, efficiencyObj=abl.obj));
		double miningRate = min(amount.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time * percent, (abl.obj.cargoCapacity - abl.obj.cargoStored) / type.storageSize);

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

class ProtectPlanet : GenericEffect {
	Document doc("Planets affected by this status cannot be captured.");
	
#section server
	void disable(Object& obj, any@ data) const override {
		if(obj.hasSurfaceComponent)
			obj.clearProtectedFrom();
	}

	void tick(Object& obj, any@ data, double time) const override {
		uint mask = ~0;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i)
			mask &= getEmpire(i).mask;
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
#section server
	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(targID.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.owner is null)
			return false;
		else
			return targ.obj.owner is Creeps;
	}
#section all
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
	void ownerChange(Object& obj, SurfaceBuilding@ bld, Empire@ prevOwner, Empire@ newOwner) const override {
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
		if(!withHook(arguments[0].str))
			return false;
		return ResourceHook::instantiate();
	}

#section server
	void onGenerate(Object& obj, Resource@ native) const override {
		hook.enable(obj, native.data[hookIndex]);
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
			emp.notifyGeneric(arguments[0].str, arguments[1].str, arguments[2].str, emp, obj);
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
					obj.owner.notifyGeneric(arguments[1].str, arguments[2].str, arguments[3].str, emp, obj);
				else
					obj.owner.notifyGeneric(arguments[1].str, arguments[2].str, arguments[3].str, obj.owner, obj);
			}
		}
	}
#section all
};