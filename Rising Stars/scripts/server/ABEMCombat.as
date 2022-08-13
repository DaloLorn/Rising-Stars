import statuses;
import combat;
import generic_effects;
import components.Statuses;
import ABEM_data;
from empire import Creeps, Pirates;

DamageFlags DF_QuadShieldPenetration = DF_Flag6;
DamageFlags DF_HalfShieldDamage = DF_Flag7;

int getDamageType(double type) {
	int iType = int(type);
	switch(iType) {
		case 1: 
		case 4: // The duplicate cases are for applying a DoT effect. Only implemented for AreaDamage.
			return DT_Projectile;
		case 2:
		case 5:
			return DT_Energy;
		case 3:
		case 6:
			return DT_Explosive;
		case 7:
		default: return DT_Generic;
	}
	return DT_Generic;
}

int getDRResponse(double type) {
	int iType = int(type);
	switch(iType) {
		case 1:
			return DF_IgnoreDR;
		case 2:
			return DF_FullDR;
		case 3:
			return DF_QuadShieldPenetration;
		case 4:
			return DF_HalfShieldDamage;
		case 5:
			return DF_IgnoreDR | DF_QuadShieldPenetration;
		case 6:
			return DF_FullDR | DF_HalfShieldDamage;
		case 7:
			return DF_IgnoreDR | DF_HalfShieldDamage;
		case 8:
			return DF_FullDR | DF_QuadShieldPenetration;
		default: return 0;
	}
	return 0;
}

bool AddStatusToSelf(const Effector& efftr, Object& obj, Object& target, float& efficiency, double supply, double statusType) {
	uint firingStatus = getABEMStatus(statusType).id;
	
	if(obj.getStatusStackCountAny(firingStatus) < 5)
		obj.addStatus(firingStatus, 2.0);

	return WeaponFire(efftr, obj, target, efficiency, supply);
}

bool FireIfNotStatus(const Effector& efftr, Object& obj, Object& target, float& efficiency, double supply, double statusType) {
	if(obj.hasStatusEffect(getABEMStatus(statusType).id))
		return false;

	return WeaponFire(efftr, obj, target, efficiency, supply);
}

bool FireIfRaiding(const Effector& efftr, Object& obj, Object& target, float& efficiency, double supply) {
	if(obj.hasSupportAI && !obj.isDetached)
		return false;

	return WeaponFire(efftr, obj, target, efficiency, supply);
}

void ABEMControlDestroyed(Event& evt) {
	Ship@ ship = cast<Ship>(evt.obj);
	int invaderID = getStatusID("IsInvader");
	int boardingParty = getStatusID("BoardingParty");
	int infiltrated = getStatusID("Infiltrated");

	//Make sure we still have a bridge or something with control up
	if(!ship.blueprint.hasTagActive(ST_ControlCore)) {
		if(!ship.hasLeaderAI || ship.owner is Creeps || ship.owner is Pirates || (invaderID != -1 && ship.hasStatusEffect(invaderID)) || ship.blueprint.hasTagActive(ST_SelfDestruct))
			ship.destroy();
		else if (ship.hasStatusEffect(boardingParty) || ship.hasStatusEffect(infiltrated)) {
			ship.grantDestructionRewards();
			@ship.owner = defaultEmpire;
		}
		else {
			double chance = ship.blueprint.currentHP / ship.blueprint.design.totalHP;
			if(randomd() < chance) {
				const uint type = getStatusID("DerelictShip");
				ship.addStatus(-1, type);
				ship.grantDestructionRewards();
				@ship.owner = defaultEmpire;
			}
			else {
				ship.destroy();
			}
		}
	}
}

DamageEventStatus CapDamageExceptEnergy(DamageEvent& evt, const vec2u& position,
	double maxDamage, double MinimumPercent)
{
	if((evt.flags & typeMask) == DT_Energy)
		return DE_Continue;
	if(evt.flags & DF_IgnoreDR != 0)
		return DE_Continue;
	if(evt.flags & DF_FullDR != 0)
		MinimumPercent = 0.01;
	if(evt.damage > maxDamage * evt.partiality)
		evt.damage = max(maxDamage * evt.partiality, evt.damage * MinimumPercent);
	return DE_Continue;
}

DamageEventStatus ChannelDamage(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double MinPct, double RechargePercent)
{
	if(evt.flags & DF_IgnoreDR != 0)
		return DE_Continue;
	if(evt.flags & DF_FullDR != 0)
		MinPct = 0.01;

	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

	double dmg = evt.damage;
	double dr;
	switch(evt.flags & typeMask) {
		case DT_Projectile:
			dr = ProjResist; break;
		case DT_Energy:
			dr = EnergyResist; break;
		case DT_Explosive:
			dr = ExplResist; break;
		case DT_Generic:
		default:
			dr = (ProjResist + EnergyResist + ExplResist) / 3.0; break;
	}
		
	dmg -= dr * evt.partiality;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg) {
		dmg = minDmg;
		dr = (dr * evt.partiality) - (minDmg - dmg);
	}
	evt.damage = dmg;
	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null) {
		double Recharge = dr * RechargePercent;
		if((ship.Shield + Recharge) > ship.MaxShield) {
			double PowerRecharge = (ship.Shield + Recharge) - ship.MaxShield;
			ship.Shield = ship.MaxShield;
			ship.refundEnergy(PowerRecharge);
		}
		else {
			ship.Shield += Recharge;
		}
	}
	return DE_Continue;
}

DamageEventStatus ChannelDamagePercentile(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double MinPct, double RechargePercent)
{
	if(evt.flags & DF_IgnoreDR != 0)
		return DE_Continue;
	if(evt.flags & DF_FullDR != 0)
		MinPct = 0.01;

	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

	double dmg = evt.damage;
	double dr;
	switch(evt.flags & typeMask) {
		case DT_Projectile:
			dr = ProjResist; break;
		case DT_Energy:
			dr = EnergyResist; break;
		case DT_Explosive:
			dr = ExplResist; break;
		case DT_Generic:
		default:
			dr = (ProjResist + EnergyResist + ExplResist) / 3.0; break;
	}
	
	dr *= dmg;
	
	dmg -= dr * evt.partiality;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg) {
		dmg = minDmg;
		dr = (dr * evt.partiality) - (minDmg - dmg);
	}
	evt.damage = dmg;
	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null) {
		double Recharge = dr * RechargePercent;
		if((ship.Shield + Recharge) > ship.MaxShield) {
			double PowerRecharge = (ship.Shield + Recharge) - ship.MaxShield;
			ship.Shield = ship.MaxShield;
			ship.refundEnergy(PowerRecharge);
		}
		else {
			ship.Shield += Recharge;
		}
	}
	return DE_Continue;
}

DamageEventStatus ReduceDamagePercentile(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double MinPct)
{
	if(evt.flags & DF_IgnoreDR != 0)
		return DE_Continue;
	if(evt.flags & DF_FullDR != 0)
		MinPct = 0.01;

	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

	double dmg = evt.damage;
	double dr;
	switch(evt.flags & typeMask) {
		case DT_Projectile:
			dr = ProjResist; break;
		case DT_Energy:
			dr = EnergyResist; break;
		case DT_Explosive:
			dr = ExplResist; break;
		case DT_Generic:
		default:
			dr = (ProjResist + EnergyResist + ExplResist) / 3.0; break;
	}
	
	dr *= dmg;
	
	dmg -= dr * evt.partiality;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg;
	return DE_Continue;
}

void ReactorOverload(Object& obj, double PowerAmountMult, double PowerRadiusMult, double BaseAmount, double BaseRadius) {
	Ship@ ship = cast<Ship>(obj);
	if(ship !is null) {
		double power = ship.blueprint.getEfficiencySum(SV_Power);
		double amount = BaseAmount + sqrt(power * PowerAmountMult);
		double radius = BaseRadius + sqrt(power * PowerRadiusMult);
		ObjectAreaExplDamage(obj, amount, radius, 4, 1);
		obj.destroy();
	}
}

void ObjectAreaExplDamage(Object& obj, double Amount, double Radius, double Hits, double Spillable) {
	vec3d center = obj.position;
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), obj.owner.hostileMask);

	playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 1.5, obj.visibleMask);

	uint hits = round(Hits);
	double maxDSq = Radius * Radius;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = Amount;
		if(dist > 0.0)
			deal *= 1.0 - (dist / Radius);
		
		//Rock the boat
		if(target.hasMover) {
			double amplitude = deal * 0.2 / (target.radius * target.radius);
			target.impulse(off.normalize(min(amplitude,8.0)));
			target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
		}
		
		DamageEvent dmg;
		@dmg.obj = obj;
		@dmg.target = target;
		dmg.flags |= DT_Projectile;
		dmg.impact = off.normalized(target.radius);
		dmg.spillable = Spillable != 0;
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		for(uint n = 0; n < hits; ++n) {
			dmg.partiality = 1 / double(hits);
			dmg.damage = deal * double(1) * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
		}
	}
}

void AreaDamage(Event& evt, double Amount, double Radius, double Hits, double Spillable, double DamageType, double DRResponse) {
	Object@ targ = evt.target !is null ? evt.target : evt.obj;

	vec3d center = targ.position + evt.impact.normalize(targ.radius);
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), evt.obj.owner.hostileMask);

	playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 3.0, targ.visibleMask);

	uint hits = round(Hits);
	double maxDSq = Radius * Radius;
	
	int flags = getDamageType(DamageType) | getDRResponse(DRResponse);
	bool spillable = Spillable != 0;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = Amount;
		if(dist > 0.0)
			deal *= 1.0 - (dist / Radius);
		
		//Rock the boat
		if(target.hasMover) {
			double amplitude = deal * 0.2 / (target.radius * target.radius);
			target.impulse(off.normalize(min(amplitude,8.0)));
			target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
		}
		
		DamageEvent dmg;
		@dmg.obj = evt.obj;
		@dmg.target = target;
		dmg.source_index = evt.source_index;
		dmg.flags |= flags;
		dmg.impact = off.normalized(target.radius);
		dmg.spillable = spillable;
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		for(uint n = 0; n < hits; ++n) {
			dmg.partiality = evt.partiality / double(hits);
			dmg.damage = deal * double(evt.efficiency) * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
			if(DamageType > 3 && DamageType != 7)
			// Divide by 2 to get half of the torpedo's damage,
			// then divide by the 10-second duration so you don't wind up dealing 5 times the torpedo's damage in DoTs.
				ApplyAreaDoT(evt, target, dir, dmg.damage/20.0, 10.0); 
		}
	}
}

// Built for use in AreaDamage. Don't try to use it as a standalone effect.
void ApplyAreaDoT(Event& evt, Object@ target, vec2d dir, double DPS, double Duration) {
	TimedEffect te(ET_DamageOverTime, Duration);
	te.effect.value0 = DPS * double(evt.efficiency) * double(evt.partiality);
	@te.event.obj = evt.obj;
	@te.event.target = target;
	te.event.partiality = evt.partiality;
	te.event.source_index = evt.source_index;
	te.event.custom1 = dir.radians();

	evt.target.addTimedEffect(te);
}

void IncreasingDamage(Event& evt, double Amount, double Status, double StatusMultiplier, double StatusAmount, double StatusIncrement, double DamageType) {
	DamageEvent dmg;
	int i;
	int StatusInt = int(Status);
	double Increment = StatusIncrement * double(evt.partiality) * double(evt.efficiency);
	int IncrementCount = int(Increment);
	Increment -= IncrementCount;
	if(Increment > 0.00001 && randomd() < Increment)
		IncrementCount += 1; 
	Empire@ dummyEmp = null;
	Region@ dummyReg = null;
	const StatusType@ type = getABEMStatus(StatusInt);
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;
	int dmgType = getDamageType(DamageType);

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= dmgType | ReachedInternals;

	// If there was an invalid Status, then we need to detect it before we try to do anything else.
	if(evt.target.hasStatuses && type !is null) {
		// If it already has the status, find the status and check its stack count to apply some math.
		uint stacks = 0;
		stacks = evt.target.getStatusStackCount(type.id, evt.obj, evt.obj.owner);
		dmg.damage += (dmg.damage * stacks * StatusMultiplier) + (stacks * StatusAmount * double(evt.efficiency) * double(evt.partiality));
		for(i = 0; i < IncrementCount; ++i) {
			evt.target.addStatus(-1, type.id, dummyEmp, dummyReg, evt.obj.owner, evt.obj);
		}
	}
	evt.target.damage(dmg, -1.0, evt.direction);
}
					
void DamageFromRelativeSize(Event& evt, double Amount, double SizeMultiplier, double AmountPerSize, double MinRatio, double MaxRatio, double DamageType) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;
	int dmgType = getDamageType(DamageType);

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= dmgType | ReachedInternals;

	if(evt.obj !is null) { // This particular bit of code is probably unneeded, but better safe than sorry.
		// This whole section is just copy-pasted with renamed variables from RelativeSizeEnergyCost, the AbilityHook.
		double myScale = sqr(evt.obj.radius);
		if(evt.obj.isShip)
			myScale = cast<Ship>(evt.obj).blueprint.design.size;
		double theirScale = sqr(evt.target.radius);
		if(evt.target.isShip)
			theirScale = cast<Ship>(evt.target).blueprint.design.size;

		double ratio = theirScale / myScale; // Just to wrap my mind around it: If they're size 200, and we're size 100, then this will yield a ratio of 2, which is 200%. Good.
		dmg.damage *= clamp(ratio, MinRatio, MaxRatio) * SizeMultiplier;
		dmg.damage += AmountPerSize * clamp(ratio, MinRatio, MaxRatio) * double(evt.efficiency) * double(evt.partiality);
	}
	evt.target.damage(dmg, -1.0, evt.direction);
}

// Takes a certain amount of damage, scales that damage based on the ratio of BaselineSize and the target's size, within the constraints of MinRatio and MaxRatio.
void SizeScaledDamage(Event& evt, double BaselineAmount, double BaselineSize, double MinRatio, double MaxRatio, double DamageType) {
	DamageEvent dmg;
	dmg.damage = BaselineAmount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;
	int dmgType = getDamageType(DamageType);

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.spillable = false;
	dmg.source_index = evt.source_index;
	dmg.flags |= dmgType | ReachedInternals;

	double theirScale = sqr(evt.target.radius);
	if(evt.target.isShip)
		theirScale = cast<Ship>(evt.target).blueprint.design.size;

	double ratio = theirScale / BaselineSize; // Just to wrap my mind around it: If they're size 200, and we're size 100, then this will yield a ratio of 2, which is 200%. Good.
	dmg.damage *= clamp(ratio, MinRatio, MaxRatio);
	evt.target.damage(dmg, -1.0, evt.direction);
}

// AOE version of SizeScaledDamage.
void SizeScaledAreaDamage(Event& evt, double Radius, double BaselineAmount, double BaselineSize, double MinRatio, double MaxRatio, double DamageType) {
	Object@ targ = evt.target !is null ? evt.target : evt.obj;

	vec3d center = targ.position + evt.impact.normalize(targ.radius);
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), evt.obj.owner.hostileMask);

	playParticleSystem("GravitonCollapser", center, quaterniond(), Radius / 3.0, targ.visibleMask);
	int dmgType = getDamageType(DamageType);
	double maxDSq = Radius * Radius;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		vec3d revOff = center - target.position;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = BaselineAmount;

		if(dist > 0.0)
			deal *= 1.0 - (dist / Radius);
		
		//Rock the boat
		if(target.hasMover) {
			double amplitude = deal * 0.2 / (target.radius * target.radius);
			target.impulse(revOff.normalize(min(amplitude,8.0)));
			target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
		}
		
		DamageEvent dmg;
		@dmg.obj = evt.obj;
		@dmg.target = target;
		dmg.source_index = evt.source_index;
		dmg.flags |= dmgType;
		dmg.impact = off.normalized(target.radius);
		dmg.spillable = false;
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		double theirScale = sqr(target.radius);
		if(target.isShip)
			theirScale = cast<Ship>(target).blueprint.design.size;

		double ratio = theirScale / BaselineSize; // Just to wrap my mind around it: If they're size 200, and we're size 100, then this will yield a ratio of 2, which is 200%. Good.
		deal *= clamp(ratio, MinRatio, MaxRatio);

		dmg.partiality = evt.partiality;
		dmg.damage = deal * double(evt.efficiency) * double(dmg.partiality);

		target.damage(dmg, -1.0, dir);
	}
}

DamageEventStatus DefensiveMatrixDamage(DamageEvent& evt, vec2u& position, vec2d& endPoint) {
	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null) {
		if(ship.blueprint.getEfficiencySum(SV_ShieldCapacity) <= 0) {
			ABEMShieldDamage(evt, position, endPoint);
		}
	}
	return DE_Continue;
}

void GenericDamage(Event& evt, double Amount, double Pierce, double DRResponse, double DamageType, double Spillable) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.spillable = Spillable != 0;
	dmg.flags |= getDamageType(DamageType) | getDRResponse(DRResponse) | ReachedInternals;

	evt.target.damage(dmg, -1.0, evt.direction);
}

DamageEventStatus ABEMShieldDamage(DamageEvent& evt, vec2u& position, vec2d& endPoint) {
	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null && ship.Shield > 0) {
		double maxShield = ship.MaxShield;
		if(maxShield <= 0.0)
			maxShield = ship.Shield;
	
		double dmgScale = (evt.damage * ship.Shield) / (maxShield * maxShield);
		if(dmgScale < 0.01) {
			//TODO: Simulate this effect on the client
			if(randomd() < dmgScale / 0.001)
				playParticleSystem("ShieldImpactLight", ship.position + evt.impact.normalized(ship.radius * 0.9), quaterniond_fromVecToVec(vec3d_front(), evt.impact), ship.radius, ship.visibleMask, networked=false);
		}
		else if(dmgScale < 0.05) {
			playParticleSystem("ShieldImpactMedium", ship.position + evt.impact.normalized(ship.radius * 0.9), quaterniond_fromVecToVec(vec3d_front(), evt.impact), ship.radius, ship.visibleMask);
		}
		else {
			playParticleSystem("ShieldImpactHeavy", ship.position + evt.impact.normalized(ship.radius * 0.9), quaterniond_fromVecToVec(vec3d_front(), evt.impact), ship.radius, ship.visibleMask, networked=false);
		}

		// BEGIN NON-MIT CODE - DOF (Mitigation)
		double Mitigation = ship.mitigation;
		double ShieldPenetration = evt.pierce / 4.0; // We don't want muons to completely bleed through, nor do we want railguns to ignore mitigation.
		double BlockFactor = 1;

		// Process shield bleedthrough damage flags.
		if(evt.flags & DF_QuadShieldPenetration != 0)
			ShieldPenetration *= 4.0;
		if(evt.flags & DF_HalfShieldDamage != 0)
			BlockFactor = 0.5;

		// If piercing is present, reduce mitigation
		if(ShieldPenetration > 0)  {
			double tmp = Mitigation;
			Mitigation = max(Mitigation - ShieldPenetration, 0.0);
			ShieldPenetration = max(ShieldPenetration - tmp, 0.0);
			evt.pierce = min(ShieldPenetration * 4, evt.pierce); // Reduce hull penetration, because we can.
		}

		// Apply remaining mitigation
		evt.damage *= 1 - Mitigation;

		double block;
		block = min(ship.Shield, evt.damage * max(1 - ShieldPenetration, 0.0));
		
		ship.Shield -= block * BlockFactor; // Reduce damage taken by shields.
		evt.damage -= block / BlockFactor; // Increase damage reduction proportionately.
		// Bleedthrough damage isn't affected by mitigation
		evt.damage /= 1 - Mitigation;
		// END NON-MIT CODE
		
		if(evt.damage <= 0.0)
			return DE_EndDamage;
	}
	return DE_Continue;
}