import regions.regions;
import saving;
import systems;

LightDesc lightDesc;

final class StarScript {
	bool hpDelta = false, shieldDelta = false, maxDelta = false;
	double maxHealth, maxShield;

	void syncInitial(const Star& star, Message& msg) {
		msg << float(star.temperature);
		star.writeOrbit(msg);
		star.writeStatuses(msg);
	}

	void save(Star& star, SaveFile& file) {
		saveObjectStates(star, file);
		file << star.temperature;
		file << cast<Savable>(star.Orbit);
		file << star.Health;
		file << star.MaxHealth;
		file << star.Shield;
		file << star.MaxShield;
		file << cast<Savable>(star.Statuses);
	}
	
	void load(Star& star, SaveFile& file) {
		loadObjectStates(star, file);
		file >> star.temperature;
		
		if(star.owner is null)
			@star.owner = defaultEmpire;

		lightDesc.att_quadratic = 1.f/(2000.f*2000.f);
		
		double temp = star.temperature;
		Node@ node;
		double soundRadius = star.radius;
		if(temp > 0.0) {
			@node = bindNode(star, "StarNode");
			node.color = blackBody(temp, max((temp + 15000.0) / 40000.0, 1.0));
		}
		else {
			@node = bindNode(star, "BlackholeNode");
			node.color = blackBody(16000.0, max((16000.0 + 15000.0) / 40000.0, 1.0));
			cast<BlackholeNode>(node).establish(star);
			soundRadius *= 10.0;
		}
		
		addAmbientSource(CURRENT_PLAYER, "star_rumble", star.id, star.position, soundRadius);

		if(file >= SV_0028)
			file >> cast<Savable>(star.Orbit);

		if(file >= SV_0102) {
			file >> star.Health;
			file >> star.MaxHealth;
			file >> star.Shield;
			file >> star.MaxShield;
			file >> cast<Savable>(star.Statuses);
		}

		lightDesc.position = vec3f(star.position);
		lightDesc.radius = star.radius;
		lightDesc.diffuse = node.color * 1.0f;
		if(temp <= 0)
			lightDesc.diffuse.a = 0.f;
		lightDesc.specular = lightDesc.diffuse;

		if(star.inOrbit)
			makeLight(lightDesc, node);
		else
			makeLight(lightDesc);
	}

	void syncDetailed(const Star& star, Message& msg) {
		msg << float(star.Health);
		msg << float(star.MaxHealth);
		msg << float(star.Shield);
		msg << float(star.MaxShield);
		star.writeStatuses(msg);
	}

	bool syncDelta(const Star& star, Message& msg) {
		bool used = false;
		msg.writeBit(maxDelta);
		if(maxDelta) {
			used = true;
			maxDelta = false;
			msg << float(star.MaxHealth);
			msg << float(star.MaxShield);
		}
		msg.writeBit(shieldDelta);
		if(shieldDelta) {
			used = true;
			shieldDelta = false;
			msg.writeFixed(star.Shield, 0.f, star.MaxShield, 16);
		}
		msg.writeBit(hpDelta);
		if(hpDelta) {
			used = true;
			hpDelta = false;
			msg.writeFixed(star.Health, 0.f, star.MaxHealth, 16);
		}
		if(star.writeStatusDelta(msg))
			used = true;
		else
			msg.write0();
		
		return used;
	}

	void postLoad(Star& star) {
		Node@ node = star.getNode();
		maxHealth = star.MaxHealth;
		maxShield = star.MaxShield;
		if(node !is null)
			node.hintParentObject(star.region, false);
	}
	
	void postInit(Star& star) {
		double soundRadius = star.radius;
		maxHealth = star.MaxHealth;
		maxShield = star.MaxShield;
		//Blackholes need a 'bigger' sound
		if(star.temperature == 0.0)
			soundRadius *= 10.0;
		addAmbientSource(CURRENT_PLAYER, "star_rumble", star.id, star.position, soundRadius);
	}
	
	void dealStarDamage(Star& star, double amount) {
		dealStarDamage(star, amount, star.position);
	}

	void dealStarDamage(Star& star, double amount, const vec3d attackerPosition) {
		if(star.Shield > 0) {
			shieldDelta = true;
			if(maxShield <= 0.0)
				maxShield = star.Shield;
				
			// This handles shield graphics.	
			if(star.position != attackerPosition) {
				double dmgScale = 0;
				dmgScale = (amount * star.Shield) / (maxShield * maxShield);
				if(dmgScale < 0.10) {
					//TODO: Simulate this effect on the client
					if(randomd() < dmgScale)
						playParticleSystem("ShieldImpactLight", star.position + attackerPosition.normalized(star.radius * 1.05), quaterniond_fromVecToVec(vec3d_front(), attackerPosition), star.radius, star.visibleMask, networked=false);
				}
				else if(dmgScale < 0.30) {
					playParticleSystem("ShieldImpactMedium", star.position + attackerPosition.normalized(star.radius * 1.05), quaterniond_fromVecToVec(vec3d_front(), attackerPosition), star.radius, star.visibleMask);
				}
				else {
					playParticleSystem("ShieldImpactHeavy", star.position + attackerPosition.normalized(star.radius * 1.05), quaterniond_fromVecToVec(vec3d_front(), attackerPosition), star.radius, star.visibleMask, networked=false);
				}
			}
			
			double tempVar = amount;
			tempVar = max(amount - star.Shield, 0.f);
			star.Shield -= amount;
			amount = tempVar;
			if(star.Shield < 0)
				star.Shield = 0;
			if(amount == 0.f)
				return;
		}
		hpDelta = true;
		star.Health -= amount;
		if(star.Health <= 0) {
			star.Health = 0;
			star.destroy();
		}
	}

	void destroy(Star& star) {
		if(!game_ending) {
			double explRad = star.radius;
			if(star.temperature == 0.0) {
				explRad *= 20.0;

				for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
					auto@ sys = getSystem(i);
					double dist = star.position.distanceTo(sys.position);
					if(dist < 100000.0) {
						double factor = sqr(1.0 - (dist / 100000));
						sys.object.addStarDPS(factor * star.MaxHealth * 0.08);
					}
				}
			}
			playParticleSystem("StarExplosion", star.position, star.rotation, explRad);
			
			//auto@ node = createNode("NovaNode");
			//if(node !is null)
			//	node.position = star.position;
			removeAmbientSource(CURRENT_PLAYER, star.id);
			if(star.region !is null)
				star.region.addSystemDPS(star.MaxHealth * 0.12);
		}
		star.destroyStatus();
		leaveRegion(star);
	}
	
	/*void damage(Star& star, DamageEvent& evt, double position, const vec2d& direction) {
		evt.damage -= 100.0;
		if(evt.damage > 0.0)
			star.HP -= evt.damage;
	}*/
	
	double tick(Star& obj, double time) {
		updateRegion(obj);
		obj.orbitTick(time);
		obj.statusTick(time);
		if(maxHealth != obj.MaxHealth) {
			maxHealth = obj.MaxHealth;
				if(obj.Health > obj.MaxHealth)
					obj.Health = obj.MaxHealth;
			maxDelta = true;
		}
		if(maxShield != obj.MaxShield) {
			maxShield = obj.MaxShield;
			if(obj.Shield > obj.MaxShield)
				obj.Shield = obj.MaxShield;
			maxDelta = true;
		}

		Region@ reg = obj.region;
		uint mask = ~0;
		if(reg !is null && obj.temperature > 0)
			mask = reg.ExploredMask.value;
		obj.donatedVision = mask;

		return 1.0;
	}
};
