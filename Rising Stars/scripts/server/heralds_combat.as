from combat import DamageTypes, DF_FullDR, ReachedInternals, ProjDamage, DF_IgnoreDR, typeMask;
from statuses import getStatusID;

int warheadStatus;
void init() {
	warheadStatus = getStatusID("Warhead");
}

void ReactorOverload(Event& evt, double Damage) {
	if(!evt.target.isShip)
		return;

	Ship@ ship = cast<Ship>(evt.target);
	if(ship.MaxShield > 0)
		Damage *= 1 - (ship.Shield / ship.MaxShield);

	DamageEvent dmg;
	dmg.damage = Damage * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Energy | DF_FullDR | ReachedInternals;

	//Randomly find an alive hex adjacent to a reactor subsystem
	auto@ bp = cast<Ship>(evt.target).blueprint;
	const Design@ dsg = bp.design;

	const Subsystem@ dmgSys;
	double totalHexes = 0;

	double roll = randomd();
	for(uint i = 0, cnt = dsg.subsystemCount; i < cnt; ++i) {
		auto@ sys = dsg.subsystems[i];
		if(!sys.type.hasTag(ST_IsReactor))
			continue;

		double hexCount = sys.hexCount;
		totalHexes += hexCount;
		double chance = hexCount / totalHexes;
		if(roll < chance) {
			@dmgSys = sys;
			roll /= chance;
		}
		else {
			roll = (roll - chance) / (1.0 - chance);
		}
	}

	if(dmgSys is null)
		return;

	uint hexCount = dmgSys.hexCount;
	if(dmgSys is null || hexCount == 0)
		return;

	vec2u hex = dmgSys.hexagon(randomi(0, hexCount-1));
	HexGridAdjacency dir = HexGridAdjacency(randomi(0,5));

	do {
		if(!dsg.hull.active.advance(hex, dir))
			break;
	} while(dsg.subsystem(hex) is dmgSys);

	bp.damage(evt.target, dmg, hex, dir, false);
	ship.recordDamage(evt.obj);
}

DamageEventStatus NilingAbsorb(DamageEvent& evt, const vec2u& position, double Damage, double Radius)
{
	//if((evt.flags & typeMask) != DT_Energy)
	//	return DE_SkipHex;

	auto@ sys = evt.destination;
	auto@ bp = evt.blueprint;

	double value = bp.decimal(sys, 0);
	value += evt.damage;

	if(value >= Damage) {
		if(value >= bp.currentHP)
			value = max(bp.currentHP, Damage);
		double radius = Radius * sqrt(value / Damage);
		playParticleSystem("NilingExplosion", evt.target.position, quaterniond(), radius / 15.0, evt.target.visibleMask);
		AoEDamage(evt.target, evt.target, vec3d(), value * 0.9, radius, 10.0);

		value = 0;
	}

	bp.decimal(sys, 0) = value;
	return DE_Continue;
}

void AoEDamage(Object& source, Object@ targ, const vec3d& impact, double Damage, double Radius, double Hits = 1.0, double partiality = 1.0, double pushback = 0.0, bool spillable = true) {
	vec3d center = impact;
	if(targ !is null)
		center = targ.position + center.normalize(targ.radius);

	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), source.owner.hostileMask);

	uint hits = round(Hits);
	double maxDSq = Radius * Radius;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = Damage;
		if(dist > 0.0)
			deal *= 1.0 - (dist / Radius);
		
		//Rock the boat
		if(pushback > 0 && target.hasMover) {
			double amplitude = deal * pushback / (target.radius * target.radius);
			target.impulse(off.normalize(min(amplitude,8.0)));
			target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
		}
		
		DamageEvent dmg;
		@dmg.obj = source;
		@dmg.target = target;
		dmg.flags |= DT_Explosive | DF_FullDR;
		dmg.impact = off.normalized(target.radius);
		dmg.spillable = spillable;
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		for(uint n = 0; n < hits; ++n) {
			dmg.partiality = partiality / double(hits);
			dmg.damage = deal * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
		}
	}
	
}

ThreadLocal<HexLineDamage@> hexLine;
HexLineDamage@ _hexLine() {
	HexLineDamage@ line = hexLine.get();
	if(line is null) {
		@line = HexLineDamage();
		hexLine.set(line);
	}
	return line;
}

class HexLineDamage : BlueprintHexLine {
	DamageEvent dmg;
	Blueprint@ bp;

	bool process(const vec2u& pos) {
		double prevDamage = dmg.damage;
		bp.damageHex(dmg.target, dmg, pos, false);
		dmg.damage = prevDamage;
		return true;
	}
};

void LineDamage(Event& evt, double Damage) {
	if(!evt.target.isShip) {
		ProjDamage(evt, Damage * 10.0, 0.0, 0.0, 0.0);
		return;
	}

	Ship@ ship = cast<Ship>(evt.target);
	if(ship.MaxShield > 0)
		Damage *= 1.0 - (ship.Shield / ship.MaxShield);
	if(Damage < 0.001)
		return;

	auto@ bp = ship.blueprint;
	const Design@ dsg = bp.design;

	HexLineDamage@ line = _hexLine();
	@line.bp = bp;
	line.dmg.damage = Damage * double(evt.efficiency) * double(evt.partiality);
	line.dmg.partiality = evt.partiality;
	line.dmg.impact = evt.impact;

	@line.dmg.obj = evt.obj;
	@line.dmg.target = evt.target;
	line.dmg.source_index = evt.source_index;
	line.dmg.flags |= DT_Projectile;

	bp.runHexLine(evt.target, line, evt.direction);
	ship.recordDamage(evt.obj);
}

double handleHarmonizedDamage(double Damage, Ship@ ship, double RedirectFactor) {
	if(ship is null)
		return Damage;

	if(RedirectFactor <= 0)
		return Damage;
	
	Ship@ flagship = cast<Ship>(ship.Leader);
	Orbital@ base = cast<Orbital>(ship.Leader);
	
	// Orbitals always have 50% mitigation in current RS. --Dalo
	double Mitigation = flagship !is null ? flagship.mitigation : 0.5;
	double shield = flagship !is null ? flagship.Shield : base.shield;
	double absorb = min(shield / 1 - Mitigation, Damage * RedirectFactor);
	double remaining = Damage;
	if(absorb > 0) {
		remaining -= absorb;
		double leaderDamage = absorb*(1-Mitigation);
		flagship !is null ? flagship.shieldDamage(leaderDamage) : base.shieldDamage(leaderDamage);
	}
	return remaining;
}

void DamageShields(Event& evt, double Damage) {
	if(!evt.target.isShip && !evt.target.isOrbital)
		return;

	Ship@ ship = cast<Ship>(evt.target);
	Orbital@ orb = cast<Orbital>(evt.target);

	if(ship !is null) {
		// Shield Mitigation
		double Mitigation = ship.mitigation;

		// Special case for shield harmonizers
		// We're just going to lump all the harmonizers together for simplicity. --Dalo
		double harmonizedDamage = handleHarmonizedDamage(Damage, ship, max(ship.blueprint.getEfficiencySum(SV_RedirectPercentage) / ship.blueprint.getEfficiencyFactor(SV_RedirectPercentage), 1.0));

		if(harmonizedDamage > 0 && ship.Shield > 0) {
			ship.shieldDamage(harmonizedDamage*(1-Mitigation));
		}
	}
	if(orb !is null) {
		// Orbitals always have 50% mitigation.
		orb.shieldDamage(Damage*0.5);
	}
};

DamageEventStatus ShieldRedirect(DamageEvent& evt, vec2u& position, vec2d& direction, double Percentage) {
	Ship@ ship = cast<Ship>(evt.target);
	if(ship is null)
		return DE_Continue;
	Object@ leader = ship.Leader;
	if(leader is null || (!leader.isShip && !leader.isOrbital))
		return DE_Continue;
		
	double workingPct = double(evt.destination_status.workingHexes) / double(evt.destination.hexCount);
	evt.damage = handleHarmonizedDamage(evt.damage, ship, workingPct);
	if(evt.damage > 0)
		return DE_Continue;
	return DE_EndDamage;
}

void BonusShield(Event& evt, double Amount) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	int curLeader = bp.integer(sys, 0);
	int newLeader = 0;

	if(!evt.obj.hasSupportAI)
		newLeader = evt.obj.id;
	else
		newLeader = evt.obj.LeaderID;

	if(newLeader != curLeader) {
		Object@ prevObj;
		if(curLeader != 0)
			@prevObj = getObjectByID(curLeader);

		Object@ newObj;
		if(newLeader != 0)
			@newObj = getObjectByID(newLeader);

		if(prevObj !is null && prevObj.valid) {
			if(prevObj.isShip) cast<Ship>(prevObj).modBonusShield(-Amount);
			else if(prevObj.isOrbital) cast<Orbital>(prevObj).modMaxShield(-Amount);
		}
		if(newObj !is null && newObj.valid) {
			if(newObj.isShip) cast<Ship>(newObj).modBonusShield(+Amount);
			else if(newObj.isOrbital) cast<Orbital>(newObj).modMaxShield(+Amount);
		}

		bp.integer(sys, 0) = newLeader;
	}
}

void RemoveBonusShield(Event& evt, double Amount) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	int curLeader = bp.integer(sys, 0);
	if(curLeader != 0) {
		Object@ prevObj = getObjectByID(curLeader);
		if(prevObj !is null && prevObj.valid) {
			if(prevObj.isShip) cast<Ship>(prevObj).modBonusShield(-Amount);
			else if(prevObj.isOrbital) cast<Orbital>(prevObj).modMaxShield(-Amount);
		}
		bp.integer(sys, 0) = 0;
	}
}

void WarheadExpl(Event& evt, double Damage, double Radius) {
	WarheadAoE(evt.obj, evt.target, evt.impact, Damage, Radius);
}

void WarheadAoE(Object& source, Object@ targ, vec3d& impact, double Damage, double Radius) {
	vec3d center = impact;
	if(targ !is null)
		center = targ.position + center.normalize(targ.radius);
	playParticleSystem("TorpExplosionTurquise", center, quaterniond(), Radius / 3.0, targ.visibleMask);

	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), source.owner.hostileMask);

	double maxDSq = Radius * Radius;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = Damage;
		if(dist > 0.0)
			deal *= 1.0 - (dist / Radius);

		if(target.isShip) {
			Ship@ ship = cast<Ship>(target);
			// Shield mitigation
			if(ship.Shield > 0) {
				//print(deal);
				double Mitigation = ship.mitigation;
				//print(Mitigation);
				double ShieldDmg = deal * Mitigation;
				//print(ShieldDmg);

				deal *= (1-Mitigation);
				//print(deal);
				ship.shieldDamage(ShieldDmg);
			}
			// Divide damage by hex count.
			deal /= ship.blueprint.design.interiorHexes + ship.blueprint.design.exteriorHexes;
			ship.damageAllHexes(deal, source=source);
		}
	}
}

bool ConsumesWarhead(const Effector& efftr, Object& obj, Object& target, float& efficiency) {
	if(!obj.hasStatuses)
		return false;
	uint count = obj.getStatusStackCount(warheadStatus);
	if(count == 0)
		return false;
	obj.removeStatusInstanceOfType(warheadStatus);
	return true;
}


void ApplyDoT(Event& evt, double DPS, double Duration) {
	TimedEffect te(ET_DamageOverTime, Duration);
	te.effect.value0 = DPS * double(evt.efficiency) * double(evt.partiality);
	@te.event.obj = evt.obj;
	@te.event.target = evt.target;
	te.event.partiality = evt.partiality;
	te.event.source_index = evt.source_index;
	te.event.custom1 = evt.direction.radians();

	evt.target.addTimedEffect(te);
}

void DoTDamage(Event& evt, double DPS) {
	double angle = (randomd(evt.custom1 - 0.5*pi, evt.custom1 + 0.5*pi) + twopi) % twopi;
	vec2d direction = vec2d(1.0, 0.0).rotate(angle);
	vec3d impact(direction.x, 0.0, direction.y);

	DamageEvent dmg;
	dmg.damage = DPS * evt.time;
	dmg.partiality = evt.partiality * evt.time;
	dmg.pierce = 0.0;
	dmg.impact = impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Energy;

	evt.target.damage(dmg, -1.0, direction);
}

void StartInstances(Event& evt, double Amount) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	bp.decimal(sys, 0) = 0.0;
}

void RecoverInstances(Event& evt, double Amount) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	double inst = bp.decimal(sys, 0);
	bp.decimal(sys, 0) = min(inst + (Amount * evt.time * evt.workingPercent), Amount);
}

DamageEventStatus DeflectInstances(DamageEvent& evt, vec2u& position, vec2d& direction, double Amount) {
	auto@ sys = evt.destination;
	auto@ bp = evt.blueprint;

	//Check if we have instances to ignore left
	double inst = bp.decimal(sys, 0);
	if(inst < evt.partiality)
		return DE_Continue;

	//Check the angle of the impact
	if(sys.effectorCount != 0) {
		auto@ efftr = sys.effectors[0];

		vec3d dirVec(direction.x, 0.0, direction.y);
		double angleDiff = dirVec.normalized().angleDistance(efftr.turretAngle);

		if(angleDiff > efftr.fireArc)
			return DE_Continue;
	}

	double dmgScale = evt.damage / bp.design.totalHP;
	if(dmgScale < 0.001) {
		if(randomd() < dmgScale / 0.0001)
			playParticleSystem("ShieldImpactLight", evt.target.position + evt.impact.normalized(evt.target.radius * 0.9), quaterniond_fromVecToVec(vec3d_front(), evt.impact), evt.target.radius, evt.target.visibleMask, networked=false);
	}
	else if(dmgScale < 0.015) {
		playParticleSystem("ShieldImpactMedium", evt.target.position + evt.impact.normalized(evt.target.radius * 0.9), quaterniond_fromVecToVec(vec3d_front(), evt.impact), evt.target.radius * 0.5, evt.target.visibleMask);
	}
	else {
		playParticleSystem("ShieldImpactHeavy", evt.target.position + evt.impact.normalized(evt.target.radius * 0.9), quaterniond_fromVecToVec(vec3d_front(), evt.impact), evt.target.radius * 0.5, evt.target.visibleMask, networked=false);
	}

	inst -= evt.partiality;
	bp.decimal(sys, 0) = inst;

	evt.damage = 0;
	return DE_EndDamage;
}

void NoRepairHexes(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
		if(stat is null)
			continue;

		stat.flags |= HF_NoRepair;
	}
}

void SingleUseRetrofit(Event& evt) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u pos = sys.hexagon(i);
		HexStatus@ stat = bp.getHexStatus(pos.x, pos.y);
		if(stat is null)
			continue;

		stat.flags |= HF_NoRepair;
		if(stat.flags & HF_Gone != 0)
			bp.removedHP += bp.design.variable(pos, HV_HP);
	}
}

DamageEventStatus RemoveDeadHexes(DamageEvent& evt, const vec2u& position) {
	auto@ sys = evt.source;
	auto@ bp = evt.blueprint;

	bp.damage(evt.target, evt, position);

	HexStatus@ stat = bp.getHexStatus(position.x, position.y);
	if(stat.hp == 0) {
		stat.flags |= HF_Gone;
		bp.removedHP += bp.design.variable(position, HV_HP);
	}
	return DE_SkipHex;
}

void FlakImpact(Event& evt, double Amount, double Pierce, double IgnoreDR, double FlagReduction) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Projectile;

	if(!evt.target.hasSupportAI)
		dmg.damage *= FlagReduction;

	if(IgnoreDR != 0)
		dmg.flags |= DF_IgnoreDR;

	evt.target.damage(dmg, -1.0, evt.direction);
}
