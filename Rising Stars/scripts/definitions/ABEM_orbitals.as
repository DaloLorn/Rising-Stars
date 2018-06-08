import hooks;
import orbitals;
import generic_effects;
import generic_hooks;
import traits;
import statuses;
import status_effects;
from orbitals import OrbitalEffect;

#section server-side
from regions.regions import getRegion;
#section all

#section server
import object_creation;
#section all

class RequireSystemFlag : OrbitalEffect {
	Document doc("This orbital can only be constructed in a system containing a specific system flag.");
	Argument flag(AT_SystemFlag, doc="System flag to check for.");
	
	bool canBuildAt(Object@ obj, const vec3d& pos) const override {
		auto@ system = getRegion(pos);
		if(system is null)
			return false;
		if(obj is null)
			return false;
		return system.getSystemFlag(obj.owner, flag.integer);
	}

	string getBuildError(Object@ obj, const vec3d& pos) const override {
		return "You cannot build this orbital in that system.";
	}
	
#section server	
	void onOwnerChange(Orbital& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const override {
		Region@region = obj.region;
		if(newOwner !is null && newOwner.valid && (region is null || !region.getSystemFlag(newOwner, flag.integer))) {
			obj.destroy();
		}
	}
	
	void onRegionChange(Orbital& obj, any@ data, Region@ fromRegion, Region@ toRegion) const override {
		Empire@ owner = obj.owner;
		if(owner !is null && owner.valid) {
			if(toRegion is null || !fromRegion.getSystemFlag(obj.owner, flag.integer)) {
				obj.destroy();
			}
		}
	}
#section all
}

class LimitTwicePerSystem : OrbitalEffect {
	Document doc("This orbital can only be constructed twice per system.");
	Argument flag(AT_SystemFlag, doc="System flag to base the limit on. Can be set to any arbitrary unique name.");
	Argument flag2(AT_SystemFlag, doc="Second system flag to base the limit on. Can be set to any arbitrary unique name.");
	
	bool canBuildAt(Object@ obj, const vec3d& pos) const override {
		auto@ system = getRegion(pos);
		if(system is null)
			return false;
		if(obj is null)
			return false;
		if(system.getSystemFlag(obj.owner, flag.integer)) {
			return !system.getSystemFlag(obj.owner, flag2.integer);
		}
		return true;
	}

	string getBuildError(Object@ obj, const vec3d& pos) const override {
		return "You can only build this orbital twice per system.";
	}

#section server
	void onOwnerChange(Orbital& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const override {
		Region@region = obj.region;
		if(region !is null) {
			if(prevOwner !is null && prevOwner.valid) {
				if(region.getSystemFlag(prevOwner, flag2.integer)) {
					region.setSystemFlag(prevOwner, flag2.integer, false);
				}
				else {
					region.setSystemFlag(prevOwner, flag.integer, false);
				}
			}
			if(newOwner !is null && newOwner.valid) {
				if(region.getSystemFlag(newOwner, flag2.integer))
					obj.destroy();
				else {
					if(region.getSystemFlag(newOwner, flag.integer))
						region.setSystemFlag(newOwner, flag2.integer, true);
					else
						region.setSystemFlag(newOwner, flag.integer, true);
				}
			}
		}
	}
	
	void onRegionChange(Orbital& obj, any@ data, Region@ fromRegion, Region@ toRegion) const override {
		Empire@ owner = obj.owner;
		if(owner !is null && owner.valid) {
			if(fromRegion !is null) {
				if(fromRegion.getSystemFlag(owner, flag2.integer))
					fromRegion.setSystemFlag(owner, flag2.integer, false);
				else
					fromRegion.setSystemFlag(owner, flag.integer, false);
			}
			if(toRegion !is null) {
				if(toRegion.getSystemFlag(owner, flag2.integer))
					obj.destroy();
				else {
					if(toRegion.getSystemFlag(owner, flag.integer))
						toRegion.setSystemFlag(owner, flag2.integer, true);
					else
						toRegion.setSystemFlag(owner, flag.integer, true);
				}
			}
		}
	}
	
	void onEnable(Orbital& obj, any@ data) const override {
		Region@ region = obj.region;
		Empire@ owner = obj.owner;
		if(region !is null && owner !is null && owner.valid) {
			if(region.getSystemFlag(owner, flag2.integer))
				obj.destroy();
			else {
				if(region.getSystemFlag(owner, flag.integer))
					region.setSystemFlag(owner, flag2.integer, true);
				else
					region.setSystemFlag(owner, flag.integer, true);
			}	
		}
	}
	
	void onDisable(Orbital& obj, any@ data) const override {
		Region@ region = obj.region;
		Empire@ owner = obj.owner;
		if(region !is null && owner !is null && owner.valid) {
			if(region.getSystemFlag(owner, flag2.integer))
				region.setSystemFlag(owner, flag2.integer, false);
			else
				region.setSystemFlag(owner, flag.integer, false);
		}
	}
#section all
}

class ApplyToOwned : StatusHook {
	Document doc("When this status is added to an object, it only applies if the object is owned by the origin empire.");

#section server
	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		Empire@ origin = status.originEmpire;
		if(origin is null)
			return true;
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;

		return origin is owner;
	}
#section all
}

class ModifyOrbitalHealth : StatusHook {
	Document doc("Adds or removes a certain amount of health and armor to the orbital affected by this status.");
	Argument hpValue("Health", AT_Decimal, "10000", doc="Amount of health to add.");
	Argument armorValue("Armor", AT_Decimal, "5000", doc="Amount of armor to add. Armor is listed under health, but has a certain amount of damage resistance. Armor is damaged before health.");
	
#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		Orbital@ orb;
		if(obj.isOrbital)
			@orb = cast<Orbital>(obj);
		else return;
		orb.modMaxHealth(hpValue.decimal);
		orb.modMaxArmor(armorValue.decimal);
	}
	
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		Orbital@ orb;
		if(obj.isOrbital)
			@orb = cast<Orbital>(obj);
		else return;
		orb.modMaxHealth(-hpValue.decimal);
		orb.modMaxArmor(-armorValue.decimal);
	}
#section all
}

class ReplaceModule : GenericEffect {
	Document doc("Replaces all modules on the target orbital with modules of a different kind.");
	Argument old("Old Module", AT_OrbitalModule, doc="The module type to replace. Attempting to replace core modules will have no effect, unless it is a standalone core, in which case it can only be replaced by a core.");
	Argument new("New Module", AT_OrbitalModule, doc="The module type to replace it with. Attempting to replace a module with itself will have no effect.");
	Argument validate("Validate", AT_Boolean, "True", doc="Whether to check if the new module can be placed before attempting to install it.");
	Argument strict("Strict", AT_Boolean, "True", doc="Whether to use strict mode. Strict mode checks for *only* the specified module type without checking for subclasses. Disable strict mode only if you know what you're doing.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj is null || !obj.isOrbital || old.integer == new.integer)
			return;

		auto@ type = getOrbitalModule(old.integer);
		if(type is null || (type.isCore && !type.isStandalone)) {
			return;
		}
		
		Orbital@ orb = cast<Orbital>(obj);
		if(orb.hasModule(old.integer, strict.boolean)) {
			orb.replaceModule(old.integer, new.integer, validate.boolean, strict.boolean);
		}
	}
#section all
}

class DestroyModule : GenericEffect {
	Document doc("Destroys all modules of a specified class on the target orbital.");
	Argument old("Old Module", AT_OrbitalModule, doc="The module class to destroy. Destroying core modules will destroy the station itself.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj is null || !obj.isOrbital)
			return;

		auto@ type = getOrbitalModule(old.integer);
		if(type is null) {
			return;
		}
		
		Orbital@ orb = cast<Orbital>(obj);
		if(orb.coreModule == type.id)
			orb.destroy();
		else if(orb.hasModule(old.integer)) {
			array<OrbitalSection> sections;
			sections.syncFrom(orb.getSections());
			for(uint i = 0, cnt = sections.length; i < cnt; i++)
			if(type.isParentOf(sections[i].type))
				orb.destroyModule(sections[i].id);
		}
	}
#section all
}

class AddModule : GenericEffect {
	Document doc("Adds a module to the target orbital.");
	Argument module("Module", AT_OrbitalModule, doc="The module type to add. Attempting to add core modules - or add modules to standalone orbitals - will have no effect.");
	Argument validate("Validate", AT_Boolean, "True", doc="Whether to check if the new module can be placed before attempting to install it.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj is null || !obj.isOrbital)
			return;

		auto@ type = getOrbitalModule(module.integer);
		if(type is null || type.isCore) { // Block cores.
			return;
		}

		Orbital@ orb = cast<Orbital>(obj);
		if(!orb.isStandalone && (!validate.boolean || type.canBuildOn(orb))) { // If it's a standalone, block it regardless of validation. Otherwise, validate as needed.
			orb.addSection(module.integer);
		}
	}
#section all
}

class ReplaceModulesInEmpire : EmpireEffect {
	Document doc("Replaces all modules of a certain kind with modules of a different kind across all orbitals in the empire.");
	Argument old("Old Module", AT_OrbitalModule, doc="The module type to replace. Attempting to replace core modules will have no effect, unless it is a standalone core, in which case it can be replaced by a core.");
	Argument new("New Module", AT_OrbitalModule, doc="The module type to replace it with. Attempting to replace a module with itself will have no effect.");
	Argument validate("Validate", AT_Boolean, "True", doc="Whether to check if the new module can be placed before attempting to install it.");
	Argument strict("Strict", AT_Boolean, "True", doc="Whether to use strict mode. Strict mode checks for *only* the specified module type without checking for subclasses. Disable strict mode only if you know what you're doing.");

#section server
	void tick(Empire& emp, any@ data, double time) const override {
		if(emp is null || !emp.valid || old.integer == new.integer)
			return;

		auto@ type = getOrbitalModule(old.integer);
		if(type is null) {
			return;
		}
		
		for(uint i = 0, cnt = emp.orbitalCount; i < cnt; i++) {
			Orbital@ orb = emp.orbitals[i];
			if(orb.hasModule(old.integer, strict.boolean)) {
				orb.replaceModule(old.integer, new.integer, validate.boolean, strict.boolean);
			}
		}
	}
#section all
}

class DestroyModulesInEmpire : EmpireEffect {
	Document doc("Destroy all modules of a certain kind across all orbitals in the empire.");
	Argument old("Target Module", AT_OrbitalModule, doc="The module type to destroy. Destroying core modules will destroy the station itself.");

#section server
	void tick(Empire& emp, any@ data, double time) const override {
		if(emp is null || !emp.valid)
			return;

		auto@ type = getOrbitalModule(old.integer);
		if(type is null) {
			return;
		}
		
		for(uint i = 0, cnt = emp.orbitalCount; i < cnt; i++) {
			Orbital@ orb = emp.orbitals[i];
			if(orb.coreModule == type.id)
				orb.destroy();
			else if(orb.hasModule(old.integer)) {
				array<OrbitalSection> sections;
				sections.syncFrom(orb.getSections());
				for(uint j = 0, jcnt = sections.length; j < jcnt; j++)
					orb.destroyModule(sections[j].id);
			}
		}
	}
#section all
}

class IfHasModule : IfHook {
	Document doc("Only applies the inner hook if the orbital has a given module or one of its descendants.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	Argument module("Module", AT_OrbitalModule, doc="The module type to check for.");

	bool instantiate() override {
		if(!withHook(hookID.str)) 
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(obj is null) 
			return false;
		Orbital@ orb = cast<Orbital>(obj);
		if(orb is null)
			return false;

		return orb.hasModule(module.integer);
	}
#section all
}

class IfNotHaveModule : IfHook {
	Document doc("Only applies the inner hook if the orbital does not have a given module or one of its descendants.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	Argument module("Module", AT_OrbitalModule, doc="The module type to check for.");

	bool instantiate() override {
		if(!withHook(hookID.str)) 
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(obj is null) 
			return false;
		Orbital@ orb = cast<Orbital>(obj);
		if(orb is null)
			return true;

		return !orb.hasModule(module.integer);
	}
#section all
}

class AddSystemRepair : GenericEffect {
	Document doc("Adds a certain amount of repair strength to the system containing this object. All ships and orbitals in the system will repair the specified amount of health each second, up to a limit of 1% of their maximum health.");
	Argument repair(AT_Decimal, doc="How much HP should be repaired each second.");

#section server	
	void enable(Object& obj, any@ data) const override {
		if(obj is null || obj.owner is null || obj.region is null)
			return;
		obj.region.modRepairRate(obj.owner, repair.decimal);
	}

	void disable(Object& obj, any@ data) const override {
		if(obj is null || obj.owner is null || obj.region is null)
			return;
		obj.region.modRepairRate(obj.owner, -repair.decimal);
	}

	void ownerChange(Object& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const override {
		if(obj is null || obj.region is null)
			return;
		if(prevOwner !is null)
			obj.region.modRepairRate(prevOwner, -repair.decimal);
		if(newOwner !is null)
			obj.region.modRepairRate(newOwner, repair.decimal);
	}

	void regionChange(Object& obj, any@ data, Region@ fromRegion, Region@ toRegion) const override {
		if(obj is null || obj.owner is null)
			return;
		if(fromRegion !is null)
			fromRegion.modRepairRate(obj.owner, -repair.decimal);
		if(toRegion !is null)
			toRegion.modRepairRate(obj.owner, repair.decimal);
	}
#section all
}