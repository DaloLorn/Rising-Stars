import cargo;
import trait_effects;
import traits;
import generic_hooks;
import abilities;
import target_filters;

class MakeResourceVisible : TraitEffect {
    Document doc("Forces a secondary resource to be visible in the resource bar regardless of its default visibility.");
    Argument type(AT_Cargo, "Ore", doc="The resource type to reveal.");

#section server
    void postInit(Empire& emp, any@ data) const override {
        emp.forceCargoTypeVisible(type.integer);
    }
#section all
}

class AddGlobalCargo : BonusEffect {
    Document doc("Adds an amount of a particular secondary resource to the global pool.");
    Argument type(AT_Cargo, "Ore", doc="The resource type to add.");
    Argument amount(AT_Decimal, doc="Amount of resources to add.");

#section server
    void activate(Object@ obj, Empire@ emp) const override {
		if(emp is null)
			return;
		emp.addCargo(type.integer, amount.decimal);
	}
#section all
}

class TargetRequireCargo : TargetFilter {
	Document doc("Restricts target to asteroids containing secondary resources.");
	Argument objTarg(TT_Object);

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Must target a minable asteroid.";
	}

	bool isValidTarget(Object@ obj, Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		Object@ target = targ.obj;
		if(target is null)
			return false;
        Asteroid@ asteroid = cast<Asteroid>(target);
		return asteroid !is null && asteroid.cargoTypes > 0 && (asteroid.canDevelop(emp) || asteroid.origin is obj);
	}
};

class MiningData {
    double cargo = 0;
    uint cargoType = UINT_MAX;
    any data;
}

class MaintainMiningBase : AbilityHook {
    Document doc("Creates and maintains a mining base on an asteroid, harvesting secondary resources while the asteroid is in range and periodically sending it via freighter to a nearby planet. Only one mining base can be established on an asteroid, but miners can still mine it normally.");
    Argument objTarg(TT_Object);
    Argument threshold("Package Size", AT_Decimal, "250.0", doc="How much cargo each freighter will carry. If the freighter is destroyed, a percentage of this will be granted to the attacking empire.");
    Argument rate("Mining Rate", AT_Decimal, "2.0", doc="The maximum rate at which the asteroid can be mined while resources are available.");
    Argument min_rate("Minimum Mining Rate", AT_Decimal, "0.5", doc="How much of the resource will be mined if the asteroid has been depleted.");

	string getFailReason(const Ability@ abl, uint index, const Target@ targ) const override {
		return "Must target a minable asteroid.";
	}

    bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		Object@ obj = targ.obj;
		if(obj is null || abl.obj is null)
			return false;
        Asteroid@ asteroid = cast<Asteroid>(obj);
		return asteroid !is null && asteroid.cargoTypes > 0 && (asteroid.canDevelop(abl.obj.owner) || asteroid.origin is abl.obj);
	}

#section server
    void create(Ability@ abl, any@ data) const override {
        MiningData info;
        data.store(@info);
    }

    void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const override {
        if(abl.obj is null || abl.obj.owner is null || !abl.obj.owner.valid)
            return;
        MiningData@ info;
        data.retrieve(@info);

        Asteroid@ obj = cast<Asteroid>(oldTarget.obj);
        if(obj !is null) {
            obj.clearSetup();
        }

        @obj = cast<Asteroid>(newTarget.obj);
        if(obj !is null) {
            obj.setup(abl.obj, abl.obj.owner, 0);
            if(obj.cargoType[0] != info.cargoType) {
                info.cargo = 0;
                info.cargoType = obj.cargoType[0];
            }
        }

        data.store(@info);
    }

    void tick(Ability@ abl, any@ data, double time) const override {
        if(abl.obj is null)
            return;
        Target@ storeTarg = objTarg.fromTarget(abl.targets);
        if(storeTarg is null)
            return;
        
        Object@ target = storeTarg.obj;
        if(target is null)
            return;
        
        MiningData@ info;
        data.retrieve(@info);
        double consAmt = max(target.consumeCargo(info.cargoType, rate.decimal * time, true), min_rate.decimal * time);
        info.cargo += consAmt;
        if(info.cargo >= threshold.decimal) {
            info.cargo -= threshold.decimal;

            ObjectDesc freightDesc;
            freightDesc.type = OT_CargoShip;
            freightDesc.name = locale::CARGO_SHIP;
            freightDesc.radius = 4.0;
            freightDesc.delayedCreation = true;

            @freightDesc.owner = abl.obj.owner;
            freightDesc.position = abl.obj.position + random3d(abl.obj.radius + 4.5);

            CargoShip@ hauler = cast<CargoShip>(makeObject(freightDesc));
            hauler.CargoType = target.cargoType[0];
            hauler.Cargo = threshold.decimal;
            @hauler.Origin = abl.obj;
            hauler.rotation = quaterniond_fromVecToVec(vec3d_front(), hauler.position - abl.obj.position, vec3d_up());
            hauler.maxAcceleration = 2.5 * abl.obj.owner.ModSpeed.value * abl.obj.owner.ColonizerSpeed;
            hauler.Health *= abl.obj.owner.ModHP.value;
            hauler.finalizeCreation();
        }

        data.store(@info);
    }

    void save(Ability@ abl, any@ data, SaveFile& file) const override {
        MiningData@ info;
        data.retrieve(@info);
        file << info.cargo;
        file << info.cargoType;
    }

    void load(Ability@ abl, any@ data, SaveFile& file) const override {
        MiningData info;
        file >> info.cargo;
        file >> info.cargoType;
        data.store(@info);
    }
#section all
}