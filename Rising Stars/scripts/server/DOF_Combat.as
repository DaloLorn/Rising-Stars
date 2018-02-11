import combat;

//DamageFlags DF_BorgAssimilationRay = DF_Flag6;

void NukeDamage(Event& evt, double Amount, double Radius, double Hits, double Spillable) {
	Object@ targ = evt.target !is null ? evt.target : evt.obj;

	vec3d center = targ.position + evt.impact.normalize(targ.radius);
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), evt.obj.owner.hostileMask);

	//playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 3.0, targ.visibleMask);
	playParticleSystem("ShipExplosion", center, quaterniond(), Radius / 5.0, targ.visibleMask);
	//playParticleSystem("PlanetExplosion", center, quaterniond(), Radius / 10.0, targ.visibleMask);
	//playParticleSystem("StarExplosion", center, quaterniond(), Radius / 20.0, targ.visibleMask);

	uint hits = round(Hits);
	double maxDSq = Radius * Radius;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = Amount;
		//print("Distance to target = "+dist);
		//if(dist > 0.0)
			deal *= Radius/(dist*5+35);
		
		//Rock the boat
		//if(target.hasMover) {
		//	double amplitude = deal * 0.2 / (target.radius * target.radius);
		//	target.impulse(off.normalize(min(amplitude,8.0)));
		//	target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
		//}
		//Rock the boat
		if(target.hasMover) {
			if (target.isShip)  {
				//print("Target Size = "+ cast<Ship>(target).blueprint.design.size+".  Damage = "+deal);
				//print("Target Mass = "+ cast<Ship>(target).blueprint.design.total(HV_Mass)+".  Damage = "+deal);
				//Only knock about a ship if damage is over 10% of it's size
				//if (deal > cast<Ship>(target).blueprint.design.size)  {
				if (deal > cast<Ship>(target).blueprint.design.total(HV_Mass))  {
					//print("Knocking about target");
					double amplitude = deal * 0.2 / (target.radius * target.radius);
					//DOF - Reducing this as there is just too much knock about going on now - this doesn't work
					//double amplitude = deal * 0.04 / (target.radius * target.radius);
					target.impulse(off.normalize(min(amplitude,8.0)));
					target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
				}
			}
			else  {
				double amplitude = deal * 0.2 / (target.radius * target.radius);
				//DOF - Reducing this as there is just too much knock about going on now - this doesn't work
				//double amplitude = deal * 0.04 / (target.radius * target.radius);
				target.impulse(off.normalize(min(amplitude,8.0)));
				target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
			}
		}
		
		DamageEvent dmg;
		@dmg.obj = evt.obj;
		@dmg.target = target;
		dmg.source_index = evt.source_index;
		//dmg.flags |= DT_Projectile;
		//Changing this to Explosive
		dmg.flags |= DT_Explosive;
		dmg.impact = off.normalized(target.radius);
		dmg.spillable = Spillable != 0;
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		for(uint n = 0; n < hits; ++n) {
			dmg.partiality = evt.partiality / double(hits);
			dmg.damage = deal * double(evt.efficiency) * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
		}
	}
}

DamageEventStatus DOFShieldDamage(DamageEvent& evt, vec2u& position, vec2d& endPoint, double Mitigation) {
	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null && ship.Shield > 0) {
		//Overt Shield Bypass
		double ShieldBypass = evt.custom1;
		//print("Chance to bypass Shield = "+ShieldBypass);
		if (ShieldBypass > 0)  {
			//print("Attempting Shield bypass");
			if (ShieldBypass > randomd())  {
				//print("Shield bypassed");
				return DE_Continue;
			}
			//print("Shield bypass failed");
		}
		//Reduce mitigation based on lost hexes
		if(Mitigation > 0)
			Mitigation *= double(evt.destination_status.workingHexes) / double(evt.destination.hexCount);
		//print(Mitigation);
		double ShieldPierce = evt.pierce;
		//If Pierce is present...
		if(ShieldPierce > 0)  {
			//Pierce is half as effective against shields
			//Disabled.  Better balance without?
			//ShieldPierce /= 2;
			//Pierce is further reduced by Mitigation
			ShieldPierce *= 1-Mitigation/100;
			//If Pierce is still positive, check for chance to bypass shield
			if(ShieldPierce > 0 && randomd() < ShieldPierce)  {
				//Reducde piercing damage by mitigation and continue
				//evt.damage *= 1-Mitigation/100;
				//Disabling this reduction
				return DE_Continue;
			}
		}

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

		//Apply mitigation
		//print(evt.damage);
		evt.damage *= 1-Mitigation/100;
		//print(evt.damage);

		double block;
		//if(ship.MaxShield > 0)
		//	block = min(ship.Shield * min(ship.Shield / maxShield, 1.0), evt.damage);
		//else
		//	block = min(ship.Shield, evt.damage);
		//Removing bleed-through
		block = min(ship.Shield, evt.damage);
		
		ship.Shield -= block;
		evt.damage -= block;
		//Handle bleed-through non-mitigated damage
		evt.damage /= 1-Mitigation/100;

		if(evt.damage <= 0.0)
			return DE_EndDamage;
	}
	return DE_Continue;
}

DamageEventStatus DOFShieldBlock(DamageEvent& evt, vec2u& position, vec2d& direction, double Chance) {
	Ship@ ship = cast<Ship>(evt.target);

	//Overt Shield Bypass
	double ShieldBypass = evt.custom1;
	//print("Chance to bypass Hardener = "+ShieldBypass);
	if (ShieldBypass > 0)  {
		//print("Attempting Hardener bypass");
		if (ShieldBypass > randomd())  {
			//print("Hardener bypassed");
			return DE_Continue;
		}
		//print("Hardener bypass failed");
	}

	//The lower the shield strength, the lower the chance
	if(ship !is null) {
		double maxShield = ship.MaxShield;
		double shield = ship.Shield;
		if(maxShield <= 0.0001 || shield <= 0.0001)
			return DE_Continue;
		Chance *= (shield / maxShield);
	}
	
	//The more damaged the hardener, the lower the chance
	Chance *= double(evt.destination_status.workingHexes) / double(evt.destination.hexCount);

	//Deal with partiality in the chance
	if(evt.partiality != 1.0)
		Chance = pow(Chance, 1.0 / double(evt.partiality));

	//Fully block hits with a particular chance
	if(Chance > 0.001 && randomd() < Chance) {
		evt.damage = 0.0;
		return DE_EndDamage;
	}
	return DE_Continue;
}


DamageEventStatus DOFDeflectInstances(DamageEvent& evt, vec2u& position, vec2d& direction, double Amount) {

	//Overt Shield Bypass
	double ShieldBypass = evt.custom1;
	//print("Chance to bypass Deflector = "+ShieldBypass);
	if (ShieldBypass > 0)  {
		//print("Attempting Deflector bypass");
		if (ShieldBypass > randomd())  {
			//print("Deflector bypassed");
			return DE_Continue;
		}
		//print("Deflector bypass failed");
	}

	auto@ sys = evt.destination;
	auto@ bp = evt.blueprint;

	//Check if we have instances to ignore left
	double inst = bp.decimal(sys, 0);
	//print("Pre-process Instances = "+inst);
	//print("Event partiality = "+evt.partiality);
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
	//print("Post-process Instances = "+inst);

	evt.damage = 0;
	return DE_EndDamage;
}

//WotH Shield Redection (Shield Harmonizer)
DamageEventStatus DOFShieldRedirect(DamageEvent& evt, vec2u& position, vec2d& direction, double Percentage) {
	Ship@ ship = cast<Ship>(evt.target);
	Object@ leader = ship.Leader;
	if(leader is null || !leader.isShip)
		return DE_Continue;

	//Overt Shield Bypass
	double ShieldBypass = evt.custom1;
	//print("Chance to bypass Harmonizer = "+ShieldBypass);
	if (ShieldBypass > 0)  {
		//print("Attempting Harmonizer bypass");
		if (ShieldBypass > randomd())  {
		//print("Harmonizer bypassed");
			return DE_Continue;
		}
		//print("Harmonizer bypass failed");
	}

	Ship@ flagship = cast<Ship>(leader);
	double shield = flagship.Shield;
	if(shield < 0)
		return DE_Continue;

	//Shield Mitigation
	double FlagshipMitigation = flagship.blueprint.design.total(SV_Mitigation);
	//double Mitigation = ship.blueprint.design.total(SV_Mitigation);

	double workingPct = double(evt.destination_status.workingHexes) / double(evt.destination.hexCount);
	double absorb = min(shield, Percentage * evt.damage * workingPct);
	//double absorb = min(shield, Percentage * evt.damage * workingPct * (1-Mitigation/100));

	if(absorb > 0) {
		evt.damage -= absorb;
		//flagship.shieldDamage(absorb);
		flagship.shieldDamage(absorb*(1-FlagshipMitigation/100));
	}
	return DE_Continue;
}

/*
DamageEventStatus DOFDeflectorShield(DamageEvent& evt, vec2u& position, vec2d& endPoint, double Amount, double Mitigation) {

	bool Deflected = TRUE;

	//Overt Deflector Bypass
	double ShieldBypass = evt.custom1;
	//print("Chance to bypass Deflector = "+ShieldBypass);
	if (ShieldBypass > 0)  {
		//print("Attempting Deflector bypass");
		if (ShieldBypass > randomd())  {
			//print("Deflector bypassed");
			Deflected = FALSE;
		}
		//print("Deflector bypass failed");
	}

	auto@ sys = evt.destination;
	auto@ bp = evt.blueprint;

	//Check if we have instances to ignore left
	double inst = bp.decimal(sys, 0);
	if(inst < evt.partiality)
		Deflected = FALSE;

	//Check the angle of the impact
	if(sys.effectorCount != 0) {
		auto@ efftr = sys.effectors[0];

		vec3d dirVec(direction.x, 0.0, direction.y);
		double angleDiff = dirVec.normalized().angleDistance(efftr.turretAngle);

		if(angleDiff > efftr.fireArc)
			Deflected = FALSE;
	}

	if (Deflected)  {
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

	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null && ship.Shield > 0) {
		//Overt Shield Bypass
		//double ShieldBypass = evt.custom1;
		//print("Chance to bypass Shield = "+ShieldBypass);
		if (ShieldBypass > 0)  {
			//print("Attempting Shield bypass");
			if (ShieldBypass > randomd())  {
				//print("Shield bypassed");
				return DE_Continue;
			}
			//print("Shield bypass failed");
		}
		//Reduce mitigation based on lost hexes
		if(Mitigation > 0)
			Mitigation *= double(evt.destination_status.workingHexes) / double(evt.destination.hexCount);
		//print(Mitigation);
		double ShieldPierce = evt.pierce;
		//If Pierce is present...
		if(ShieldPierce > 0)  {
			//Pierce is half as effective against shields
			//Disabled.  Better balance without?
			//ShieldPierce /= 2;
			//Pierce is further reduced by Mitigation
			ShieldPierce *= 1-Mitigation/100;
			//If Pierce is still positive, check for chance to bypass shield
			if(ShieldPierce > 0 && randomd() < ShieldPierce)  {
				//Reducde piercing damage by mitigation and continue
				//evt.damage *= 1-Mitigation/100;
				//Disabling this reduction
				return DE_Continue;
			}
		}

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

		//Apply mitigation
		//print(evt.damage);
		evt.damage *= 1-Mitigation/100;
		//print(evt.damage);

		double block;
		//if(ship.MaxShield > 0)
		//	block = min(ship.Shield * min(ship.Shield / maxShield, 1.0), evt.damage);
		//else
		//	block = min(ship.Shield, evt.damage);
		//Removing bleed-through
		block = min(ship.Shield, evt.damage);
		
		ship.Shield -= block;
		evt.damage -= block;
		//Handle bleed-through non-mitigated damage
		evt.damage /= 1-Mitigation/100;

		if(evt.damage <= 0.0)
			return DE_EndDamage;
	}
	return DE_Continue;
}
*/

//WotH Shock Missiles
void DOFDamageShields(Event& evt, double Damage) {
	if(!evt.target.isShip)
		return;

	Ship@ ship = cast<Ship>(evt.target);

	//Shield Mitigation
	double Mitigation = ship.blueprint.design.total(SV_Mitigation);

	if(ship.MaxShield > 0) {
		//ship.shieldDamage(Damage);
		ship.shieldDamage(Damage*(1-Mitigation/100));
		
		return;
	}

	//Special case for shield harmonizers
	if(ship.blueprint.design.hasTag(ST_ShieldHarmonizer)) {
		Ship@ leader = cast<Ship>(ship.Leader);
		if(leader !is null)
			//leader.shieldDamage(Damage);
			leader.shieldDamage(Damage*(1-Mitigation/100));
	}
};

void FlakDamage(Event& evt, double Amount, double Radius, double Hits, double Spillable) {
	Object@ targ = evt.target !is null ? evt.target : evt.obj;

	vec3d center = targ.position + evt.impact.normalize(targ.radius);
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), evt.obj.owner.hostileMask);

	//Need a more suitable particle effect
	//playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 3.0, targ.visibleMask);
	playParticleSystem("ShipExplostionExtra", center, quaterniond(), Radius / 3.0, targ.visibleMask);
	
	uint hits = round(Hits);
	double maxDSq = Radius * Radius;

	//Max targets is capped by effector Hits value.	
	for(uint i = 0, cnt = min(objs.length, hits); i < cnt; ++i) {
		Object@ target = objs[i];
		if (target !is null && target.isShip)  {
			vec3d off = target.position - center;
			double dist = off.length - target.radius;
			if(dist > Radius)
				continue;
		
			double deal = Amount;
			//Damage is scaled by target size.  Targets smaller than size 8 take increasing damage.  Targets smaller than size 8 take reducing damage.
			//deal *= 8/cast<Ship>(evt.target).blueprint.design.size;
			deal *= 8/cast<Ship>(target).blueprint.design.size;
		
			DamageEvent dmg;
			@dmg.obj = evt.obj;
			@dmg.target = target;
			dmg.source_index = evt.source_index;
			dmg.flags |= DT_Projectile;
			dmg.impact = off.normalized(target.radius);
			dmg.spillable = Spillable != 0;
			
			vec2d dir = vec2d(off.x, off.z).normalized();
			//No partiality
			dmg.damage = deal * double(evt.efficiency);
			target.damage(dmg, -1.0, dir);
		}
	}
}

int NuclearwarheadStatus;
void init() {
	NuclearwarheadStatus = getStatusID("NuclearWarhead");
}

bool ConsumesNuclearWarhead(const Effector& efftr, Object& obj, Object& target, float& efficiency) {
	if(!obj.hasStatuses)
		return false;
	uint count = obj.getStatusStackCount(NuclearwarheadStatus);
	if(count == 0)
		return false;
	obj.removeStatusInstanceOfType(NuclearwarheadStatus);
	return true;
}

void DOFWarheadExpl(Event& evt, double Damage, double Radius) {
	DOFWarheadAoE(evt.obj, evt.target, evt.impact, Damage, Radius);
}

void DOFWarheadAoE(Object& source, Object@ targ, vec3d& impact, double Damage, double Radius) {
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

		if(target.isShip)  {
			//Work in Shield Mitigation
			if(cast<Ship>(target).Shield > 0) {
				//print(deal);
				double Mitigation = cast<Ship>(target).blueprint.design.total(SV_Mitigation);
				//print(Mitigation);
				double ShieldDmg = deal * cast<Ship>(target).blueprint.design.total(SV_HexLimit);
				//ShieldDmg *= (Mitigation/100);
				//print(ShieldDmg);

				deal *= (1-Mitigation/100);
				//print(deal);
				cast<Ship>(target).shieldDamage(ShieldDmg);
			}
			cast<Ship>(target).damageAllHexes(deal, source=source);
		}
	}
}

//void DOFAreaExplDamage(Event& evt, double Amount, double Radius, double Hits, int VFX) {
//	DOFAreaExplDamage(evt, Amount, Radius, Hits, VFX, 0);
//}

void DOFAreaExplDamage(Event& evt, double Amount, double Radius, double Hits, double VFX, double Bypass, double Spillable) {
	Object@ targ = evt.target !is null ? evt.target : evt.obj;

	vec3d center = targ.position + evt.impact.normalize(targ.radius);
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), evt.obj.owner.hostileMask);

	//playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 3.0, targ.visibleMask);
	//playParticleSystem("MissileExplosion", center, quaterniond(), Radius / 3.0, targ.visibleMask);

	//print("VFX = "+int(VFX));

	switch(int(VFX))  {
		case 0:  playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 3.0, targ.visibleMask); break;
		case 1:  playParticleSystem("MissileExplosion", center, quaterniond(), Radius / 6.0, targ.visibleMask); break;
		case 2:  playParticleSystem("ImpactFlareMissile", center, quaterniond(), Radius, targ.visibleMask); break;
		case 3:  playParticleSystem("ShipExplosionLight", center, quaterniond(), Radius/2, targ.visibleMask); break;
		case 4:  playParticleSystem("TorpExplosion", center, quaterniond(), Radius / 3.0, targ.visibleMask); break;
		case 5:  playParticleSystem("TorpExplosionBlue", center, quaterniond(), Radius / 3.0, targ.visibleMask); break;
		case 6:  playParticleSystem("TorpExplosionTurquise", center, quaterniond(), Radius / 3.0, targ.visibleMask); break;
		case 7:  playParticleSystem("TorpExplosionGreen", center, quaterniond(), Radius / 3.0, targ.visibleMask); break;
		case 8:  playParticleSystem("TorpExplosionPurple", center, quaterniond(), Radius / 3.0, targ.visibleMask); break;
	}

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
			if (target.isShip)  {
				//print("Target Size = "+ cast<Ship>(target).blueprint.design.size+".  Damage = "+deal);
				//print("Target Mass = "+ cast<Ship>(target).blueprint.design.total(HV_Mass)+".  Damage = "+deal);
				//Only knock about a ship if damage is over 10% of it's size
				//if (deal > cast<Ship>(target).blueprint.design.size)  {
				if (deal > cast<Ship>(target).blueprint.design.total(HV_Mass))  {
					//print("Knocking about target");
					double amplitude = deal * 0.2 / (target.radius * target.radius);
					//DOF - Reducing this as there is just too much knock about going on now - this doesn't work
					//double amplitude = deal * 0.04 / (target.radius * target.radius);
					target.impulse(off.normalize(min(amplitude,8.0)));
					target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
				}
			}
			else  {
				double amplitude = deal * 0.2 / (target.radius * target.radius);
				//DOF - Reducing this as there is just too much knock about going on now - this doesn't work
				//double amplitude = deal * 0.04 / (target.radius * target.radius);
				target.impulse(off.normalize(min(amplitude,8.0)));
				target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
			}
		}
		
		DamageEvent dmg;
		@dmg.obj = evt.obj;
		@dmg.target = target;
		dmg.source_index = evt.source_index;
		//dmg.flags |= DT_Projectile;
		//DOF - Changing this to Explosive
		dmg.flags |= DT_Explosive;
		//DOF - Adding bypass
		dmg.custom1 = Bypass;
		dmg.impact = off.normalized(target.radius);
		dmg.spillable = Spillable != 0;
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		for(uint n = 0; n < hits; ++n) {
			dmg.partiality = evt.partiality / double(hits);
			dmg.damage = deal * double(evt.efficiency) * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
		}
	}
}

void DOFEnergyDamage(Event& evt, double Amount, double Pierce, double Bypass, double IgnoreDR) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.custom1 = Bypass;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Energy | DF_FullDR | ReachedInternals;

	if(IgnoreDR != 0)
		dmg.flags |= DF_IgnoreDR;

	evt.target.damage(dmg, -1.0, evt.direction);
	
	//if(dmg.flags & ReachedInternals != 0 && evt.target.isShip)
	//	cast<Ship>(evt.target).startFire();
}

void DOFExplDamage(Event& evt, double Amount, double Pierce, double Bypass, double IgnoreDR, double VFX) {
	if (VFX != 0)  {
		Object@ targ = evt.target !is null ? evt.target : evt.obj;
		vec3d center = targ.position + evt.impact.normalize(targ.radius);
		switch(int(VFX))  {
			case 0:  break; //Nothing
			case 1:  playParticleSystem("TorpExplosionRed", center, quaterniond(), max(log(Amount),0.5), targ.visibleMask); break;
			case 2:  playParticleSystem("MissileExplosion", center, quaterniond(), max(log(Amount)/2.0,0.5), targ.visibleMask); break;
			case 3:  playParticleSystem("ImpactFlareMissile", center, quaterniond(), max(log(Amount)/2.0,0.5), targ.visibleMask); break;
			case 4:  playParticleSystem("ShipExplosionLight", center, quaterniond(), max(log(Amount),0.5), targ.visibleMask); break;
			case 5:  playParticleSystem("TorpExplosion", center, quaterniond(), max(log(Amount),0.5), targ.visibleMask); break;
			case 6:  playParticleSystem("TorpExplosionBlue", center, quaterniond(), max(log(Amount),0.5), targ.visibleMask); break;
			case 7:  playParticleSystem("TorpExplosionTurquise", center, quaterniond(), max(log(Amount),0.5), targ.visibleMask); break;
			case 8:  playParticleSystem("TorpExplosionGreen", center, quaterniond(), max(log(Amount),0.5), targ.visibleMask); break;
			case 9:  playParticleSystem("TorpExplosionPurple", center, quaterniond(), max(log(Amount),0.5), targ.visibleMask); break;
		}
	}
	
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.custom1 = Bypass;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Explosive | ReachedInternals;

	if(IgnoreDR != 0)
		dmg.flags |= DF_IgnoreDR;

	evt.target.damage(dmg, -1.0, evt.direction);
	
	//if(dmg.flags & ReachedInternals != 0 && evt.target.isShip)
	//	cast<Ship>(evt.target).mangle(Amount);
}

//void DOFProjDamage(Event& evt, double Amount, double Pierce, double Suppression) {
//	DOFProjDamage(evt, Amount, Pierce, Suppression, 0);
//}

void DOFProjDamage(Event& evt, double Amount, double Pierce, double Suppression, double IgnoreDR, double Bypass) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.custom1 = Bypass;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Projectile;

	if(IgnoreDR != 0)
		dmg.flags |= DF_IgnoreDR;

	//if(Bypass != 0)
	//	dmg.flags |= DF_ShieldBypass;

	evt.target.damage(dmg, -1.0, evt.direction);
	
	if(Suppression > 0 && evt.target.isShip) {
		double r = evt.target.radius;
		double suppress = Suppression * double(evt.efficiency) * double(evt.partiality) / (r*r*r);
		cast<Ship>(evt.target).suppress(suppress);
	}
}

void DOFProjImpact(Event& evt, double Amount, double Pierce, double IgnoreDR, double Impulse, double Bypass) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.custom1 = Bypass;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Projectile;

	if(IgnoreDR != 0)
		dmg.flags |= DF_IgnoreDR;

	evt.target.damage(dmg, -1.0, evt.direction);

	if(Impulse != 0) {
		Ship@ ship = cast<Ship>(evt.target);
		if(ship !is null)
			ship.impulse((ship.position - evt.obj.position).normalize(Impulse / ship.getMass()));
	}
}

DamageEventStatus DOFBorgAdaptiveHull(DamageEvent& evt, vec2u& position, vec2d& endPoint, double AdaptationMax, double AdaptationRate) {
	Ship@ ship = cast<Ship>(evt.target);
	//print("Adaptive Hull reached");
	//Handle Hard Bypass
	double Bypass = evt.custom1;
	if(Bypass > 0)  {
		//print("Adaptation Bypass is possible");
		if(Bypass > randomd())  {
			//print("Adaptation Bypass successful");
			return DE_Continue;
		}
	}
	//No Bypass, proceed with adaptive hull process
	//print("Raw damage = "+evt.damage);
	//double Adaptation = ship.Adaptation;
	//print("Current Adaptation = "+Adaptation);
	//Damage Type filter
	/*
	switch(evt.flags & typeMask) {
		case DT_Projectile:
			Adaptation *= 0.25; break;
		case DT_Energy:
			break;
		case DT_Explosive:
			Adaptation *= 0.5; break;
		case DT_Generic:
		default:
			break;
	}
	*/
	//Reporting version
	/*
	switch(evt.flags & typeMask) {
		case DT_Projectile:
			Adaptation *= 0.25; print("Damage type is Projectile"); break;
		case DT_Energy:
			print("Damage type is Energy"); break;
		case DT_Explosive:
			Adaptation *= 0.5; print("Damage type is Explosive"); break;
		case DT_Generic:
		default:
			print("Damage type is Generic"); break;
	}
	*/
	double Adaptation = 0;
	if((evt.flags & typeMask) == DT_Explosive)  {
		Adaptation = ship.AdaptationExplosive;
		if(Adaptation > 0)  {
			evt.damage *= 1-Adaptation/100;
		}
		ship.AdaptationExplosive = min(ship.AdaptationExplosive+(AdaptationRate*0.5*ship.AdaptationFactor)*evt.partiality, AdaptationMax*0.5);
	}
	else if((evt.flags & typeMask) == DT_Projectile)  {
		Adaptation = ship.AdaptationProjectile;
		if(Adaptation > 0)  {
			evt.damage *= 1-Adaptation/100;
		}
		ship.AdaptationProjectile = min(ship.AdaptationProjectile+(AdaptationRate*0.25*ship.AdaptationFactor)*evt.partiality, AdaptationMax*0.25);
	}
	else  {
		Adaptation = ship.AdaptationEnergy;
		if(Adaptation > 0)  {
			evt.damage *= 1-Adaptation/100;
		}
		ship.AdaptationEnergy = min(ship.AdaptationEnergy+(AdaptationRate*ship.AdaptationFactor)*evt.partiality, AdaptationMax);
	}
	//print("Post-modifier Adaptation = "+Adaptation);
	//Account for partiality
	//Adaptation *= evt.partiality;
	//print("Damage partiality = "+evt.partiality);
	//print("Post-partiality Adaptation = "+Adaptation);
	//Reduce damage
	//if(Adaptation > 0)  {
		//evt.damage *= 1-Adaptation/100;
	//}
	//print("Adapted damage = "+evt.damage);	
	//ship.Adaptation = min(ship.Adaptation+(AdaptationRate*ship.AdaptationFactor)/evt.partiality, AdaptationMax);
	//ship.Adaptation = min(ship.Adaptation+(AdaptationRate*ship.AdaptationFactor)*evt.partiality, AdaptationMax);
	return DE_Continue;
}

void DOFBorgAssimilationRay(Event& evt, double Amount, double Pierce, double Bypass, double IgnoreDR) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.custom1 = Bypass;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Energy | DF_FullDR | ReachedInternals | DF_BorgAssimilationRay;

	if(IgnoreDR != 0)
		dmg.flags |= DF_IgnoreDR;

	evt.target.damage(dmg, -1.0, evt.direction);
	
	//if(dmg.flags & ReachedInternals != 0 && evt.target.isShip)
	//	cast<Ship>(evt.target).startFire();
}