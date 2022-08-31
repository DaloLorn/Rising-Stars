import generic_effects;
import hooks;
import subsystem_effects;
import statuses;
import status_effects;
import ability_effects;
#section server
import ABEMCombat;
from map_effects import makeCreepCamp;
#section all
import systems;
import influence;
from influence import InfluenceCardEffect;
import anomalies;
import orbitals;
import artifacts;
import resources;
from anomalies import IAnomalyHook;
from abilities import IAbilityHook, Ability, AbilityHook;

#section server
from influence_global import getInfluenceEffectOwner, canDismissInfluenceEffect;
from regions.regions import getRegion, isOutsideUniverseExtents;
#section shadow
from influence_global import getInfluenceEffectOwner, canDismissInfluenceEffect;
from regions.regions import getRegion, isOutsideUniverseExtents;
#section all
import target_filters;

import hooks;
import abilities;
from abilities import AbilityHook;
from generic_effects import GenericEffect;
import bonus_effects;
from map_effects import MakePlanet, MakeStar;
import listed_values;
#section server
from objects.Artifact import createArtifact;
import bool getCheatsEverOn() from "cheats";
from game_start import generateNewSystem;
#section all

import statuses;
from statuses import StatusHook;
import planet_effects;
import tile_resources;
from bonus_effects import BonusEffect;

import ftl;
#section server
import empire;
#section all

#section server
void breakableHexesImpl(DamageEvent& evt, const vec2u& position) {
	auto@ bp = evt.blueprint;

	// Manually damage the hex, since the caller will undoubtedly
	// return DE_SkipHex, preventing the damage event from damaging this hex.
	bp.damage(evt.target, evt, position);

	HexStatus@ stat = bp.getHexStatus(position.x, position.y);
	if(int(stat.hp) < int(bp.design.variable(position, HV_BreakThreshold) * 255)) {
		stat.flags |= HF_NoRepair;
		if(stat.hp == 0) {
			stat.flags |= HF_Gone;
			bp.removedHP += bp.design.variable(position, HV_HP);
		}
	}
}
#section all

class BreakableHexes : SubsystemEffect {
	Document doc("The subsystem's hexes will no longer be repairable after they reach a certain threshold. NOTE: This hook is automatically applied to all subsystems already, and should not be used directly!");

#section server
	DamageEventStatus damage(SubsystemEvent& sysEvent, DamageEvent& evt, const vec2u& position) const override {
		// TODO for next save-breaking patch: Replace this hacky workaround with a special tag on Liquid and Ferrofluid armors.
		string ident = sysEvent.subsystem.type.id;
		if(ident.contains_nocase("LiquidArmor") || ident.contains_nocase("FerrofluidArmor"))
			return DE_Continue;

		breakableHexesImpl(evt, position);
		return DE_SkipHex;
	}
#section all
}

class DamagePassthrough : SubsystemEffect {
	Document doc("The subsystem will take full weapon damage, but will not reduce the damage passing through to other hexes, and will instead let it through as if it had not been damaged at all.");

#section server
	DamageEventStatus damage(SubsystemEvent& sysEvent, DamageEvent& evt, const vec2u& position) const override {
		// Remember the damage that came in.
		double dmg = evt.damage;

		// We need to return DE_SkipHex in order to send the damage event on its way.
		// However, doing so will prevent BreakableHexes from being called, so we need 
		// to emulate its behavior ourselves.
		breakableHexesImpl(evt, position);

		// Restore any damage that was spent on hurting us.
		evt.damage = dmg;

		return DE_SkipHex;
	}
}

class Regeneration : SubsystemEffect {
	Document doc("Regenerates itself over time.");
	Argument regen(AT_Decimal, doc="Amount of health to heal per second.");
	Argument spread(AT_Boolean, "False", doc="If false, regeneration amount is applied to each hex individually. Otherwise, it is spread evenly across all the hexes. (Surplus healing will then be divided equally across remaining damaged hexes until it is depleted or there are no damaged hexes left.)");

#section server
	void tick(SubsystemEvent& event, double time) const override {
		uint Hexes = event.subsystem.hexCount;
		uint i = 0;
		double amount = regen.decimal * time;
		double excess = 0, lastExcess;
		if(spread.boolean) {
			amount = amount / Hexes;
		}
		do {
			lastExcess = excess;
			for(i; i < Hexes; i++) {
				double surplus;
				surplus = event.blueprint.repair(event.obj, event.subsystem.hexagon(i), amount);

				if(spread.boolean) {
					excess += surplus;
				}
			}
			if(spread.boolean)
				amount = excess / Hexes;
		} while(excess > 0 && lastExcess != excess);
	}
#section all
};

class RegenerateAdjacentHexes : SubsystemEffect {
	Document doc("Hexes of this subsystem regenerate adjacent hexes over time.");
	Argument regen(AT_Decimal, doc="Amount of health to heal per second.");
	Argument spread(AT_Boolean, "False", doc="If false, regeneration amount is applied to each adjacent hex individually. Otherwise, it is spread evenly across all the hexes. (Surplus healing will then be divided equally across remaining damaged hexes until it is depleted or there are no damaged hexes left.)");
	Argument can_heal_self(AT_Boolean, "False", doc="If true, hexes of this subsystem that are adjacent to each other will heal each other. If not, they will be treated as empty.");
	Argument no_overflow(AT_Boolean, "True", doc="If true, any excess healing from a hex's adjacencies will be spread out among other adjacent hexes as necessary.");

#section server
	void tick(SubsystemEvent& event, double time) const override {
		uint Hexes = event.subsystem.hexCount;
		uint i = 0;
		double amount = regen.decimal * time;
		double excess = 0, lastExcess = 0;
		double hexExcess = 0, lastHexExcess = 0;
		if(spread.boolean) {
			amount = amount / Hexes;
		}

		do {
			// If spread is true, this is used to check if we're trying to repair 
			// a collection of hexes whose members are *all* at full health.
			// (i.e. `excess` has stopped changing.)
			lastExcess = excess;

			for(uint i = 0; i < Hexes; i++) {
				vec2u origin = event.subsystem.hexagon(i);
				vec2u[] adjacencies;
				for(uint d = 0; d < 6; d++) {
					vec2u other = origin;
					if(event.design.hull.active.advance(other, HexGridAdjacency(d))) {
						auto@ otherSys = event.design.subsystem(other);
						if(otherSys !is null) {
							if(otherSys is event.subsystem && !can_heal_self.boolean)
								continue;
							if(event.blueprint.getHexStatus(other.x, other.y).flags & HF_NoRepair != 0)
								continue;
							if(otherSys.type.hasTag(ST_Forcefield))
								continue; // Forcefields do not obey normal repair rules. TODO: Allow forcefield emitters to be repaired anyways!
							adjacencies.insertLast(other);
						}
					}
				}
				if(adjacencies.length < 1) {
					if(spread.boolean)
						excess += amount;
					continue;
				}

				double hexHeal = amount;
				if(spread.boolean) {
					hexHeal = hexHeal / adjacencies.length;
				}

				do {
					// Either we're remembering regeneration overflows from a previous hex,
					// or we've started a second regeneration pass on this one.
					// Either way, the data has been stored elsewhere and we need to
					// clear this space for fresh data.
					lastHexExcess = hexExcess;
					hexExcess = 0;

					for(int j = adjacencies.length-1; j >= 0; --j) {
						vec2u other = adjacencies[j];
						double surplus = event.blueprint.repair(event.obj, other, hexHeal);
						if(surplus > 0)
							hexExcess += surplus; // Store this for use by any acceptable overflow-spreading mechanisms.
						if(!no_overflow.boolean || surplus <= 0)
							adjacencies.removeLast();
					}
					if(adjacencies.length > 0)
						hexHeal = hexExcess / adjacencies.length;
					else break;
				} while(hexHeal > 0 && hexExcess != lastHexExcess);
				if(spread.boolean) {
					excess += hexExcess;
				}
			}
		} while(excess > 0 && excess != lastExcess);
	}
#section all
}

class AddThrustBonus : GenericEffect, TriggerableGeneric {
	Document doc("Add a bonus amount of thrust to the object. In case it is a planet, also allow the planet to move.");
	Argument amount(AT_Decimal, doc="Thrust amount to add.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.isPlanet) {
			Planet@ pl = cast<Planet>(obj);
			if(!pl.hasMover) {
				pl.activateMover();
				pl.maxAcceleration = 0;
			}
		}
		if(obj.hasMover)
			obj.modAccelerationBonus(+(amount.decimal / getMassFor(obj)));
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.modAccelerationBonus(-(amount.decimal / getMassFor(obj)));
	}
#section all
};

class ReactorOverloadHook : StatusHook {
	Document doc("Handles the power-boosted explosion of a ship. Do not try to use on anything that isn't a ship.");
	Argument powerdamage(AT_Decimal, "5", doc="Number by which the ship's power output is multiplied when calculating damage.");
	Argument powerradius(AT_Decimal, "2", doc="Number by which the ship's power output is multiplied when calculating the blast radius.");
	Argument basedamage(AT_Decimal, "0", doc="Base damage. Added to the result of the power-damage calculation.");
	Argument baseradius(AT_Decimal, "0", doc="Base radius. Added to the result of the power-radius calculation.");

#section server
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		ReactorOverload(obj, powerdamage.decimal, powerradius.decimal, basedamage.decimal, baseradius.decimal);
	}
#section all
};

class TargetRequireCommand : TargetFilter {
	Document doc("Restricts target to objects with a leader AI. (Flagships, certain orbitals and planets.)");
	Argument objTarg(TT_Object);

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Must target flagships, orbitals or planets.";
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		Object@ obj = targ.obj;
		if(obj is null)
			return false;
		return obj.hasLeaderAI;
	}
};

class TargetFilterStatus : TargetFilter {
	Document doc("Restricts target to objects with a particular status.");
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
		return "Target must have the '" + statusName + "' status.";
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasStatuses)
			return false;
		if(targ.obj.hasStatusEffect(status.integer))
			return true;
		return false;
	}
};

class TargetFilterStatuses : TargetFilter {
	Document doc("Restricts target to objects with one of two particular statuses.");
	Argument objTarg(TT_Object);
	Argument status("Status", AT_Status, doc="First status to require.");
	Argument status2("Status 2", AT_Status, doc="Second status to require.");
	Argument exclusive("Exclusive", AT_Boolean, "False", doc="What relationship the two statuses must be in for the target to be valid. True - Must be one OR the other, can't be both. False - At least one of the statuses must be present. Defaults to false.");
	string statusName = "DUMMY";
	string status2Name = "DUMMY";

	bool instantiate() override {
		if(status.integer == -1) {
			error("Invalid argument: "+status.str);
			return false;
		}
		else if(status.str == status2.str) {
			error("TargetFilterStatuses must have two different statuses: "+status.str+" "+status2.str);
			return false;
		}
		else if(status2.integer == -1) {
			error("Invalid argument: "+status2.str);
			return false;
		}
		else {
			statusName = getStatusType(status.integer).name;
			status2Name = getStatusType(status2.integer).name;
		}
		return TargetFilter::instantiate();
	}

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		if(exclusive.boolean) {
			return "Target must have the '" + statusName + "' status or the '" + status2Name + "' status, but it must not have both!";
		}
		else {
			return "Target must have either the '" + statusName + "' status or the '" + status2Name + "' status.";
		}
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasStatuses)
			return false;
		if(targ.obj.hasStatusEffect(status.integer)) {
			if(exclusive.boolean) {
				return !targ.obj.hasStatusEffect(status2.integer);
			}
			else {
				return true;
			}
		}
		else {
			return targ.obj.hasStatusEffect(status2.integer);
		}
	}
};

class TargetFilterNotType : TargetFilter {
	Document doc("Target must not be the type defined.");
	Argument objTarg(TT_Object);
	Argument type("Type", AT_Custom, "True", doc="Type of object.");
	int typeId = -1;

	bool instantiate() override {
		typeId = getObjectTypeId(type.str);
		if(typeId == -1) {
			error("Invalid object type: "+type.str);
			return false;
		}
		return TargetFilter::instantiate();
	}

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Cannot target " + localize("#OT_"+getObjectTypeName(typeId));
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		Object@ obj = targ.obj;
		if(obj is null)
			return false;
		return obj.type != typeId;
	}
};

class MaxStacks : StatusHook {
	Document doc("Cannot have more than # stacks.");
	Argument count("Maximum", AT_Integer, "10", doc="How many stacks of a status can exist on a given object. Defaults to 10.");

#section server
	void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
		if(status.stacks > count.integer) {
			status.remove(obj, instance);
		}
	}
#section all
};

class CombinedExpiration : StatusHook {
	Document doc("All stacks of the status expire simultaneously.");
	Argument duration("Duration", AT_Decimal, "10.0", doc="How long the status persists after its last application before expiring.");
	
#section server
	void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
		double timer = 0;
		data.store(timer);
	}
	
	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		double timer = 0;
		data.retrieve(timer);
		timer += time;
		data.store(timer);
		return timer < duration.decimal;
	}
	
	void save(Status@ status, any@ data, SaveFile& file) override {
		double timer = 0;
		data.retrieve(timer);

		file << timer;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		double timer = 0;
		
		file >> timer;
		data.store(timer);
	}
#section all
}
class DisplayStatus : StatusHook {
	Document doc("Displays a dummy status on the origin object, IF that object isn't also the object the status is on.");
	Argument statustype("Status", AT_Status, doc="Status to display.");

#section server
	void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
		if(obj !is status.originObject) {
			if(status.originObject.hasStatuses) {
				status.originObject.addStatus(getStatusID(statustype.str));
			}
		}
	}
#section all
};

/*class BoardingData {
	double boarders;
	double defenders;
	double originalboarders;
	double originaldefenders;
	any data;
};

class Boarders : StatusHook {
	Document doc("Calculates the boarding strength of the origin object from a subsystem value, and calculates the boarding strength of the target from the same subsystem value. After a certain amount of time, either the boarders are repelled or the target is captured.");
	Argument value("Subsystem Value", AT_Custom, doc="Subsystem value to calculate boarding strength from.");
	Argument defaultboarders("Default Boarder Strength", AT_Decimal, "200.0", doc="If the subsystem value can't be found or is zero on the origin object, this is how strong the boarders will be. Defaults to 200.");
	Argument defaultdefenders("Default Defender Strength", AT_Decimal, "100.0", doc="If the subsystem value can't be found or is zero on the target object, and the object has no crew, this is how strong the defenders will be. Defaults to 100.");

	#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		// Calculating boarder strength.
		double boarders = 0;
		Ship@ caster = cast<Ship>(status.originObject);
		if(caster !is null)
			boarders = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(value.str)), ST_Boarders, true);
		if(boarders <= 0)
			boarders = defaultboarders.decimal;
		
		// Calculating defender strength.
		double defenders = 0;
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null)
			defenders = ship.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(value.str)));
		if(defenders <= 0)
			defenders = defaultdefenders.decimal;
		// We want a planet to be 10 thousand times as hard to capture via 'boarding' as other objects.
		// This means you need quite a dedicated force to conquer a world like this, even if someone allowed planets to be targeted with this ability.
		if(obj.isPlanet)
			defenders *= 10000;

		BoardingData info;
		info.boarders = boarders;
		info.defenders = defenders;
		info.originalboarders = boarders;
		info.originaldefenders = defenders;
		data.store(@info);
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		BoardingData@ info;
		double boarders = 0;
		double defenders = 0;
		double originalboarders = 0;
		double originaldefenders = 0;
		double ratio = 0;
		data.retrieve(@info);
		boarders = info.boarders;
		defenders = info.defenders;
		originalboarders = info.originalboarders;
		originaldefenders = info.originaldefenders;
		
		ratio = boarders / defenders;
		// Basically, if there are 100 boarders and 100 defenders, 1 of each are lost per second. 
		// If there are 200 boarders, 0.5% of the boarders - incidentally, also 1 - are lost, but 2% of the defenders are lost.
		// This means that boarding operations will last a maximum of 100 seconds, though it will usually last less as one side will have an advantage over the other.
		// Hopefully, 100 seconds will give the boarded player enough time to respond, without allowing him to wait too long before acting. (And thus needlessly prolonging the battle.)
		// EDIT: No more than 10% of all troops can be lost by either side in the engagement, so a minimum battle length is 10 seconds.
		boarders -= min((originalboarders * 0.01) / ratio, originalboarders * 0.1) * time;
		defenders -= min((originaldefenders * 0.01) * ratio, originaldefenders * 0.1) * time;
		if(defenders <= 0) {
			@obj.owner = status.originEmpire;
			if(obj.hasStatuses) {
				if(obj.hasStatusEffect(getStatusID("DerelictShip")))
					obj.removeStatusType(getStatusID("DerelictShip"));
			}
			return false;
		}
		if(boarders <= 0)
			return false;
		info.boarders = boarders;
		info.defenders = defenders;
		data.store(@info);
		return true;
	}
	
	void save(Status@ status, any@ data, SaveFile& file) override {
		BoardingData@ info;
		data.retrieve(@info);

		if(info is null) {
			double nil = 0;
			file << nil;
			file << nil;
			file << nil;
			file << nil;
		}
		else {
			file << info.boarders;
			file << info.defenders;
			file << info.originalboarders;
			file << info.originaldefenders;
		}
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		BoardingData info;
		data.store(@info);

		file >> info.boarders;
		file >> info.defenders;
		file >> info.originalboarders;
		file >> info.originaldefenders;
	}
	#section all
};*/

class TransferSupplyFromSubsystem : AbilityHook {
	Document doc("Gives supplies to its target while draining its own supplies, with a rate determined by a subsystem value. If the caster is not a ship, the default transfer rate is used instead, and the supply rate is irrelevant.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the transfer. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the transfer rate is 1 unit of supply per unit of HyperdriveSpeed in such a case.");
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default transfer rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null && caster.Supply == 0)
			return false;
		return true;
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.isShip) {
			Ship@ target = cast<Ship>(targ.obj);
			return target.Supply < target.MaxSupply;
		}
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ targetShip = cast<Ship>(target);
		if(targetShip is null || targetShip.Supply == targetShip.MaxSupply)
			return;

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Supply == 0) 
			return;

		float resupply = targetShip.MaxSupply - targetShip.Supply; 
		float resupplyCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			resupplyCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			resupplyCap = preset.decimal * time; // The 'default' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(resupplyCap < resupply)
			resupply = resupplyCap;

		if(castedByShip && caster.Supply < resupply)
			resupply = caster.Supply;
		
		if(castedByShip)
			caster.consumeSupply(resupply);
		targetShip.refundSupply(resupply);
	}
#section all
};

class TransferShieldFromSubsystem : AbilityHook {
	Document doc("Gives shields to its target while draining its own shields, with a rate determined by a subsystem value. If the caster is not a ship, the default transfer rate is used instead, and the subsystem value is irrelevant.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the transfer. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the transfer rate is 1 shield HP per unit of HyperdriveSpeed in such a case.");
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default transfer rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null && caster.Shield == 0)
			return false;
		return true;
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.isShip) {
			Ship@ target = cast<Ship>(targ.obj);
			return target.Shield < target.MaxShield;
		}
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ targetShip = cast<Ship>(target);
		if(targetShip is null || targetShip.Shield == targetShip.MaxShield)
			return;

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Supply == 0) 
			return;

		float resupply = targetShip.MaxShield - targetShip.Shield; 
		float resupplyCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			resupplyCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			resupplyCap = preset.decimal * time; // The 'default' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(resupplyCap < resupply)
			resupply = resupplyCap;

		if(castedByShip && caster.Shield < resupply)
			resupply = caster.Shield;
		
		if(castedByShip)
			caster.Shield -= resupply;
		targetShip.Shield += resupply;
	}
#section all
};

class RechargeShields : GenericEffect {
	Document doc("Recharge the flagship's shields over time.");
	Argument base(AT_Decimal, doc="Base rate to recharge at per second.");
	Argument percent(AT_Decimal, "0", doc="Percentage of maximum shields to recharge per second.");
	Argument in_combat(AT_Boolean, "False", doc="Whether the recharge rate should apply in combat.");
	Argument fleet(AT_Boolean, "True", doc="Whether the recharge rate should apply to the rest of the fleet.");

#section server
	void tick(Object& obj, any@ data, double time) const override {
		if(!obj.hasLeaderAI)
			return;
		if(!in_combat.boolean && obj.inCombat)
			return;

		Ship@ ship = cast<Ship>(obj);
		Orbital@ orb = cast<Orbital>(obj);

		double rate = time * base.decimal;
		double maxShield = 0;
		if(ship !is null)
			maxShield = ship.MaxShield;
		else if(orb !is null) {
			maxShield = orb.maxShield;
			rate /= orb.shieldMod;
		}
			
		if(percent.decimal != 0)
			rate += time * percent.decimal * maxShield;
		
		if(ship !is null)
			ship.restoreShield(rate);
		else if(orb !is null)
			orb.repairOrbitalShield(rate);

		if(obj.supportCount > 0 && fleet.boolean) {
			Ship@ support;
			for(uint i = 0, count = obj.supportCount; i < count; ++i) {
				@support = cast<Ship>(obj.supportShip[i]);
				if(support !is null) {
					rate = time * base.decimal;
					if(percent.decimal != 0)
						rate += time * percent.decimal * support.MaxShield;
					support.restoreShield(rate);
				}
			}
		}
	}
#section all
};

class ApplyToShips : StatusHook {
	Document doc("When this status is added to a system, it only applies to ships.");
	
	bool shouldApply(Empire@ emp, Region@ region, Object@ obj) const override {
		return obj !is null && obj.isShip;
	}
};

class ApplyToShielded : StatusHook {
	Document doc("When this status is added to a system, it only applies to non-stellar objects capable of having shields - ships and orbitals.");

	bool shouldApply(Empire@ emp, Region@ region, Object@ obj) const override {
		return obj !is null && (obj.isShip || obj.isOrbital);
	}
};

class ApplyToLeaderAI : StatusHook {
	Document doc("When this status is added to a system, it only applies to objects capable of containing support ships - planets, ships and orbitals.");

	bool shouldApply(Empire@ emp, Region@ region, Object@ obj) const override {
		return obj !is null && obj.hasLeaderAI;
	}
};

class ApplyToStars : StatusHook {
	Document doc("When this status is added to a system, it only applies to stars.");
	
	bool shouldApply(Empire@emp, Region@ region, Object@ obj) const override {
		return obj !is null && obj.isStar;
	}
}

class AddOwnedStatus : AbilityHook {
	Document doc("Adds a status belonging to the specific object (and empire) activating the ability.");
	Argument objTarg(TT_Object);
	Argument status(AT_Custom, doc="Type of status effect to create.");
	Argument duration(AT_Decimal, "-1", doc="How long the status effect should last. If set to -1, the status effect acts as long as this effect hook does.");
	
	string getFailReason(const Ability@ abl, uint index, const Target@ targ) const override {
		return "Target must be capable of having statuses.";
	}
	
	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		return targ.obj.hasStatuses;
	}
	
#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ targ = objTarg.fromConstTarget(targs).obj;
		Empire@ dummyEmp = null;
		Region@ dummyReg = null;
		const StatusType@ type = getStatusType(status.str);
		if(targ !is null)
			targ.addStatus(duration.decimal, type.id, dummyEmp, dummyReg, abl.obj.owner, abl.obj);
	}
#section all
};

class UserMustNotHaveStatus : AbilityHook {
	Document doc("The object using this ability must not be under the effects of the specified status.");
	Argument status(AT_Custom, doc="Type of status effect to avoid.");
		
	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		if(abl.obj is null)
			return false;
		if(!abl.obj.hasStatuses) {
			return true;
		}
		else {
			const StatusType@ type = getStatusType(status.str);
			if(abl.obj.hasStatusEffect(type.id))
				return false;
		}
		return true;
	}
}

class DerelictData {
	double supply;
	double shield;
	any data;
}

class IsDerelict : StatusHook {
	Document doc("Marks the object as a derelict (or otherwise deactivated) ship. Derelicts have 0 maximum shields and 0 maximum supply - which is part of what makes them incapable of repairing or otherwise defending themselves in any way. Should never be done without setting the ship's owner to defaultEmpire beforehand.");
	Argument decay("Decay", AT_Boolean, "True", doc="If true, deals 1 damage per second as the ship is ravaged by time and the harsh, cold environment of space.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		Ship@ ship;
		Orbital@ orb;
		if(obj.isShip)
			@ship = cast<Ship>(obj);
		if(obj.isOrbital)
			@orb = cast<Orbital>(obj);
		DerelictData info;
		data.store(@info);
		if(obj is null || !obj.valid)
			return;
		if(ship !is null) {
			info.supply = ship.MaxSupply;
			ship.modSupplyBonus(-info.supply);
			info.shield = ship.MaxShield;
			ship.modBonusShield(-info.shield);
			ship.Supply = 0;
			ship.Shield = 0;
		}
		else if(orb !is null) {
			info.shield = orb.maxShield / orb.shieldMod;
			orb.modMaxShield(-info.shield);
			orb.setDerelict(true);
		}
		obj.engaged = true;
		obj.rotationSpeed = 0;
		obj.clearOrders();
	}
	
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		DerelictData@ info;
		data.retrieve(@info);
		if(obj is null || !obj.valid)
			return;
		if(obj.isShip) {
			Ship@ ship = cast<Ship>(obj);
			if(ship !is null) {
				ship.modSupplyBonus(info.supply);
				ship.modBonusShield(info.shield);
			}
		}
		if(obj.isOrbital) {
			Orbital@ orb = cast<Orbital>(obj);
			if(orb !is null) {
				orb.setDerelict(false);
				orb.modMaxShield(info.shield);
			}
		}
		obj.engaged = false;
		obj.rotationSpeed = 0.1;
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		DerelictData@ info;
		data.retrieve(@info);
		if(obj is null || !obj.valid)
			return false;
		if(obj.isShip) {
			Ship@ ship = cast<Ship>(obj);
			if(ship !is null) {
				if(ship.MaxSupply != 0)
					info.supply += ship.MaxSupply;
				if(ship.MaxShield != 0)
					info.shield += ship.MaxShield;
				ship.Supply = 0;
				ship.Shield = 0;
				ship.modSupplyBonus(-ship.MaxSupply);
				ship.modBonusShield(-ship.MaxShield);
			}
		}
		else if(obj.isOrbital) {
			Orbital@ orb = cast<Orbital>(obj);
			if(orb !is null) {
				if(orb.maxShield != 0)
					info.shield += orb.maxShield / orb.shieldMod;
				orb.modMaxShield(-orb.maxShield);
			}
		}				
		if(decay.boolean) {
			DamageEvent dmg;
			dmg.damage = 1.0 * time;
			dmg.partiality = time;
			dmg.impact = 0;
			@dmg.obj = null;
			@dmg.target = obj;
			obj.damage(dmg, -1.0, vec2d(randomi(-1, 1), randomi(-1, 1)));
		}
		obj.engaged = true;
		obj.rotationSpeed = 0;
		return true;
	}
	
	void save(Status@ status, any@ data, SaveFile& file) override {
		DerelictData@ info;
		data.retrieve(@info);

		if(info is null) {
			double nil = 0;
			file << nil;
			file << nil;
		}
		else {
			file << info.supply;
			file << info.shield;
		}
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		DerelictData info;
		data.store(@info);

		file >> info.supply;
		file >> info.shield;
	}
#section all
};

class DestroyTarget: AbilityHook {
	Document doc("Destroys the target object.");
	Argument objTarg(TT_Object);
	
#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ obj = objTarg.fromConstTarget(targs).obj;
		if(obj !is null && obj.valid)
			obj.destroy();
	}
#section all
};

// Dalo: Repurposing some old code of mine.
class Interdict : StatusHook {
	Document doc("An old, badly implemented bit of code. Consult Dalo Lorn before using this; it's unintuitive, rigid and all sorts of other bad stuff.");
	// Currently: 1 - Ship.
	Argument type("Type", AT_Integer, "1", doc="Type of object performing interdiction.");
	// The booleans are what they say on the tin.
	Argument hasinitialcost("Has Initial Cost", AT_Boolean, "True", doc="What it says on the tin.");
	Argument hasmaintenance("Has Maintenance", AT_Boolean, "True", doc="What it says on the tin.");
	// 1 - All, 2 - Non-Owner, 3 - Hostile.
	Argument friendlytype("Parameters", AT_Integer, "1", doc="What sort of interdiction the object is performing.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) {
		double maintenance = 0.0;
		bool failed = false;
		if(type.integer == 1) {
			Ship@ object = cast<Ship>(obj);
			if(hasinitialcost.boolean) {
			//	double initialCost = object.blueprint.getEfficiencySum(SV_InterdictInitCost);
				double initialCost = 0.0;
				if(initialCost > 0) {
					double consumed = obj.owner.consumeFTL(initialCost, false);
					if(consumed < initialCost) {
						obj.removeStatusType(status.type.id);
						failed = true;
						data.store(failed);
						return;
					}
				}
			}
			if(hasmaintenance.boolean) {
			//	maintenance = object.blueprint.design.total(SV_InterdictMaintenance);
				if(maintenance > 0) {
					obj.owner.modFTLUse(maintenance);
				}
			}
		}
	}
	
	void onDestroy(Object& obj, Status@ status, any@ data) {
		double maintenance = 0.0;
		bool failed = false;
		data.retrieve(failed);
		if(type.integer == 1) {
			Ship@ object = cast<Ship>(obj);
		//	maintenance = object.blueprint.design.total(SV_InterdictMaintenance);
		}
		if(maintenance > 0 && !failed) {
			obj.owner.modFTLUse(-maintenance);
		}
		if(obj.region !is null) {
			obj.region.BlockFTLMask = 0;
		}
	}
	
	void onObjectDestroy(Object& obj, Status@ status, any@ data) {
		double maintenance = 0.0;
		bool failed = false;
		data.retrieve(failed);
		if(type.integer == 1) {
			Ship@ object = cast<Ship>(obj);
		//	maintenance = object.blueprint.design.total(SV_InterdictMaintenance);
		}
		if(maintenance > 0 && !failed) {
			obj.owner.modFTLUse(-maintenance);
		}
		if(obj.region !is null) {
			obj.region.BlockFTLMask = 0;
		}
	}
	
	bool onTick(Object& obj, Status@ status, any@ data, double time) {
		bool failed = false;
		data.retrieve(failed);
		if(failed) {
			obj.removeStatusType(status.type.id);
			return false;
		}
		if(obj.owner.FTLShortage) {
			obj.removeStatusType(status.type.id);
		}

		if(obj.region !is null) {
			uint mask = ~0;
			if(friendlytype.integer == 2 && obj.owner !is null)
				mask &= ~obj.owner.mask;
			if(friendlytype.integer == 3 && obj.owner !is null) {
				mask &= obj.owner.hostileMask;
				mask &= ~obj.owner.mask;
			}
			obj.region.BlockFTLMask |= mask;
		}
		return true;
	}

	bool onRegionChange(Object& obj, Status@ status, any@ data, Region@ prevRegion, Region@ newRegion) {
		if(prevRegion !is null) {
			prevRegion.BlockFTLMask = 0;
		}
		return true;
	}
#section all
};

class TeleportTargetToSelf : AbilityHook {
	Document doc("Teleport the target to the casting object.");
	Argument objTarg(TT_Object);
	
#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ targ = objTarg.fromConstTarget(targs).obj;
		if(targ is null)
			return;
		
		vec3d point = abl.obj.position + vec3d(randomd(-100.0, 100.0), randomd(-100.0, 100.0), 0);
		if(targ.hasOrbit && targ.inOrbit) {
 			targ.stopOrbit();
 			targ.position = point;
 			targ.remakeStandardOrbit();
 		}
		else if(targ.hasLeaderAI) {
			targ.teleportTo(point);
		}
	}
#section all
};

class PlayParticlesAtObject : AbilityHook {
	Document doc("Play particles at the target object's location when activated.");
	Argument objTarg(TT_Object);
	Argument type(AT_Custom, doc="Which particle effect to play.");
	Argument scale(AT_Decimal, "1.0", doc="Scale of the particle effect.");
	Argument object_scale(AT_Boolean, "True", doc="Whether to scale the particle effect to the target's scale as well.");

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ targ = objTarg.fromConstTarget(targs).obj;
		if(targ is null)
			return;
		
		double size = scale.decimal;
		if(object_scale.boolean)
			size *= targ.radius;
		playParticleSystem(type.str, targ.position, quaterniond(), size);
	}
#section all
};

class TargetFilterNotRemnantOrPirate : TargetFilter {
	Document doc("Target must not be a Remnant or pirate-controlled object.");
	Argument objTarg(TT_Object);
	
	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Cannot target Remnants and pirates.";
	}
	
	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		Object@ obj = targ.obj;
		if(obj is null)
			return false;
		return !(isCreepEmpire(obj.owner) || isPirateEmpire(obj.owner));
	}
}

class HealFromSubsystem : AbilityHook {
	Document doc("Heals the target object (or fleet) at a rate determined by a subsystem value, while draining supplies (if applicable). If the caster does not have the subsystem, uses a default value.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the healing. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the healing rate is 1 HP per unit of HyperdriveSpeed in such a case.");
	Argument cost("Cost per HP", AT_Decimal, "2.0", doc="Amount of supplies drained per HP of repairs. Does not apply if the caster is not a ship. Defaults to 2.0. Is fully applied even if not all repairs are used in modes 1 and 2.");
	Argument powerCost("Power per HP", AT_Decimal, "2.0", doc="Amount of Power drained per HP of regeneration. Does not apply if the caster is not a ship. Defaults to 2.0. Is fully applied even if not all regeneration is used in modes 1 and 2."); // Doesn't work, we don't have Power yet.
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default healing rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");
	Argument mode("Mode", AT_Integer, "2", doc="How the healing behaves. Mode 0 heals only the target object, mode 1 heals each ship in the target fleet by the value, and mode 2 divides the healing evenly across every member of the target fleet. Defaults to mode 2, and uses mode 2 if an invalid mode is passed to the hook.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null || cost.decimal > caster.Supply /* We don't have Power. || powerCost.decimal > caster.Energy */)
			return false;
		return true;
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.isShip || targ.obj.isOrbital && mode.integer == 0)
			return true;
		if(targ.obj.hasLeaderAI || targ.obj.isOrbital)
			return true;
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Supply == 0) 
			return;

			
		float repair = 0;
		if(mode.integer == 0) {
			if(target.isShip)
				repair = cast<Ship>(target).blueprint.design.totalHP - cast<Ship>(target).blueprint.currentHP;
			else if(target.isOrbital)
				repair = (cast<Orbital>(target).maxHealth + cast<Orbital>(target).maxArmor) - (cast<Orbital>(target).health + cast<Orbital>(target).armor);
		}
		else if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0)
			repair = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		else
			repair = preset.decimal * time;
		float repairCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			repairCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			repairCap = preset.decimal * time; // The 'preset' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(repairCap < repair)
			repair = repairCap;

		if(castedByShip && caster.Supply < (repair * cost.decimal))
			repair = caster.Supply / cost.decimal;
/* We don't have Power yet.
		if(castedByShip && caster.Energy < (repair * powerCost.decimal))
			repair = caster.Energy / powerCost.decimal;
*/
		
		if(castedByShip) {
			caster.consumeSupply(repair * cost.decimal);
// We don't have Power yet.
//			caster.consumeEnergy(repair * powerCost.decimal);
		}
		if(mode.integer == 0){
			if(target.isShip)
				cast<Ship>(target).repairShip(repair);
			else if(target.isOrbital)
				cast<Orbital>(target).repairOrbital(repair);
		}
		else{
			if(mode.integer == 1){
				if(target.hasLeaderAI)
					target.repairFleet(repair, spread=false);
			}
			else{
				if(target.hasLeaderAI)
					target.repairFleet(repair, spread=true);
			}
		}
	}
#section all
};

class ABEMDealStellarDamageOverTime : AbilityHook {
	Document doc("Deal damage to the stored target stellar object over time. Damages things like stars and planets. This one correctly displays shield visuals if applicable.");
	Argument objTarg(TT_Object);
	Argument dmg_per_second(AT_SysVar, doc="Damage to deal per second.");
	Argument delay(AT_Decimal, "0.0", doc="How long to wait before starting to deal damage.");

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		data.store(0.0);
	}

	
	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const override {
		data.store(0.0);
	}

	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return;
		double timer;
		data.retrieve(timer);
		timer += time;
		data.store(timer);

		Object@ obj = storeTarg.obj;
		if(obj is null)
			return;
		if(timer < delay.decimal)
			return;

		const vec3d position = abl.obj.position;
		
		double amt = dmg_per_second.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		if(obj.isPlanet)
			cast<Planet>(obj).dealPlanetDamage(amt);
		else if(obj.isStar)
			cast<Star>(obj).dealStarDamage(amt, position);
	}

	void save(Ability@ abl, any@ data, SaveFile& file) const override {
		double timer;
		data.retrieve(timer);
		file << timer;
	}

	void load(Ability@ abl, any@ data, SaveFile& file) const override {
		double timer = 0;
		file >> timer;
		data.store(timer);
	}
#section all
};

class ShieldData {
	double bonus;
	bool castedBySubsystem;
	any data;
}

class AddStellarShield : StatusHook {
	Document doc("Adds shield capacity to the star or black hole affected by this status.");
	Argument value("Capacity Subsystem Value", AT_Custom, doc="Subsystem value to use if applicable.");
	Argument regenValue("Regeneration Subsystem Value", AT_Custom, doc="Subsystem value to use for shield regeneration if applicable.");
	Argument defaultShield("Default Capacity", AT_Decimal, "1000.0", doc="Used if the subsystem value specified for capacity does not exist or is zero on the origin object. Measured in millions. Defaults to 1000.0, or 1G shield capacity.");
	Argument holeMult("Black Hole Multiplier", AT_Decimal, "10.0", doc="How much the added shielding is multiplied for black holes. Defaults to 10.0 - the difference between a typical star and a black hole.");
	Argument defaultRegen("Default Regeneration", AT_Decimal, "1.0", doc="Used if the subsystem value specified for regeneration does not exist or is zero on the origin object. Measured in millions. Defaults to 1.0, or 1M shields per second.");
	Argument startOn("Start On", AT_Boolean, "false", doc="Whether the shield should start at maximum capacity. Defaults to false (starts with no shields).");
	
#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		// Calculating shield power.
		double bonus = 0;
		bool castedBySubsystem = true;
		Star@ star = cast<Star>(obj);
		if(star is null)
			return;
		Ship@ caster = cast<Ship>(status.originObject);
		if(caster !is null)
			bonus = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(value.str)));
		if(bonus <= 0)
			castedBySubsystem = false;
			bonus = defaultShield.decimal * 1000000; // 1M
		if(star.temperature == 0)
			bonus *= holeMult.decimal;
		
		star.MaxShield += bonus;
		if(startOn.boolean)
			star.Shield += bonus;
		ShieldData info;
		info.bonus = bonus;
		info.castedBySubsystem = castedBySubsystem;
		data.store(@info);
	}
	
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		Star@ star = cast<Star>(obj);
		if(star is null)
			return;
		double bonus = 0;
		ShieldData@ info;
		data.retrieve(@info);
		bonus = info.bonus;
		star.MaxShield -= bonus;
		if(star.MaxShield < star.Shield)
			star.Shield = star.MaxShield;
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		Star@ star = cast<Star>(obj);
		if(star is null)
			return false;
		ShieldData@ info;
		double bonus = 0;
		bool castedBySubsystem = false;
		double regen = 0;
		data.retrieve(@info);
		bonus = info.bonus;
		castedBySubsystem = info.castedBySubsystem;
		
		if(castedBySubsystem) {
			Ship@ caster = cast<Ship>(status.originObject);
			if(caster is null)
				return false;
			else {
				double newBonus = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(value.str)));
				if(bonus != newBonus) {
					star.MaxShield -= newBonus - bonus;
					bonus = newBonus;
				}
				regen = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(regenValue.str))) * time;
			}
		}
		else {
			regen = defaultRegen.decimal * 1000000 * time;
		}
		star.Shield = min(star.Shield + regen, star.MaxShield);
		info.bonus = bonus;
		info.castedBySubsystem = castedBySubsystem;
		data.store(@info);
		return true;
	}
	
	void save(Status@ status, any@ data, SaveFile& file) override {
		ShieldData@ info;
		data.retrieve(@info);

		file << info.bonus;
		file << info.castedBySubsystem;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		ShieldData info;
		data.store(@info);

		file >> info.bonus;
		file >> info.castedBySubsystem;
	}
#section all
}

class AddShieldCapacity : StatusHook {
	Document doc("Temporarily adds a certain amount of shield capacity to the ship or orbital affected by this status.");
	Argument value("Capacity Subsystem Value", AT_Custom, doc="The subsystem value to use when calculating the added shield capacity.");
	Argument preset("Default Capacity", AT_Decimal, "500.0", doc="The default amount of shield capacity to add if the subsystem value cannot be found or is zero. Defaults to 500.0.");
	Argument startOn("Start On", AT_Boolean, "true", doc="Whether to add additional shield HP equivalent to the added capacity. Defaults to true.");
		
#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		// Calculating shield power.
		double bonus = 0;
		bool castedBySubsystem = true;
		Ship@ ship;
		Orbital@ orb;

		if(obj.isShip)
			@ship = cast<Ship>(obj);
		else if(obj.isOrbital)
			@orb = cast<Orbital>(obj);
		if(ship is null && orb is null)
			return;
		Ship@ caster = cast<Ship>(status.originObject);
		if(caster !is null)
			bonus = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(value.str)));
		if(bonus <= 0)
			castedBySubsystem = false;
			bonus = preset.decimal;
		
		if(obj.isShip) {
			ship.modBonusShield(bonus);
			if(startOn.boolean)
				ship.Shield += bonus;
		}
		else if(obj.isOrbital) {
			orb.modMaxShield(bonus);
			if(startOn.boolean)
				orb.repairOrbitalShield(bonus);
		}
		ShieldData info;
		info.bonus = bonus;
		info.castedBySubsystem = castedBySubsystem;
		data.store(@info);
	}
	
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		double bonus = 0;
		ShieldData@ info;
		data.retrieve(@info);
		bonus = info.bonus;
		if(obj.isShip) {
			Ship@ ship = cast<Ship>(obj);
			ship.modBonusShield(-bonus);
			if(ship.MaxShield < ship.Shield)
				ship.Shield = ship.MaxShield;
		}
		else if(obj.isOrbital) {
			Orbital@ orb = cast<Orbital>(obj);
			orb.modMaxShield(-bonus);
		}
	}
	
	void save(Status@ status, any@ data, SaveFile& file) override {
		ShieldData@ info;
		data.retrieve(@info);

		file << info.bonus;
		file << info.castedBySubsystem;
	}

	void load(Status@ status, any@ data, SaveFile& file) override {
		ShieldData info;
		data.store(@info);

		file >> info.bonus;
		file >> info.castedBySubsystem;
	}
#section all	
}

class AddSizeScaledShield : StatusHook {
	Document doc("Adds a certain amount of shield capacity and regeneration to the orbital affected by this status, based on its radius.");
	Argument capacity("Capacity Multiplier", AT_Decimal, "500.0", doc="The amount of capacity to multiply the radius with. Defaults to 500.");
	Argument regeneration("Regeneration Multiplier", AT_Decimal, "500.0", doc="The amount of regeneration to multiply the regeneration with. Defaults to 2.5.");
	Argument startOn("Start On", AT_Boolean, "False", doc="Whether to add additional shield HP equivalent to the added capacity. Defaults to false.");
		
#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		if(obj.isOrbital) {
			Orbital@ orb = cast<Orbital>(obj);
			orb.modMaxShield(capacity.decimal * orb.radius);
			if(startOn.boolean)
				orb.repairOrbitalShield(capacity.decimal * orb.radius);
			orb.modShieldRegen(regeneration.decimal * orb.radius);
		}
	}
	
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		if(obj.isOrbital) {
			Orbital@ orb = cast<Orbital>(obj);
			orb.modMaxShield(-capacity.decimal * orb.radius);
			orb.modShieldRegen(-regeneration.decimal * orb.radius);
		}
	}
#section all	
}

class HealShieldFromSubsystem : AbilityHook {
	Document doc("Heals the target object's (or fleet's) shields at a rate determined by a subsystem value, while draining supplies (if applicable). If the caster does not have the subsystem, uses a default value.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the healing. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the healing rate is 1 HP per unit of HyperdriveSpeed in such a case.");
	Argument cost("Cost per HP", AT_Decimal, "2.0", doc="Amount of supplies drained per HP of regeneration. Does not apply if the caster is not a ship. Defaults to 2.0. Is fully applied even if not all regeneration is used in modes 1 and 2.");
	Argument powerCost("Power per HP", AT_Decimal, "2.0", doc="Amount of Power drained per HP of regeneration. Does not apply if the caster is not a ship. Defaults to 2.0. Is fully applied even if not all regeneration is used in modes 1 and 2."); // Doesn't work, we don't have Power yet.
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default healing rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");
	Argument mode("Mode", AT_Integer, "2", doc="How the healing behaves. Mode 0 heals only the target object, mode 1 heals each ship in the target fleet by the value, and mode 2 divides the healing evenly across every member of the target fleet with shield capacity. Defaults to mode 2, and uses mode 2 if an invalid mode is passed to the hook.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null || cost.decimal > caster.Supply /* We don't have Power yet. || powerCost.decimal > caster.Energy */)
			return false;
		return true;
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if((targ.obj.isShip || targ.obj.isOrbital) && mode.integer == 0)
			return true;
		if(targ.obj.hasLeaderAI && (targ.obj.supportCount > 0 || targ.obj.isShip || targ.obj.isOrbital))
			return true;
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Supply == 0) 
			return;

			
		float repair = 0;
		if(mode.integer == 0) {
			if(target.isShip)
				repair = cast<Ship>(target).MaxShield - cast<Ship>(target).Shield;
		}
		else if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0)
			repair = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		else
			repair = preset.decimal * time;
		float repairCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			repairCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			repairCap = preset.decimal * time; // The 'preset' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(repairCap < repair)
			repair = repairCap;

		if(castedByShip && caster.Supply < (repair * cost.decimal))
			repair = caster.Supply / cost.decimal;
/* We don't have Power yet.
		if(castedByShip && caster.Energy < (repair * powerCost.decimal))
			repair = caster.Energy / powerCost.decimal;
*/
		
		if(castedByShip) {
			caster.consumeSupply(repair * cost.decimal);
// We don't have Power yet.
//			caster.consumeEnergy(repair * powerCost.decimal);
		}
		if(mode.integer == 0){
			if(target.isShip)
				cast<Ship>(target).Shield += repair;
/* We don't have Power yet.
			else if(target.isOrbital)
				cast<Orbital>(target).repairOrbitalShield(repair / cast<Orbital>(target).shieldMod);
*/
		}
		else{
			if(target.supportCount > 0) {
				Ship@ support;
				int shieldlessCount = 0;
				if(mode.integer != 1) {
					for(uint i = 0, count = target.supportCount; i < count; ++i) {
						@support = cast<Ship>(target.supportShip[i]);
						if(support !is null) {
							if(support.MaxShield <= 0)
								++shieldlessCount;
						}
					}
				}
				for(uint i = 0, count = target.supportCount; i < count; ++i) {
					@support = cast<Ship>(target.supportShip[i]);
					if(support !is null) {
						if(mode.integer != 1)
							support.Shield += repair / (count + 1 - shieldlessCount);
						else 
							support.Shield += repair;
						if(support.Shield > support.MaxShield) {
							support.Shield = support.MaxShield;
						}
					}
				}
				if(mode.integer != 1)
					repair /= target.supportCount + 1 - shieldlessCount;
			}
			if(target.isShip)
				cast<Ship>(target).Shield = min(cast<Ship>(target).Shield + repair, cast<Ship>(target).MaxShield);
			else if(target.isOrbital)
				cast<Orbital>(target).repairOrbitalShield(repair / cast<Orbital>(target).shieldMod);
		}
	}
#section all
};

/* This never really worked IIRC.
class ChangeOriginOnOwnerChange : StatusHook {
	Document doc("When the object affected by this status changes owners, the status' origin empire is also changed.");
	Argument refresh("Refresh Status", AT_Boolean, "True", doc="If true, the status will be removed and replaced with an identical copy of itself. If in doubt, set to true.");
	Argument refreshduration("Refreshed Duration", AT_Decimal, "-1", doc="The duration of the status after it is refreshed. Does not apply if Refresh Status is set to false. Defaults to -1 (never expires).");
	
#section server
	bool onOwnerChange(Object& obj, Status@ status, any@ data, Empire@ prevOwner, Empire@ newOwner) override {
		if(newOwner !is null)
			@status.originEmpire = newOwner;
		if(refresh.boolean)
			obj.addStatus(status.type.id, refreshduration.decimal);
		return !refresh.boolean;
	}
#section all
}
*/

class ResourcelessRegenSurface : GenericEffect, TriggerableGeneric {
	Document doc("When this hook is enabled on a planet, create a new surface with a particular size and biome count. Should be preferred to RegenSurface if both are available.");
	Argument width(AT_Integer, doc="Surface grid width.");
	Argument height(AT_Integer, doc="Surface grid width.");
	Argument biome_count(AT_Integer, "3", doc="Amount of biomes on the planet.");
	Argument force_biome(AT_PlanetBiome, EMPTY_DEFAULT, doc="Force a particular biome as the planet's base biome.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.isPlanet) {
			obj.regenSurface(width.integer, height.integer, max(biome_count.integer, 1));
			if(force_biome.str.length != 0) {
				auto@ type = getBiome(force_biome.str);
				if(type !is null)
					obj.replaceFirstBiomeWith(type.id);
			}
		}
	}
#section all
}

tidy final class PreciseTriggerOnAttributeIncrease : EmpireEffect {
	BonusEffect@ hook;

	Document doc("Trigger a bonus effect whenever an empire attribute increases by a certain threshold. This variant of the hook will not ignore the first instance when an attribute has been increased, causing issues as reported in http://steamcommunity.com/app/282590/discussions/0/217691032439349400/#c208684375424164302 - however, it is theoretically possible that other bugs may occur. Use with caution.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to check.");
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect");
	Argument threshold(AT_Decimal, "1.0", doc="Trigger the effect every time the empire attribute has increased by this amount.");

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("PreciseTriggerOnAttributeIncrease(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return EmpireEffect::instantiate();
	}

#section server
	void enable(Empire& emp, any@ data) const override {
		double amount = emp.getAttribute(attribute.integer);
		data.store(amount);
	}

	void tick(Object& obj, any@ data, double tick) const override {
		double curAmount = 0;
		data.retrieve(curAmount);

		double newAmount = 0;
		if(obj.owner !is null)
			newAmount = obj.owner.getAttribute(attribute.integer);

		while(newAmount >= curAmount + threshold.decimal) {
			if(hook !is null)
				hook.activate(obj, obj.owner);
			curAmount += threshold.decimal;
		}

		data.store(curAmount);
	}

	void tick(Empire& emp, any@ data, double tick) const override {
		double curAmount = 0;
		data.retrieve(curAmount);

		double newAmount = emp.getAttribute(attribute.integer);

		while(newAmount >= curAmount + threshold.decimal) {
			if(hook !is null)
				hook.activate(null, emp);
			curAmount += threshold.decimal;
		}

		data.store(curAmount);
	}

	void ownerChange(Object& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const override {
		double amount = 0;
		if(newOwner !is null)
			amount = newOwner.getAttribute(attribute.integer);
		data.store(amount);
	}

	void save(any@ data, SaveFile& file) const override {
		double curAmount = 0;
		data.retrieve(curAmount);
		file << curAmount;
	}

	void load(any@ data, SaveFile& file) const override {
		double curAmount = 0;
		file >> curAmount;
		data.store(curAmount);
	}
#section all
};

class SubsystemModAttributeOnEnable : SubsystemEffect {
	Document doc("Modify an empire attribute when the subsystem has been activated. WARNING: Will occur every time the subsystem comes online! Use extreme caution!");
	Argument attribute(AT_EmpAttribute, doc="Attribute to modify.");
	Argument mode(AT_AttributeMode, doc="How to modify the attribute.");
	Argument value(AT_Decimal, doc="How much to modify the attribute.");

#section server
	void start(SubsystemEvent& event) const override {
		if(event.obj.owner !is null && event.obj.owner.valid)
			event.obj.owner.modAttribute(uint(attribute.integer), mode.integer, value.decimal);
	}
#section all
};