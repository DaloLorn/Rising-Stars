from constructible import ConstructibleType;
from saving import SaveVersion;
from resources import MoneyType;

enum TickResult {
	TR_Remove,      //Remove this constructible from the queue
	TR_UsedLabor,   //Mark as using labor, use it
	TR_VanishLabor, //Don't mark as using labor, but use it (don't consume stored labor though)
	TR_UnusedLabor, //Don't mark as using labor, pass labor through
	// Finished spending labor, but still busy building;
	// mark as using labor as per TR_UsedLabor, then pass surplus labor through
	// as per TR_UnusedLabor (should then return TR_UnusedLabor on later ticks!)
	TR_PartialLabor, 
};

tidy class Constructible : Serializable {
	int id = -1;
	double curLabor = 0;
	double totalLabor = 1.0;
	int buildCost = 0;
	int maintainCost = 0;
	int budgetCycle = -1;
	bool started = false;
	bool paid = false;
	bool repeated = false;
	double finalizingTimer = 0;
	bool finalizing = false;

	string get_name() {
		return "(null)";
	}

	ConstructibleType get_type() {
		return CT_Invalid;
	}

	bool get_canComplete() {
		return true;
	}

	bool pay(Object& obj) {
		if(buildCost != 0) {
			budgetCycle = obj.owner.consumeBudget(buildCost, borrow=!repeated);
			if(budgetCycle == -1)
				return false;
		}
		paid = true;
		return true;
	}

	bool start(Object& obj) {
		if(started)
			return true;
		if(maintainCost != 0)
			obj.owner.modMaintenance(maintainCost, MoT_Construction);
		started = true;
		return true;
	}

	void changeOwner(Empire@ prevOwner, Empire@ newOwner) {
		if (started && maintainCost != 0) { // Transfer maintenance costs!
			if (prevOwner !is null && prevOwner.valid) {
				prevOwner.modMaintenance(-maintainCost, MoT_Construction);
			}
			if (newOwner !is null && newOwner.valid) {
				newOwner.modMaintenance(maintainCost, MoT_Construction);
			}
		}
	}

	void remove(Object& obj) {
		if(started) {
			started = false;
			if(maintainCost != 0)
				obj.owner.modMaintenance(-maintainCost, MoT_Construction);
		}
	}

	void move(Object& obj, uint toPosition) {
	}

	TickResult tick(Object& obj, double time) {
		return TR_UsedLabor;
	}

	void cancel(Object& obj) {
		if(buildCost != 0)
			obj.owner.refundBudget(buildCost, budgetCycle);
	}

	void complete(Object& obj) {
	}

	void read(Message& msg) {
		throw("Attempting to read into a server constructible.");
	}

	bool repeat(Object& obj) {
		budgetCycle = -1;
		curLabor = 0;
		paid = false;
		started = false;
		repeated = true;
		return true;
	}

	void write(Message& msg) {
		uint8 tp = type;
		msg << tp;
		msg << id;
		msg << started;
		msg << curLabor;
		msg << totalLabor;
		msg << maintainCost;
		msg << buildCost;
		msg << finalizing;
		msg << finalizingTimer;
	}

	void save(SaveFile& msg) {
		uint8 tp = type;
		msg << tp;
		msg << id;
		msg << started;
		msg << curLabor;
		msg << totalLabor;
		msg << maintainCost;
		msg << buildCost;
		msg << paid;
		msg << repeated;
		msg << finalizing;
		msg << finalizingTimer;
	}
	
	void load(SaveFile& msg) {
		msg >> id;
		msg >> started;
		msg >> curLabor;
		msg >> totalLabor;
		msg >> maintainCost;
		msg >> buildCost;
		if(msg >= SV_0117)
			msg >> paid;
		else
			paid = true;
		if(msg >= SV_0118)
			msg >> repeated;
		else
			repeated = false;
		msg >> finalizing;
		msg >> finalizingTimer;
	}
};
