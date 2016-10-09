import hooks;
import orbitals;
import generic_effects;
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