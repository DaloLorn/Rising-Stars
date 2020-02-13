// Infrastructure
// ------
// Manages building basic structures in newly colonized or weakened systems
// to support the Military or Colonization components.
//
import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Events;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Development;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;

import ABEM_data;
import util.lookup;
import ai.construction;
import ai.events;

from ai.orbitals import RegisterForTradeUse;

from statuses import getStatusID;
from traits import getTraitID;

enum ResourcePreference {
	RP_None,
	RP_FoodWater,
	RP_Level0,
	RP_Level1,
	RP_Level2,
	RP_Level3,
	RP_Scalable,
};

enum SystemArea {
	SA_Core,
	SA_Tradable,
};

enum SystemBuildAction {
	BA_BuildOutpost,
};

enum PlanetBuildAction {
	BA_BuildMoonBase,
};

enum SystemBuildLocation {
	BL_InSystem,
	BL_AtSystemEdge,
	BL_AtBestPlanet,
};

enum FocusType {
	FT_None,
	FT_Outpost,
}

int moonBaseStatusId = -1;

final class OwnedSystemEvents : IOwnedSystemEvents {
	Infrastructure@ infrastructure;

	OwnedSystemEvents(Infrastructure& infrastructure) {
		 @this.infrastructure = infrastructure;
	}

	void onOwnedSystemAdded(SystemAI& ai) {
		infrastructure.registerOwnedSystemAdded(ai);
	}

	void onOwnedSystemRemoved(SystemAI& ai) {
		infrastructure.registerOwnedSystemRemoved(ai);
	}
};

final class OutsideBorderSystemEvents : IOutsideBorderSystemEvents {
	Infrastructure@ infrastructure;

	OutsideBorderSystemEvents(Infrastructure& infrastructure) {
		@this.infrastructure = infrastructure;
	}

	void onOutsideBorderSystemAdded(SystemAI& ai) {
		infrastructure.registerOutsideBorderSystemAdded(ai);
	}

	void onOutsideBorderSystemRemoved(SystemAI& ai) {
		infrastructure.registerOutsideBorderSystemRemoved(ai);
	}
};

final class PlanetEvents : IPlanetEvents {
	Infrastructure@ infrastructure;

	PlanetEvents(Infrastructure& infrastructure) {
		@this.infrastructure = infrastructure;
	}

	void onPlanetAdded(PlanetAI& ai) {
		infrastructure.registerPlanetAdded(ai);
	}

	void onPlanetRemoved(PlanetAI& ai) {
		infrastructure.registerPlanetRemoved(ai);
	}
};

final class TradeRouteEvents : ITradeRouteEvents {
	Infrastructure@ infrastructure;

	TradeRouteEvents(Infrastructure& infrastructure) {
		@this.infrastructure = infrastructure;
	}

	void onTradeRouteNeeded(ref& sender, EventArgs& args) {
		TradeRouteNeededEventArgs@ specs = cast<TradeRouteNeededEventArgs>(args);
		if (specs !is null)
			infrastructure.establishTradeRoute(specs.territoryA, specs.territoryB);
	}
}

final class OrbitalRequestEvents : IOrbitalRequestEvents {
	Infrastructure@ infrastructure;

	OrbitalRequestEvents(Infrastructure& infrastructure) {
		@this.infrastructure = infrastructure;
	}

	void onOrbitalRequested(ref& sender, EventArgs& args) {
		OrbitalRequestedEventArgs@ specs = cast<OrbitalRequestedEventArgs>(args);
		if (specs !is null)
			infrastructure.requestOrbital(specs.region, specs.module, specs.priority, specs.expires, specs.moneyType);
	}
}

final class SystemOrder {
	private IConstruction@ _construction;

	double expires = INFINITY;

	SystemOrder() {}

	SystemOrder(IConstruction@ construction) {
		@_construction = (construction);
	}

	bool get_isValid() const { return _construction !is null; }

	bool get_isInProgress() const { return _construction.started; }

	bool get_isComplete() const { return _construction.completed; }

	IConstruction@ get_info() const { return _construction; }

	void save(Infrastructure& infrastructure, SaveFile& file) {
		file << _construction.id;
		file << expires;
	}

	void load(Infrastructure& infrastructure, SaveFile& file) {
		int id = - 1;
		file >> id;
		if (id != -1) {
			for (uint i = 0, cnt = infrastructure.construction.allocations.length; i < cnt; ++i) {
				if (infrastructure.construction.allocations[i].id == id) {
					@_construction = infrastructure.construction.allocations[i];
				}
			}
		}
		file >> expires;
	}
};

final class PlanetOrder {
	private IConstruction@ _construction;

	double expires = INFINITY;

	PlanetOrder() {}

	PlanetOrder(IConstruction@ construction) {
		@_construction = construction;
	}

	bool get_isValid() const { return _construction !is null; }

	bool get_isInProgress() const { return _construction.started; }

	bool get_isComplete() const { return _construction.completed; }

	IConstruction@ get_info() const { return _construction; }

	void save(Infrastructure& infrastructure, SaveFile& file) {
		file << _construction.id;
		file << expires;
	}

	void load(Infrastructure& infrastructure, SaveFile& file) {
		int id = - 1;
		file >> id;
		if (id != -1) {
			for (uint i = 0, cnt = infrastructure.planets.constructionRequests.length; i < cnt; ++i) {
				if (infrastructure.planets.constructionRequests[i].id == id) {
					@_construction = infrastructure.planets.constructionRequests[i];
				}
			}
		}
		file >> expires;
	}
};

abstract class NextAction {
	double priority = 1.0;
	bool force = false;
	bool critical = false;
};

final class SystemAction : NextAction {
	private SystemCheck@ _sys;
	private SystemBuildAction _action;
	private SystemBuildLocation _loc;

	SystemAction(SystemCheck& sys, SystemBuildAction action, SystemBuildLocation loc) {
		@_sys = sys;
		_action = action;
		_loc = loc;
	}

	SystemCheck@ get_sys() const { return _sys; }
	SystemBuildAction get_action() const { return _action; }
	SystemBuildLocation get_loc() const { return _loc; }
};

final class PlanetAction : NextAction {
	private PlanetCheck@ _pl;
	private PlanetBuildAction _action;

	PlanetAction(PlanetCheck& pl, PlanetBuildAction action) {
		@_pl = pl;
		_action = action;
	}

	PlanetCheck@ get_pl() const { return _pl; }
	PlanetBuildAction get_action() const { return _action; }
};

abstract class Check {
	protected double _checkInTime = 0.0;

	Check() {
		_checkInTime = gameTime;
	}

	double get_checkInTime() const { return _checkInTime; }
}

namespace SystemCheck {
	array<SystemOrder@> allOrders;
}

final class SystemCheck : Check {
	SystemAI@ ai;

	array<SystemOrder@> orders;

	private double _weight = 0.0;
	private bool _isUnderAttack = false;
	private int _nebulaFlag = -1;

	SystemCheck() {}

	SystemCheck(Infrastructure& infrastructure, SystemAI& ai) {
		super();
		@this.ai = ai;
	}

	double get_weight() const { return _weight; }
	bool get_isUnderAttack() const { return _isUnderAttack; }
	bool get_isBuilding() const { return orders.length > 0; }

	void save(Infrastructure& infrastructure, SaveFile& file) {
		infrastructure.systems.saveAI(file, ai);

		uint cnt = orders.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			orders[i].save(infrastructure, file);

		file << _checkInTime;
		file << _weight;
		file << _isUnderAttack;
	}

	void load(Infrastructure& infrastructure, SaveFile& file) {
		@ai = infrastructure.systems.loadAI(file);

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ order = SystemOrder();
			order.load(infrastructure, file);
			if (order.isValid)
				addOrder(order);
		}
		file >> _checkInTime;
		file >> _weight;
		file >> _isUnderAttack;
	}

	void tick(AI& ai, Infrastructure& infrastructure, double time) {
		OrbitalAI@ orbital;
		//Update hostile status
		_isUnderAttack = this.ai.obj.ContestedMask & ai.mask != 0;

		//Cancel all orders if attacked
		/*if (isUnderAttack && isBuilding) {
			for (uint i = 0, cnt = orders.length; i < cnt; ++i) {
				auto@ order = orders[i];
				//SoI - TODO: Cancel not fully implemented, see Construction.as
				infrastructure.construction.cancel(order.info);
				removeOrder(order);
				--i; --cnt;
			}
		}*/

		if (isBuilding) {
			for (uint i = 0, cnt = orders.length; i < cnt; ++i) {
				auto@ order = orders[i];
				if (!order.isValid) {
					removeOrder(order);
					--i; --cnt;
				}
				else if (order.isComplete) {
					if (infrastructure.log)
						ai.print("order complete");
					removeOrder(order);
					--i; --cnt;
				}
				else if (!order.isInProgress && order.expires < gameTime) {
					if (infrastructure.log)
						ai.print("order expired, gameTime = " + gameTime);
					removeOrder(order);
					--i; --cnt;
				}
			}
		}
	}

	void focusTick(AI& ai, Infrastructure& infrastructure, double time) {
	}

	double check(AI& ai) {
		_weight = 0.0;
		//Dangerous nebulae should always be ignored
		if (nebulaFlag != -1) {
			if (Lookup(nebulaFlag).isIn(array<int> = {
					METREON_NEBULA_FLAG,
					RADIOACTIVE_NEBULA_FLAG
				})) {
				//Not in dangerous nebulae
				return weight;
			}
		}
		//Systems under attack are bottom priority for now
		if (isUnderAttack)
				return weight;
		//Hostile systems are bottom priority until cleared
		if (this.ai.seenPresent & ai.enemyMask != 0)
			return weight;
		//Remnants are considered hostile but ignored in nebulae
		if (this.ai.pickupProtectors.length > 0 && this.nebulaFlag == -1)
			return weight;
		//Start weighting
		double sysWeight = 1.0;
		//Oldest systems come first
		sysWeight /= (checkInTime + 60.0) / 60.0;
		//The home system is a priority
		if (this.ai.obj is ai.empire.HomeSystem)
			sysWeight *= 2.0;
		else if (nebulaFlag != -1) {
			//The best nebulae
			if (Lookup(nebulaFlag).isIn(array<int> = {
					TACHYON_NEBULA_FLAG
				})) {
					sysWeight *= 1.8;
			}
			//The average nebulae
			else if (Lookup(nebulaFlag).isIn(array<int> = {
					CERULEAN_NEBULA_FLAG,
					ECONOMIC_NEBULA_FLAG,
					METAPHASIC_NEBULA_FLAG,
					MUTARA_NEBULA_FLAG,
					TYPE_1_NEBULA_FLAG
				})) {
					sysWeight *= 1.5;
			}
			//Meh
			else if (Lookup(nebulaFlag).isIn(array<int> = {
					EMPTY_SPACE_NEBULA_FLAG
				})) {
					sysWeight *= 0.5;
			}
		}
		_weight = 1.0 * sysWeight;
		return weight;
	}

	SystemOrder@ buildInSystem(Infrastructure& infrastructure, const OrbitalModule@ module, double priority = 1.0, bool force = false, double delay = 600.0, uint moneyType = BT_Infrastructure) {
		vec3d pos = ai.obj.position;
		vec2d offset = random2d(ai.obj.radius * 0.4, ai.obj.radius * 0.7);
		pos.x += offset.x;
		pos.z += offset.y;

		BuildOrbital@ orbital = infrastructure.construction.buildOrbital(module, pos, priority, force, moneyType);
		auto@ order = SystemOrder(orbital);
		order.expires = gameTime + delay;
		addOrder(order);

		return order;
	}

	SystemOrder@ buildAtSystemEdge(Infrastructure& infrastructure, const OrbitalModule@ module, double priority = 1.0, bool force = false, double delay = 600.0, uint moneyType = BT_Infrastructure) {
		vec3d pos = ai.obj.position;
		vec2d offset = random2d(ai.obj.radius * 0.8, ai.obj.radius * 0.9);
		pos.x += offset.x;
		pos.z += offset.y;

		BuildOrbital@ orbital = infrastructure.construction.buildOrbital(module, pos, priority, force, moneyType);
		auto@ order = SystemOrder(orbital);
		order.expires = gameTime + delay;
		addOrder(order);

		return order;
	}

	SystemOrder@ buildAtPlanet(Infrastructure& infrastructure, Planet& planet, const OrbitalModule@ module, double priority = 1.0, bool force = false, double delay = 600.0, uint moneyType = BT_Infrastructure) {
		BuildOrbital@ orbital = infrastructure.construction.buildLocalOrbital(module, planet, priority, force, moneyType);
		auto@ order = SystemOrder(orbital);
		order.expires = gameTime + delay;
		addOrder(order);

		return order;
	}

	void addOrder(SystemOrder@ order) {
		orders.insertLast(order);
		SystemCheck::allOrders.insertLast(order);
	}

	void removeOrder(SystemOrder@ order) {
		orders.remove(order);
		SystemCheck::allOrders.remove(order);
		@order = null;
	}
};

namespace PlanetCheck {
	array<PlanetOrder@> allOrders;
}

final class PlanetCheck : Check {
	PlanetAI@ ai;

	array<PlanetOrder@> orders;

	private double _weight = 0.0;
	private bool _isSystemUnderAttack = false;

	PlanetCheck() {}

	PlanetCheck(Infrastructure& infrastructure, PlanetAI& ai) {
		super();
		@this.ai = ai;
	}

	double get_weight() const { return _weight; }
	bool get_isSystemUnderAttack() const { return _isSystemUnderAttack; }
	bool get_isBuilding() const { return orders.length > 0; }

	void save(Infrastructure& infrastructure, SaveFile& file) {
		infrastructure.planets.saveAI(file, ai);

		uint cnt = orders.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			orders[i].save(infrastructure, file);

		file << _checkInTime;
		file << _weight;
		file << _isSystemUnderAttack;
	}

	void load(Infrastructure& infrastructure, SaveFile& file) {
		@ai = infrastructure.planets.loadAI(file);

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ order = PlanetOrder();
			order.load(infrastructure, file);
			if (order.isValid)
				addOrder(order);
		}
		file >> _checkInTime;
		file >> _weight;
		file >> _isSystemUnderAttack;
	}

	void tick(AI& ai, Infrastructure& infrastructure, double time) {
		auto@ sysAI = infrastructure.systems.getAI(this.ai.obj.region);
		if (sysAI !is null)
			_isSystemUnderAttack = sysAI.obj.ContestedMask & ai.mask != 0;

		if (isBuilding) {
			for (uint i = 0, cnt = orders.length; i < cnt; ++i) {
				auto@ order = orders[i];
				if (!order.isValid) {
					removeOrder(order);
					--i; --cnt;
				}
				else if (order.isComplete) {
					if (infrastructure.log)
						ai.print("planet order complete");
					removeOrder(order);
					--i; --cnt;
				}
				else if (!order.isInProgress && order.expires < gameTime) {
					if (infrastructure.log)
						ai.print("planet order expired, gameTime = " + gameTime);
					removeOrder(order);
					--i; --cnt;
				}
			}
		}
	}

	void focusTick(AI& ai, Infrastructure& infrastructure, double time) {
	}

	double check(AI& ai) {
		_weight = 0.0;
		//Planets in systems under attack are bottom priority for now
		if (isSystemUnderAttack)
				return _weight;
		//Start weighting
		double plWeight = 1.0;
		//Oldest planets come first
		plWeight /= (checkInTime + 60.0) / 60.0;
		//The homeworld is a priority
		if (this.ai.obj is ai.empire.Homeworld)
			plWeight *= 2.0;

		_weight = 1.0 * plWeight;
		return _weight;
	}

	PlanetOrder@ build(Infrastructure& infrastructure, const ConstructionType@ consType, double priority = 1.0, bool force = false, bool critical = false, double delay = 600.0, uint moneyType = BT_Infrastructure) {
			ConstructionRequest@ request = infrastructure.planets.requestConstruction(ai, ai.obj, consType, priority, gameTime + delay, moneyType);
			auto@ order = PlanetOrder(request);
			order.expires = gameTime + delay;
			addOrder(order);

			return order;
	}

	void addOrder(PlanetOrder@ order) {
		orders.insertLast(order);
		PlanetCheck::allOrders.insertLast(order);
	}

	void removeOrder(PlanetOrder@ order) {
		orders.remove(order);
		PlanetCheck::allOrders.remove(order);
		@order = null;
	}
};

final class TradeRoute {
	private Territory@ _territoryA;
	private Territory@ _territoryB;
	private Region@ _endpointA;
	private Region@ _endpointB;
	private SystemOrder@ _orderA;
	private SystemOrder@ _orderB;
	private bool _isEstablishing;
	private bool _isWaitingForLabor;
	private double _delay;
	private double _sleep;

	TradeRoute() {}

	TradeRoute(Territory& territoryA, Territory& territoryB) {
		@_territoryA = territoryA;
		@_territoryB = territoryB;
		_isEstablishing = false;
		_isWaitingForLabor = false;
		_delay = 0.0;
		_sleep = 0.0;
	}

	Territory@ get_territoryA() const { return _territoryA; }
	Territory@ get_territoryB() const { return _territoryB; }
	Region@ get_endpointA() const { return _endpointA; }
	Region@ get_endpointB() const { return _endpointB; }
	SystemOrder@ get_orderA() const { return _orderA; }
	SystemOrder@ get_orderB() const { return _orderB; }
	bool get_isEstablishing() const { return _isEstablishing; }
	bool get_isWaitingForLabor() const { return _isWaitingForLabor; }

	void save(Infrastructure& infrastructure, SaveFile& file) {
	}

	void load(Infrastructure& infrastructure, SaveFile& file) {
	}

	void tick(AI& ai, Infrastructure& infrastructure, double time) {
		if (_delay > 0.0 && _delay < gameTime) {
			_isWaitingForLabor = false;
			_delay = 0.0;
		}
	}

	void focusTick(AI& ai, Infrastructure& infrastructure, double time) {
	}

	bool canEstablish(Infrastructure& infrastructure, bool&out buildAtA, bool&out canBuildAtA, bool&out buildAtB, bool&out canBuildAtB) {
		//We're still sleeping
		if (_sleep > gameTime)
			return false;
		//At least one building order is still pending
		if (orderA !is null || orderB !is null)
			return false;

		buildAtA = true;
		buildAtB = true;
		canBuildAtA = false;
		canBuildAtB = false;
		for (uint i = 0, cnt = infrastructure.checkedPlanets.length; i < cnt; ++i) {
			Planet@ pl = infrastructure.checkedPlanets[i].ai.obj;
			if (pl.region !is null) {
				Territory@ t = pl.region.getTerritory(infrastructure.ai.empire);
				if (t is territoryA) {
					//Is there a global trade node here already
					if (pl.region.GateMask & ~pl.owner.mask != 0) {
						buildAtA = false;
						@_endpointA = pl.region;
					}
					if (!canBuildAtA) {
						//Is there a labor source in this territory
						if (pl.laborIncome > 0 && pl.canBuildOrbitals)
							canBuildAtA = true;
					}
				}
				else if (t is territoryB) {
					//Is there a global trade node here already
					if (pl.region.GateMask & ~pl.owner.mask != 0) {
						buildAtB = false;
						@_endpointB = pl.region;
					}
					if (!canBuildAtB) {
						//Is there a labor source in this territory
						if (pl.laborIncome > 0 && pl.canBuildOrbitals)
							canBuildAtB = true;
					}
				}
				if (!buildAtA && !buildAtB) {
					//Should not normally happen, except if trade if somehow disrupted despite global trade nodes
					return false;
				}
				if (canBuildAtA && canBuildAtB) {
					_isWaitingForLabor = false;
					return true;
				}
			}
		}
		//These checks are expensive and don't need to be run frequently, so let's sleep for some time
		_sleep = gameTime + 10.0;
		return false;
	}

	void establish(Infrastructure& infrastructure, Region@ regionA, Region@ regionB) {
		SystemOrder@ orderA = null;
		SystemOrder@ orderB = null;
		if (regionA !is null) {
			@orderA = infrastructure.requestOrbital(regionA, infrastructure.ai.defs.TradeStation);
			@_endpointA = regionA;
		}
		if (regionB !is null) {
			@orderB = infrastructure.requestOrbital(regionB, infrastructure.ai.defs.TradeStation);
			@_endpointB = regionB;
		}
		if (orderA is null || orderB is null) {
			infrastructure.ai.print("ERROR: could not establish trade route between " + regionA.name + " and " + regionB.name);
			return;
		}
		@_orderA = orderA;
		@_orderB = orderB;
		_isEstablishing = true;
	}

	void waitForLabor(double expires) {
		_isWaitingForLabor = true;
		_delay = gameTime + expires;
	}
}

final class Infrastructure : AIComponent {
	const ResourceClass@ foodClass, waterClass, scalableClass;

	//Current focus
	private uint _focus = FT_None;

	Events@ events;
	Colonization@ colonization;
	Development@ development;
	Construction@ construction;
	Orbitals@ orbitals;
	Planets@ planets;
	Systems@ systems;
	Budget@ budget;
	Resources@ resources;

	array<SystemCheck@> checkedOwnedSystems; //Includes border systems
	array<SystemCheck@> checkedOutsideSystems;
	array<PlanetCheck@> checkedPlanets;

	array<TradeRoute@> pendingRoutes;

	SystemCheck@ homeSystem;
	NextAction@ nextAction;

	//Unlock tracking
	bool canBuildGate = false;
	bool canBuildMoonBase = true;

	void create() {
		@events = cast<Events>(ai.events);
		@colonization = cast<Colonization>(ai.colonization);
		@development = cast<Development>(ai.development);
		@construction = cast<Construction>(ai.construction);
		@orbitals = cast<Orbitals>(ai.orbitals);
		@planets = cast<Planets>(ai.planets);
		@systems = cast<Systems>(ai.systems);
		@budget = cast<Budget>(ai.budget);
		@resources = cast<Resources>(ai.resources);

		//Cache expensive lookups
		@foodClass = getResourceClass("Food");
		@waterClass = getResourceClass("WaterType");
		@scalableClass = getResourceClass("Scalable");
		moonBaseStatusId = getStatusID("MoonBase");

		events += OwnedSystemEvents(this);
		events += OutsideBorderSystemEvents(this);
		events += PlanetEvents(this);
		events += TradeRouteEvents(this);

		if (ai.empire.hasTrait(getTraitID("Gate")))
			canBuildGate = true;
		if (ai.empire.hasTrait(getTraitID("StarChildren")))
			canBuildMoonBase = false;
	}

	void save(SaveFile& file) {
		file << _focus;
		uint cnt = checkedOwnedSystems.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			checkedOwnedSystems[i].save(this, file);
		cnt = checkedOutsideSystems.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			checkedOutsideSystems[i].save(this, file);
		cnt = checkedPlanets.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			checkedPlanets[i].save(this, file);
	}

	void load(SaveFile& file) {
		file >> _focus;
		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			SystemCheck@ sys = SystemCheck();
			sys.load(this, file);
			checkedOwnedSystems.insertLast(sys);
		}
		cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			SystemCheck@ sys = SystemCheck();
			sys.load(this, file);
			checkedOutsideSystems.insertLast(sys);
		}
		cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			PlanetCheck@ pl = PlanetCheck();
			pl.load(this, file);
			checkedPlanets.insertLast(pl);
		}
	}

	void start() {
	}

	void turn() {
		if(log) {
			ai.print("==============");
			ai.print("Current owned systems checked: " + checkedOwnedSystems.length);
			for (uint i = 0, cnt = checkedOwnedSystems.length; i < cnt; ++i)
				ai.print(checkedOwnedSystems[i].ai.obj.name);
			ai.print("==============");
			ai.print("Current outside border systems checked: " + checkedOutsideSystems.length);
			for (uint i = 0, cnt = checkedOutsideSystems.length; i < cnt; ++i)
				ai.print(checkedOutsideSystems[i].ai.obj.name);
			ai.print("==============");
			ai.print("Current owned planets checked: " + checkedPlanets.length);
			for (uint i = 0, cnt = checkedPlanets.length; i < cnt; ++i)
				ai.print(checkedPlanets[i].ai.obj.name);
			ai.print("==============");
		}

		//Reset any focus
		_focus = FT_None;
		//If colonization is somehow blocked, force territory expansion by focusing on building outposts
		if (colonization.needsMoreTerritory){
			if (budget.canFocus()) {
				budget.focus(BT_Infrastructure);
				_focus = FT_Outpost;
			}
		}
	}

	void tick(double time) override {
		SystemCheck@ sys;
		PlanetCheck@ pl;
		TradeRoute@ route;
		//Perform routine duties
		for (uint i = 0, cnt = checkedOwnedSystems.length; i < cnt; ++i) {
			@sys = checkedOwnedSystems[i];
			sys.tick(ai, this, time);
		}
		for (uint i = 0, cnt = checkedOutsideSystems.length; i < cnt; ++i) {
			@sys = checkedOutsideSystems[i];
			sys.tick(ai, this, time);
		}
		for (uint i = 0, cnt = checkedPlanets.length; i < cnt; ++i) {
			@pl = checkedPlanets[i];
			pl.tick(ai, this, time);
		}
		for (uint i = 0, cnt = pendingRoutes.length; i < cnt; ++i) {
			@route = pendingRoutes[i];
			route.tick(ai, this, time);
		}
	}

	void focusTick(double time) override {
		SystemCheck@ sys;
		PlanetCheck@ pl;
		SystemBuildLocation loc;

		bool critical = false;
		double w;
		double bestWeight = 0.0;

		//Check if owned systems need anything
		for (uint i = 0, cnt = checkedOwnedSystems.length; i < cnt; ++i) {
			@sys = checkedOwnedSystems[i];
			//Only consider anything if no critical action is underway
			if (!critical) {
				//Evaluate current weight
				w = sys.check(ai);
				if (w > bestWeight) {
					if (_focus == FT_None || _focus == FT_Outpost) {
						//Check if an outpost is needed
						if (shouldHaveOutpost(sys, SA_Core, loc)) {
							@nextAction = SystemAction(sys, BA_BuildOutpost, loc);
							bestWeight = w;
							if (log)
								ai.print("outpost considered for owned system with weight: " + w, sys.ai.obj);
						}
					}
				}
			}
			//Perform routine duties
			sys.focusTick(ai, this, time);
		}
		//Check if systems in tradable area need anything
		for (uint i = 0, cnt = checkedOutsideSystems.length; i < cnt; ++i) {
			@sys = checkedOutsideSystems[i];
			//Skip unexplored systems
			if (sys.ai.explored) {
				//Only consider anything if no critical action is underway
				if (!critical) {
					//Evaluate current weight
					w = sys.check(ai);
					if (w > bestWeight) {
						if (_focus == FT_None || _focus == FT_Outpost) {
							//Check if an outpost is needed
							if (shouldHaveOutpost(sys, SA_Tradable, loc)) {
								@nextAction = SystemAction(sys, BA_BuildOutpost, loc);
								bestWeight = w;
								if (log)
									ai.print("outpost considered for outside system with weight: " + w, sys.ai.obj);
							}
						}
					}
				}
			}
			//Perform routine duties
			sys.focusTick(ai, this, time);
		}
		//Check if owned planets need anything
		for (uint i = 0, cnt = checkedPlanets.length; i < cnt; ++i) {
			@pl = checkedPlanets[i];
			//Only consider anything if no critical action is underway
			if (!critical) {
				//Planets are their own 'factory' and can only build one construction at a time
				if (!pl.isBuilding) {
					//Evaluate current weight
					w = pl.check(ai);
					if (w > bestWeight) {
						//Check if a moon base is needed
						if (canBuildMoonBase && shouldHaveMoonBase(pl)) {
							@nextAction = PlanetAction(pl, BA_BuildMoonBase);
							bestWeight = w;
							if (log)
								ai.print("moon base considered with weight: " + w, pl.ai.obj);
						}
					}
				}
			}
			//Perform routine duties
			pl.focusTick(ai, this, time);
		}
		//Execute our next action if there is one
		if (nextAction !is null) {
			Object@ obj;
			auto@ next = cast<SystemAction>(nextAction);
			if (next !is null)
			{
				@sys = next.sys;
				switch (next.action) {
					case BA_BuildOutpost:
						switch (next.loc) {
							case BL_InSystem:
								sys.buildInSystem(this, ai.defs.EconomyCore, next.priority, next.force);
								break;
							case BL_AtSystemEdge:
								sys.buildAtSystemEdge(this, ai.defs.EconomyCore, next.priority, next.force);
								break;
							case BL_AtBestPlanet:
									@obj = getBestPlanet(sys);
									if (obj !is null) {
										sys.buildAtPlanet(this, cast<Planet>(obj), ai.defs.EconomyCore, next.priority, next.force);
									}
								break;
							default:
								ai.print("ERROR: undefined infrastructure building location for outpost");
						}
						if (log)
							ai.print("outpost ordered", sys.ai.obj);
						break;
					default:
						ai.print("ERROR: undefined infrastructure building action for system");
				}
			}
			else {
				auto@ next = cast<PlanetAction>(nextAction);
				if (next !is null) {
					@pl = next.pl;
					switch (next.action) {
						case BA_BuildMoonBase:
							pl.build(this, ai.defs.MoonBase, next.priority, next.force, next.critical);
							if (log)
								ai.print("moon base ordered", pl.ai.obj);
							break;
						default:
							ai.print("ERROR: undefined infrastructure building action for planet");
					}
				}
			}

			@nextAction = null;
		}

		//Manage any pending trading routes
		TradeRoute@ route;
		for (uint i = 0, cnt = pendingRoutes.length; i < cnt; ++i) {
			@route = pendingRoutes[i];

			if (route.territoryA is null || route.territoryB is null) {
				pendingRoutes.remove(route);
				--i; --cnt;
				if (log)
					ai.print("invalid territory for pending route, route canceled");
			}

			bool buildAtA = true;
			bool canBuildAtA = false;
			bool buildAtB = true;
			bool canBuildAtB = false;

			if (route.canEstablish(this, buildAtA, canBuildAtA, buildAtB, canBuildAtB)) {
				Region@ regionA = null;
				Region@ regionB = null;
				if (buildAtA)
					@regionA = getRouteEndpoint(route.territoryA);
				if (buildAtB)
					@regionB = getRouteEndpoint(route.territoryB);
				if (regionA !is null && regionB !is null) {
					route.establish(this, regionA, regionB);
					if (log)
						ai.print("trade route establishing between " + regionA.name + " and " + regionB.name);
				}
			}
			else if (!route.isEstablishing && !route.isWaitingForLabor) {
				Region@ regionA = null;
				Region@ regionB = null;
				double expires = 0.0;
				if (!canBuildAtA)
					@regionA = getLaborAt(route.territoryA, expires);
				if (!canBuildAtB)
					@regionB = getLaborAt(route.territoryB, expires);
				route.waitForLabor(expires);
				if (log) {
					string location = "";
					if (!canBuildAtA && regionA !is null)
						location += " " + regionA.name;
					if (!canBuildAtB && regionB !is null) {
						if (location != "")
							location += ", ";
						location += " " + regionB.name;
					}
					if (location == "")
						ai.print("trade route unable to get labor");
					else
						ai.print("trade route waiting for labor at:" + location);
				}
			}
			if (route.endpointA !is null && route.endpointB !is null && resources.canTradeBetween(route.endpointA, route.endpointB)) {
				pendingRoutes.remove(route);
				--i; --cnt;
				if (log)
					ai.print("trade route established between " + addrstr(route.territoryA) + " and " + addrstr(route.territoryB));
			}
			//Perform routine duties
			route.focusTick(ai, this, time);
		}
	}

	void registerOwnedSystemAdded(SystemAI& sysAI) {
		auto@ sys = SystemCheck(this, sysAI);
		checkedOwnedSystems.insertLast(sys);
		if (log)
			ai.print("adding owned system: " + sysAI.obj.name);
	}

	void registerOwnedSystemRemoved(SystemAI& sysAI) {
		for (uint i = 0, cnt = checkedOwnedSystems.length; i < cnt; ++i) {
			if (sysAI is checkedOwnedSystems[i].ai) {
				checkedOwnedSystems.removeAt(i);
				break;
			}
		}
		if (log)
			ai.print("removing owned system: " + sysAI.obj.name);
	}

	void registerOutsideBorderSystemAdded(SystemAI& sysAI) {
		auto@ sys = SystemCheck(this, sysAI);
		checkedOutsideSystems.insertLast(sys);
		if (log)
			ai.print("adding outside system: " + sysAI.obj.name);
	}

	void registerOutsideBorderSystemRemoved(SystemAI& sysAI) {
		for (uint i = 0, cnt = checkedOutsideSystems.length; i < cnt; ++i) {
			if (sysAI is checkedOutsideSystems[i].ai) {
				checkedOutsideSystems.removeAt(i);
				break;
			}
		}
		if (log)
			ai.print("removing outside system: " + sysAI.obj.name);
	}

	void registerPlanetAdded(PlanetAI& plAI) {
		auto@ pl = PlanetCheck(this, plAI);
		checkedPlanets.insertLast(pl);
		if (log)
			ai.print("adding planet: " + plAI.obj.name);
	}

	void registerPlanetRemoved(PlanetAI& plAI) {
		for (uint i = 0, cnt = checkedPlanets.length; i < cnt; ++i) {
			if (plAI is checkedPlanets[i].ai) {
				checkedPlanets.removeAt(i);
				break;
			}
		}
		if (log)
			ai.print("removing planet: " + plAI.obj.name);
	}

	void establishTradeRoute(Territory@ territoryA, Territory@ territoryB) {
		if (canBuildGate)
			return;
		if (hasPendingTradeRoute(territoryA, territoryB)) {
			if (log)
				ai.print("pending route detected between " + addrstr(territoryA) + " and " + addrstr(territoryB) + ", establishment canceled");
			return;
		}

		if (territoryA is null || territoryB is null) {
			if (log)
				ai.print("invalid territory for pending route, establishment canceled");
			return;
		}
		pendingRoutes.insertLast(TradeRoute(territoryA, territoryB));
		if (log)
			ai.print("establishing trade route between " + addrstr(territoryA) + " and " + addrstr(territoryB));
	}

	SystemOrder@ requestOrbital(Region@ region, const OrbitalModule@ module, double priority = 1.0, double expires = INFINITY, uint moneyType = BT_Infrastructure) {
		SystemAI@ sysAI = systems.getAI(region);
		if (sysAI !is null) {
			for (uint i = 0, cnt = checkedOwnedSystems.length; i < cnt; ++i) {
				if (sysAI is checkedOwnedSystems[i].ai)
					return checkedOwnedSystems[i].buildInSystem(this, module, priority, false, expires, moneyType);
			}
			ai.print("ERROR: requestOrbital: owned system not found: " + region.name);
			return null;
		}
		return null;
	}

	bool shouldHaveOutpost(SystemCheck& sys, SystemArea area, SystemBuildLocation&out loc) const {
		loc = BL_InSystem;

		uint presentMask = sys.ai.seenPresent;
		//Make sure we did not previously built an outpost here
		if (orbitals.haveInSystem(ai.defs.EconomyCore, sys.ai.obj))
			return false;
		//Make sure we are not already building an outpost here
		if (isBuilding(sys, ai.defs.EconomyCore))
			return false;
		//Hostile systems should be ignored until cleared
		if (presentMask & ai.enemyMask != 0)
			return false;
		//Remnants are considered hostile but ignored in nebulae, clearing them can take ages
		if (sys.ai.pickupProtectors.length > 0 && sys.nebulaFlag == -1)
			return false;
		//Inhabited systems should be ignored if we're not aggressively expanding
		if(!ai.behavior.colonizeNeutralOwnedSystems && (presentMask & ai.neutralMask) != 0)
			return false;
		if(!ai.behavior.colonizeAllySystems && (presentMask & ai.allyMask) != 0)
			return false;
		//Nebulae should have an outpost so we can expand our territory beyond them
		if (sys.nebulaFlag != -1) {
			//Not in dangerous nebulae
			if (Lookup(sys.nebulaFlag).isIn(array<int> = {
					METREON_NEBULA_FLAG,
					RADIOACTIVE_NEBULA_FLAG
				})) {
				return false;
			}
			//Building at system edge to minimize risks of remnant fire
			loc = BL_AtSystemEdge;
			return true;
		}
		else {
			Planet@ planet;
			ResourceType@ type;

			switch(area) {
				//Owned systems should have an outpost
				case SA_Core:
					if (sys.ai.planets.length > 0)
						loc = BL_AtBestPlanet;
					return true;
				//Outside systems might have an outpost if they are of some interest
				case SA_Tradable:
					//The system has no planets but is not empty space, it needs an outpost to allow expansion
					if (sys.ai.planets.length == 0 && sys.nebulaFlag == -1)
						return true;
					else {
						@planet = getBestPlanet(sys, type);
						if (planet is null)
							break;
						loc = BL_AtBestPlanet;
						//The best planet is barren, the system needs an outpost to allow expansion
						int resId = planet.primaryResourceType;
						if (resId == -1)
							return true;
						//The best planet has either a scalable or level 3 or 2 resource, the system should have an outpost to dissuade other empires from colonizing it
						if (type !is null && (type.cls is scalableClass || type.level == 3 || type.level == 2))
							return true;
					}
					return false;
				default:
					return false;
			}
		}
		return false;
	}

	bool shouldHaveMoonBase(PlanetCheck& pl) const {
		if (pl.ai.obj.moonCount == 0)
			return false;
		//If the planet is at least level 2 and short on empty developed tiles, it should have a moon base
		else if (pl.ai.obj.resourceLevel > 1 && pl.ai.obj.emptyDevelopedTiles < 9)
			return true;

		return false;
	}

	Region@ getRouteEndpoint(Territory@ territory) {
		const OrbitalModule@ module = ai.defs.TradeStation;
		Region@ region = null;
		for (uint i = 0, cnt = module.ai.length; i < cnt; ++i) {
			auto@ hook = cast<RegisterForTradeUse>(module.ai[i]);
			if (hook !is null) {
				Object@ obj = hook.considerBuild(orbitals, module, territory);
				if (obj !is null) {
					@region = cast<Region>(obj);
					break;
				}
			}
		}
		return region;
	}

	Region@ getLaborAt(Territory@ territory, double&out expires) {
		expires = 600.0;

		if (territory is null) {
			if (log)
				ai.print("invalid territory to get labor at");
			return null;
		}
		//SoI - TODO: Handle more complex cases

		//Fallback solution: build a labor generation building
		Planet@ pl = development.getLaborAt(territory, expires);
		if (pl !is null)
			return pl.region;
		return null;
	}

	bool isBuilding(const OrbitalModule@ module) {
		for (uint i = 0, cnt = SystemCheck::allOrders.length; i < cnt; ++i) {
			auto@ orbital = cast<IOrbitalConstruction>(SystemCheck::allOrders[i].info);
			if (orbital !is null) {
				if (orbital.module is module)
					return true;
			}
		}
		return false;
	}

	bool isBuilding(SystemCheck& sys, const OrbitalModule@ module) {
		for (uint i = 0, cnt = sys.orders.length; i < cnt; ++i) {
			auto@ orbital = cast<IOrbitalConstruction>(sys.orders[i].info);
			if (orbital !is null) {
				if (orbital.module is module)
					return true;
			}
		}
		return false;
	}

	int identifyNebula(Region@ region) {
		if (region.getSystemFlag(ai.empire, CERULEAN_NEBULA_FLAG)) {
			if (log)
				ai.print("identified a cerulean nebula");
			return CERULEAN_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, ECONOMIC_NEBULA_FLAG)) {
			if (log)
				ai.print("identified an economic nebula");
			return ECONOMIC_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, EMPTY_SPACE_NEBULA_FLAG)) {
			if (log)
				ai.print("identified empty space");
			return EMPTY_SPACE_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, METAPHASIC_NEBULA_FLAG)) {
			if (log)
				ai.print("identified a metaphasic nebula");
			return METAPHASIC_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, METREON_NEBULA_FLAG)) {
			if (log)
				ai.print("identified a metreon nebula");
			return METREON_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, MUTARA_NEBULA_FLAG)) {
			if (log)
				ai.print("identified a mutara nebula");
			return MUTARA_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, RADIOACTIVE_NEBULA_FLAG)) {
			if (log)
				ai.print("identified a radioactive nebula");
			return RADIOACTIVE_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, TACHYON_NEBULA_FLAG)) {
			if (log)
				ai.print("identified a tachyon nebula");
			return TACHYON_NEBULA_FLAG;
		}
		else if (region.getSystemFlag(ai.empire, TYPE_1_NEBULA_FLAG)) {
			if (log)
				ai.print("identified a type 1 nebula");
			return TYPE_1_NEBULA_FLAG;
		}
		return NEBULA_FLAG;
	}

	Planet@ getBestPlanet(SystemCheck sys) {
		ResourceType@ type;
		return getBestPlanet(sys, type);
	}

	Planet@ getBestPlanet(SystemCheck sys, const ResourceType@ resourceType) {
		Planet@ bestPlanet, planet;
		ResourcePreference bestResource = RP_None;

		if (sys.ai.obj is ai.empire.HomeSystem) {
			//The homeworld if there is one
			@planet = ai.empire.Homeworld;
			if (planet !is null)
				return planet;
		}

		for (uint i = 0, cnt = sys.ai.planets.length; i < cnt; ++i) {
			@planet = sys.ai.planets[i];
			int resId = planet.primaryResourceType;
			if (resId == -1)
				continue;

			const ResourceType@ type = getResource(resId);
			//The first scalable resource
			if (type.cls is scalableClass) {
				@resourceType = type;
				return planet;
			}
			//The first level 3 resource
			if (type.level == 3) {
				bestResource = RP_Level3;
				@resourceType = type;
				@bestPlanet = planet;
			}
			//The first level 2 resource
			else if (type.level == 2 && RP_Level2 > bestResource) {
				bestResource = RP_Level2;
				@resourceType = type;
				@bestPlanet = planet;
			}
			//The first level 1 resource
			else if (type.level == 1 && RP_Level1 > bestResource) {
				bestResource = RP_Level1;
				@resourceType = type;
				@bestPlanet = planet;
			}
			//The first level 0 resource except food and water
			else if (type.level == 0 && type.cls !is foodClass && type.cls !is waterClass && RP_Level0 > bestResource) {
				bestResource = RP_Level0;
				@resourceType = type;
				@bestPlanet = planet;
			}
			//The first food or water resource
			else if ((type.cls is foodClass || type.cls is waterClass) && RP_Level0 > bestResource) {
				bestResource = RP_FoodWater;
				@resourceType = type;
				@bestPlanet = planet;
			}
			else if (i == sys.ai.planets.length - 1 && bestPlanet is null) {
				@resourceType = type;
				@bestPlanet = planet;
			}
		}

		if (bestPlanet is null)
			return planet;
		return bestPlanet;
	}
};

AIComponent@ createInfrastructure() {
	return Infrastructure();
}
