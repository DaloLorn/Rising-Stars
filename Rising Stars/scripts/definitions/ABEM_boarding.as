import generic_effects;
import hooks;
import subsystem_effects;
import statuses;
import status_effects;
#section server
import combat;
import ABEMCombat;
#section all

class BoardingData {
	double boarders;
	double originalBoarders;
	double defenders;
	Ship@ targetShip;
	Orbital@ targetOrbital;
	uint locationIndex;
	double timer = 0;
	double reactivationTimer = 0;
	bool justLoaded = false;
	any data;
}

const double BOARDING_TICKRATE = 0.25;

class BoardShip : StatusHook {
	Document doc("Places a boarding party on a random internal subsystem (avoids Antimatter Generators, prefers Security Stations) and starts damaging its hexes until all troops are lost or the ship's control subsystems have been destroyed. Once a subsystem is disabled, boarding parties will randomly select a new target to attack. Captures the ship and applies a debuff once the control cores are destroyed.");
	Argument value("Offensive Subsystem Value", AT_Custom, doc="Subsystem value used to determine the attacker's strength.");
	Argument defenseValue("Defensive Subsystem Value", AT_Custom, doc="Subsystem value used to determine the defender's strength.");
	Argument defaultBoarders("Default Boarding Strength", AT_Decimal, "400.0", doc="If the relevant subsystem value cannot be found or is zero on the origin object, this is how strong the boarding party will be.");
	Argument defaultDefenders("Default Defense Strength", AT_Decimal, "100.0", doc="If the relevant subsystem value cannot be found or is zero on the target object, this is how strong the object's defense will be.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		BoardingData info;

		// Calculating boarder strength.
		double boarders = 0;
		Ship@ caster = cast<Ship>(status.originObject);
		if(caster !is null)
			boarders = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(value.str)), ST_Boarders, true);
		if(boarders <= 0)
			boarders = defaultBoarders.decimal;
		
		// Calculating defender strength.
		double defenders = 0;
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null)
			defenders = ship.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(defenseValue.str)), ST_SecuritySystem, true);
		Orbital@ orb = cast<Orbital>(obj);
		if(defenders <= 0) // TODO: Make it possible to define custom boarding strength for various orbitals.
			defenders = defaultDefenders.decimal;

		if(obj.owner is defaultEmpire)
			defenders = 0;

		info.boarders = boarders;
		info.defenders = defenders;
		info.originalBoarders = boarders;
		@info.targetShip = ship;
		@info.targetOrbital = orb;
		pickSubsystem(info);
		data.store(@info);
	}

	// Selects a subsystem for the boarding party to attack.
	void pickSubsystem(BoardingData& info) {
		if(info.targetShip is null) // Can't pick subsystems on an orbital. Orbitals take direct health damage instead, and are captured when health reaches 25%.
			return;
		
		Blueprint@ blueprint = info.targetShip.blueprint;
		uint cnt = blueprint.design.subsystemCount;
		// First, let's try finding a security station capable of fighting us.
		for(uint i = 0; i < cnt; ++i) {
			const Subsystem@ sys = blueprint.design.subsystems[i];
			// The station must be equipped to fight our kind of boarding party, and it must still be active.
			if(sys.type.hasTag(ST_SecuritySystem) && sys.has(SubsystemVariable(getSubsystemVariable(value.str))) && blueprint.getSysStatus(i).status == ES_Active)
			{
				info.locationIndex = i;
				return;
			}
		}
		
		// This could theoretically backfire if there are absolutely no valid subsystems to target... but at that point we may have a bigger issue to deal with.
		while(true) {
			uint index = randomi(0, cnt-1);
			const Subsystem@ sys = blueprint.design.subsystems[index];
			
			if(sys.type.hasTag(ST_Volatile)) // Antimatter Reactors are too dangerous to board.
				continue;
			
			if(sys.type.hasTag(ST_NoWall) || sys.type.hasTag(ST_IsArmor) || sys.type.hasTag(ST_ExternalSpace) || sys.type.hasTag(ST_FauxExterior) || sys.type.hasTag(ST_Forcefield) || sys.type.hasTag(ST_PassExterior)) // This should prevent attacks against all armor, sensors and Solar Panels.
				continue;
				
			if(sys.type.hasTag(ST_Applied) || sys.type.hasTag(ST_HullSystem)) // This should prevent attacks against applied subsystems or hulls.
				continue;
				
			if(blueprint.getSysStatus(index).status != ES_Active) // This should prevent attacks against disabled subsystems.
				continue;
				
			info.locationIndex = index;
			return;
		}
	}
	
	// Damages the boarding party, and returns true if there are still any troops left.
	bool combatTick(BoardingData& info) {
		if(info.boarders <= 0)
			return false;
			
		// Damaging a Security Station will reduce the ship's defense strength, and we need to remember that.
		if(info.targetShip !is null)
			info.defenders = info.targetShip.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(defenseValue.str)), ST_SecuritySystem, true);
		
		// The boarders' casualties grow exponentially if they don't have a significant advantage over the defenders. If their relative strength is great enough, their casualties will be negligible.
		double advantageMult = 1;
		double ratio = info.boarders / info.defenders;
		if(ratio > 2)
			advantageMult = ratio / 2;
		
		info.boarders -= info.defenders / (ratio * advantageMult * 10) * BOARDING_TICKRATE;
		
		return info.boarders > 0;
	}
	
	// Damages the subsystem the boarding party is currently attacking, and returns true if the subsystem is still operational.
	bool damageTick(BoardingData& info, Status@ status, bool isShip) {
		DamageEvent dmg;
		@dmg.obj = status.originObject;
		dmg.damage = info.boarders;
		dmg.partiality = BOARDING_TICKRATE;
		dmg.flags |= DT_Generic | ReachedInternals | DF_FullShieldBleedthrough;
		if(isShip) {
			const Subsystem@ location = info.targetShip.blueprint.design.subsystems[info.locationIndex];
			uint cnt = location.hexCount;
			vec2u hex = location.hexagon(randomi(0, cnt-1));
			HexGridAdjacency dir = HexGridAdjacency(randomi(0, 5));
			
			
			@dmg.target = info.targetShip;
			double maxDamage = info.targetShip.blueprint.design.size * 0.5 * BOARDING_TICKRATE; // We won't deal more than 0.5*ShipSize damage per second, no matter how many troops we have onboard. We're trying to sabotage or capture the ship, not destroy it outright - this should still be enough to destroy a hex or two each second.
			if(dmg.damage > maxDamage)
				dmg.damage = maxDamage;
				
			info.targetShip.blueprint.damage(info.targetShip, dmg, hex, dir, false);
			info.targetShip.recordDamage(status.originObject);
			
			return info.targetShip.blueprint.getSysStatus(info.locationIndex).status == ES_Active;
		}
		else {
			@dmg.target = info.targetOrbital;
			double maxDamage = (info.targetOrbital.maxHealth + info.targetOrbital.maxArmor) * randomd(5.0, 15.0); // While we want to bring the station below the 25% health threshold, we don't want to destroy the station.
			
			info.targetOrbital.damage(dmg, 0, vec2d(0, 0));
			return true;
		}
	}
	
	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		BoardingData@ info;
		data.retrieve(@info);
		
		// If we've only just loaded, we need to recache target data.
		if(info.justLoaded) {
			@info.targetOrbital = cast<Orbital>(obj);
			@info.targetShip = cast<Ship>(obj);
			if(info.targetShip !is null) {
				if(info.locationIndex == UINT_MAX)
					pickSubsystem(info);
			}
			info.justLoaded = false;
		}
		
		if(info.targetOrbital !is null) // Constantly check if we've captured an orbital, regardless of the boarding tickrate.
			if((info.targetOrbital.health + info.targetOrbital.armor) / (info.targetOrbital.maxHealth + info.targetOrbital.maxArmor) < 0.25)
				@obj.owner = defaultEmpire;
					
		if(obj.owner is defaultEmpire) {
			if(obj.hasStatusEffect(getStatusID("DerelictShip")))
				obj.removeStatusType(getStatusID("DerelictShip"));
			obj.engaged = false;
			obj.clearOrders();
			info.reactivationTimer += time;
			// Reactivation takes a minute if all the boarders survived the battle... but more likely it'll be a while longer. Limiting reactivation time to 30 minutes for a cripplingly close fight.
			if(info.reactivationTimer > min(60.0 / (info.boarders / info.originalBoarders), 1800.0)) {
				@obj.owner = status.originEmpire;
				return false;
			}
		}
		else {
			obj.engaged = true;
			info.timer += time;	
			
			// We want a constant tick rate to ensure that the results of combatTick() are always the same. It doesn't matter what that rate is, but it has to be constant.
			while(info.timer >= BOARDING_TICKRATE)
			{
				info.timer -= BOARDING_TICKRATE;
			
				if(info.targetShip !is null) {
					if(!damageTick(info, status, true))
						pickSubsystem(info);
				}
				else if(info.targetOrbital !is null) {
					damageTick(info, status, false);
					if((info.targetOrbital.health + info.targetOrbital.armor) / (info.targetOrbital.maxHealth + info.targetOrbital.maxArmor) < 0.25)
						@obj.owner = defaultEmpire;
				}
				if(!combatTick(info))
					return false; // If the battle ended during this tick, stop simulating any ticks we may have skipped earlier, and destroy the status.
			}
		}
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
			file << UINT_MAX;
			file << nil;
			file << nil;
		}
		else {
			file << info.boarders;
			file << info.originalBoarders;
			file << info.defenders;
			file << info.locationIndex;
			file << info.timer;
			file << info.reactivationTimer;
		}
	}
	
	void load(Status@ status, any@ data, SaveFile& file) override {
		BoardingData info;
		data.store(@info);
		
		file >> info.boarders;
		file >> info.originalBoarders;
		file >> info.defenders;
		file >> info.locationIndex;
		file >> info.timer;
		file >> info.reactivationTimer;
		
		// Tell onTick() to reconstruct target data.
		info.justLoaded = true;
	}
#section all
};