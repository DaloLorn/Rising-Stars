import combat;
import ABEMCombat;

void NoRepairNonCore(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	
	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		if(pos == sys.core) // We don't want to affect the core.
			continue;
		HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
		if(stat is null)
			continue;

		stat.flags |= HF_NoRepair;
	}
}

void ForcefieldNoRepair(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	auto@ emitter = sys.type.module("Emitter");

	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		if(sys.module(i) !is emitter && pos != sys.core) {
			HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
			if(stat is null)
				continue;

			stat.flags |= HF_NoRepair;
		}
	}
}

void ShieldInitMitigation(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	Ship@ ship = cast<Ship>(evt.obj);
	
	if(!bp.boolean(sys, 0)) {
		bp.boolean(sys, 0) = true;
		ship.modShieldCores(sys.variable(SV_ShieldCores));
		ship.modShieldMitCap(sys.variable(SV_ShieldMitCap));
	}
}

void ShieldDisableMitigation(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	Ship@ ship = cast<Ship>(evt.obj);
	
	if(bp.boolean(sys, 0)) {
		bp.boolean(sys, 0) = false;
		ship.modShieldCores(-sys.variable(SV_ShieldCores));
		ship.modShieldMitCap(-sys.variable(SV_ShieldMitCap));
	}
}

void ForcefieldTick(Event& evt, double Regen, double Capacity, double CapacityMult) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	auto@ emitter = sys.type.module("Emitter");
	
	if(bp.getSysStatus(sys.index).status == ES_Ended)
		return; // One of the emitters is offline!

	double health = bp.decimal(sys, 0); // Get current shield integrity.
	double healthFactor = bp.decimal(sys, 1); // Get ship health factor.
	if(healthFactor != bp.hpFactor) {
		health *= 1 + (bp.hpFactor - healthFactor); // This should adjust our current health to match the new veterancy buff.
		bp.decimal(sys, 1) = bp.hpFactor;
	}
	double shieldFactor = bp.decimal(sys, 2); // Get shield capacity factor.
	if(shieldFactor != CapacityMult) {
		double hpMult = (CapacityMult / shieldFactor);
		double extraHealth = health * hpMult - health;
//		print("Adjusting for multiplier change:");
//		print("Current capacity: " + Capacity);
//		print("Current health: " + health);
//		print("Multipliers: " + shieldFactor + " changing to " + CapacityMult + ", difference " + hpMult);
//		print("Current ship health: " + bp.currentHP);
//		print("Extra capacity: " + extraHealth);
		bp.currentHP -= extraHealth;
		bp.decimal(sys, 2) = CapacityMult;
	}
	// We need to account for various effects that could have changed the field's health, because I'm bound to miss something somewhere. Too many ways to damage the damn thing without triggering ForcefieldDamage.
	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u hex = sys.hexagon(i);
		if(sys.module(i) !is emitter && hex != sys.core) {
			HexStatus@ field = bp.getHexStatus(hex.x, hex.y);
			if(field is null)
				continue;
			
			int healthPct = int((health / (Capacity * bp.hpFactor)) * 255);
			double healthDiff = double((healthPct - int(field.hp)) / 255) * (Capacity * bp.hpFactor);
			if(healthPct != int(field.hp)) {				
				health -= healthDiff;
				bp.currentHP -= healthDiff;
			}
		}
	}
	double regeneratedHP = min(Regen, Capacity * bp.hpFactor - health); // Calculate how much we can heal.
	health += regeneratedHP;
	bp.currentHP += regeneratedHP; // The blueprint needs to know we've been patching it up.
	bp.decimal(sys, 0) = health; // Store new shield integrity.
	
	sync_health_forcefield(sys, bp, health, Capacity * bp.hpFactor); // Synchronize hex health with new shield integrity.
}

// Sets forcefield health to 0.
void ForcefieldShutdown(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	bp.currentHP -= bp.decimal(sys, 0); // We need to remove all of our remaining HP from the blueprint or all hell will break loose.
	bp.decimal(sys, 0) = 0; // Store new shield integrity.
	
	sync_health_forcefield(sys, bp, 0, 1); // Synchronize hex health with new shield integrity.
}

void sync_health_forcefield(const Subsystem& sys, Blueprint& bp, double health, double maxHealth) {
	auto@ emitter = sys.type.module("Emitter");
	uint healthPct = uint((health / maxHealth) * 255);
	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		if(sys.module(i) !is emitter && pos != sys.core) {
			HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
			if(stat is null)
				continue;

			stat.hp = healthPct;
		}
	}
}

void sync_health_nocore(const Subsystem& sys, Blueprint& bp, double health, double maxHealth) {
	// HexStatus.hp is an uint from 0 to 255 describing the health percentage of the hex.
	// Hopefully my math is right here, and I'm getting an accurate percentage value in the below equation.
	uint healthPct = uint((health / maxHealth) * 255);
	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		if(pos == sys.core) // We don't want to affect the core.
			continue;
		HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
		if(stat is null)
			continue;

		stat.hp = healthPct;
	}
}

// Probably never going to need this variant, but who knows?
void sync_health(const Subsystem& sys, Blueprint& bp, double health, double maxHealth) {
	// HexStatus.hp is an uint from 0 to 255 describing the health percentage of the hex.
	// Hopefully my math is right here, and I'm getting an accurate percentage value in the below equation.
	uint healthPct = uint((health / maxHealth) * 255);
	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
		if(stat is null)
			continue;

		stat.hp = healthPct;
	}
}

DamageEventStatus ForcefieldDamage(DamageEvent& evt, const vec2u& position, double Capacity) {	
	auto@ sys = evt.destination;
	auto@ bp = evt.blueprint;
	auto@ emitter = sys.type.module("Emitter");
	// Has the emitter been destroyed? Are we hitting the emitter? Does the emitter even exist?
	if(emitter !is null || sys.type.hasCore) {
		if(bp.design.module(position) is emitter || position == sys.core) {
			return DE_Continue; // This is the emitter, kill it!
		}
	}
	if(bp.getSysStatus(position.x, position.y).status == ES_Ended) {
		return DE_SkipHex; // Emitter is offline. Forcefields are offline. Everything's offline.
	}
	
	double health = bp.decimal(sys, 0);
	// Do we have any power left?
	if(health <= 0) {
		return DE_SkipHex;
	}

	//Prevent internal-only effects (I have no idea what this does, just copy-pasting from armor scripts)
	evt.flags &= ~ReachedInternals;

	// Check if we're getting hit by a shield-piercing weapon. We're using an oversimplified version of mitigation here because forcefields don't technically *have* mitigation.
	bool hasPenetration = evt.flags & DF_QuadShieldPenetration != 0;
	
	// Do damage math.
	double dmg = evt.damage;
	if(hasPenetration) {
		dmg /= 2.0; // Half of the damage moves on as bleedthrough. No, it's not supposed to be a quarter or three quarters or anything else...
		evt.damage /= 2.0; // ... It's complicated. See the rest of this block.
	}
	dmg = max(dmg - health, 0.0);
	bp.currentHP -= evt.damage - dmg; // This should tell the blueprint that it's been damaged. I think.
	health = max(health - evt.damage, 0.0);
	
	// Store the damage and health values.

	if(hasPenetration)
		dmg += evt.damage; // We need the extra damage from the bleedthrough.
	evt.damage = dmg;
	bp.decimal(sys, 0) = health;
	
	// Postprocessing.
	sync_health_forcefield(sys, bp, health, Capacity * bp.hpFactor); // Sync the damaged forcefield's health.
	cast<Ship>(evt.target).recordDamage(evt.obj);
	if(dmg <= 0.0) // Send the diminished damage (if any) on its merry way.
		return DE_EndDamage;
	return DE_SkipHex; 
}

// In case we want ceramics that can be repaired but still disappear when destroyed.
// Not sure if it works correctly, though. Should probably consult Lucas before trying to use it.
void RepairableSingleUseRetrofit(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
		if(stat is null)
			continue;
			
		if(stat.flags & HF_Gone != 0)
			bp.removedHP += bp.design.variable(pos, HV_HP);
	}
}

DamageEventStatus RemoveDeadRepairableHexes(DamageEvent& evt, const vec2u& position) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	bp.damage(evt.target, evt, position);

	HexStatus@ stat = bp.getHexStatus(position.x, position.y);
	if(stat.hp == 0) {
		stat.flags |= HF_NoRepair;
		stat.flags |= HF_Gone;
		bp.removedHP += bp.design.variable(position, HV_HP);
	}
	return DE_SkipHex;
}