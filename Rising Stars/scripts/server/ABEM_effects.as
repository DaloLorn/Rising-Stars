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

void ForcefieldTick(Event& evt, double Regen, double Capacity) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	if(sys.type.hasCore) {
		if(bp.getHexStatus(sys.core.x, sys.core.y).hp < 1) {
			return; // Emitter is offline. Forcefields are offline. Everything's offline.
		}
	}
	double health = bp.decimal(sys, 0); // Get current shield integrity.
	health = min(health + Regen, Capacity); // Calculate new shield integrity.
	bp.decimal(sys, 0) = health; // Store new shield integrity.
	
	sync_health_nocore(sys, bp, health, Capacity); // Synchronize hex health with new shield integrity.
}

// Sets forcefield health to 0.
void ForcefieldShutdown(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;
	bp.decimal(sys, 0) = 0; // Store new shield integrity.
	
	sync_health_nocore(sys, bp, 0, 1); // Synchronize hex health with new shield integrity.
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

DamageEventStatus ForcefieldDamage(DamageEvent& evt, const vec2u& position, double Capacity, double UseBleedthrough) {
	// This allows us to decide if forcefields can be penetrated by shield bleedthrough, like that from Progenitor drones.
	bool hasShieldBleedthrough = UseBleedthrough != 0;
	
	auto@ sys = evt.destination;
	auto@ bp = evt.blueprint;
	// Has the emitter been destroyed? Are we hitting the emitter;
	if(sys.type.hasCore) {
		if(position == sys.core) {
			return DE_Continue; // This is the emitter, kill it!
		}
		if(bp.getHexStatus(sys.core.x, sys.core.y).hp < 1) {
			return DE_SkipHex; // Emitter is offline. Forcefields are offline. Everything's offline.
		}
	}
	
	// Can we bypass this forcefield type?
	if(evt.flags & DF_FullShieldBleedthrough != 0 && hasShieldBleedthrough) {
		return DE_SkipHex;
	}
	
	double health = bp.decimal(sys, 0);
	// Do we have any power left?
	if(health < 0) {
		return DE_SkipHex;
	}

	//Prevent internal-only effects (I have no idea what this does, just copy-pasting from armor scripts)
	evt.flags &= ~ReachedInternals;
	
	// Do damage math.
	double dmg = evt.damage;
	dmg = max(dmg - health, 0.0);
	health = max(health - evt.damage, 0.0);
	
	// Store the damage and health values.
	evt.damage = dmg;
	bp.decimal(sys, 0) = health;
	
	// Postprocessing.
	cast<Ship>(evt.target).recordDamage(evt.obj);
	sync_health_nocore(sys, bp, health, Capacity); // Sync the damaged forcefield's health.
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