import influence;
import hooks;
from influence import InfluenceClauseHook;
import resources;

#section server
import influence_global;
#section all

//ShareGates(To Starter = True, To Other = True)
// Share gate access between empires.
/// If <To Starter> is true, the treaty starter gets gate access.
/// If <To Other> is true, the treaty signatories get gate access.
class ShareGates : InfluenceClauseHook {
	Document doc("Shares gate access from either of the parties in a treaty to the other (or both).");
	Argument starter("To Starter", AT_Boolean, "True", doc="Whether the receiver shares gates with the starter.");
	Argument other("To Other", AT_Boolean, "True", doc="Whether the starter shares gates with the receiver.");

#section server
void onTick(Treaty@ treaty, Clause@ clause, double time) const override {
		int mask = computeMask(treaty);
		for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
			Empire@ giver = treaty.joinedEmpires[i];
			// Are we sharing to everyone the treaty says we should share to?
			// If not, let's do that now.
			if(giver.GateShareMask & mask != mask) {
				updateSharing(treaty, giver, mask);
			}
		}
	}

	int computeMask(Treaty@ treaty) {
		if(other.boolean) {
			if(starter.boolean) // Share to all treaty members.
				return treaty.presentMask;
			else if(treaty.leader !is null) // Share to all except starter.
				return treaty.presentMask & ~treaty.leader.mask;
		} 
		else if(starter.boolean && treaty.leader !is null) {
			return treaty.leader.mask; // Share only to starter.
		}
		return 0; // Share to nobody? This shouldn't be a thing, but it's technically *possible*...
	}

	void updateSharing(Treaty@ treaty, Empire@ giver, int mask) {
		auto@ data = giver.getStargates();
		Object@ obj;
		while(receive(data, obj)) {
			if(obj is null)
				continue;				
			for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
				Empire@ otherEmp = treaty.joinedEmpires[i];
				// Is this someone the treaty says we should be sharing to?
				// And are we not sharing to them yet?
				if(mask & otherEmp.mask != 0 && giver.GateShareMask & otherEmp.mask == 0) {
					otherEmp.registerFriendlyStargate(obj);
				}
			}
		}
		giver.GateShareMask |= mask;
	}

	void onEnd(Treaty@ treaty, Clause@ clause) const override {
		int mask = computeMask(treaty);
		for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
			Empire@ giver = treaty.joinedEmpires[i];
			// Formally stop sharing to all treaty members. (Except us, obviously!)
			// Other sharing treaties with those empires may notice we've stopped sharing,
			// in which case they'll tell us to start sharing again in the next tick.
			// (This also applies to the mask changes in onLeave(), below.)
			giver.GateShareMask.value &= ~mask | giver.mask;
			auto@ data = giver.getStargates();
			Object@ obj;
			while(receive(data, obj)) {
				if(obj is null)
					continue;
				for(uint j = 0; j < cnt; ++j) {
					Empire@ otherEmp = treaty.joinedEmpires[j];
					// Were we sharing to them? Well, not anymore!
					if(otherEmp !is giver && mask & otherEmp.mask != 0) {
						otherEmp.unregisterFriendlyStargate(obj);
					}
				}
			}
		}
	}

	void onLeave(Treaty@ treaty, Clause@ clause, Empire@ left) const override {
		int mask = computeMask(treaty);
		// Were we being shared to? If so, tell everyone to stop sharing.
		if(mask & left.mask != 0) {
			for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
				Empire@ otherEmp = treaty.joinedEmpires[i];
				if(otherEmp !is left) {
					otherEmp.GateShareMask &= ~left.mask;
					auto@ data = otherEmp.getStargates();
					Object@ obj;
					while(receive(data, obj)) {
						if(obj is null)
							continue;
						left.unregisterFriendlyStargate(obj);
					}
				}
			}
		}

		// Were we sharing to others? If so, tell them we're not sharing anymore.
		left.GateShareMask.value &= ~mask | left.mask;
		if(mask & ~left.mask != 0) {
			auto@ data = left.getStargates();
			Object@ obj;
			while(receive(data, obj)) {
				if(obj is null)
					continue;
				for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
					Empire@ otherEmp = treaty.joinedEmpires[i];
					if(otherEmp !is left && mask & otherEmp.mask != 0) 
						otherEmp.unregisterFriendlyStargate(obj);
				}
			}
		}
	}
#section all
};

//ShareFlingBeacons(To Starter = True, To Other = True)
// Share fling access between empires.
/// If <To Starter> is true, the treaty starter gets fling access.
/// If <To Other> is true, the treaty signatories get fling access.
class ShareFlingBeacons : InfluenceClauseHook {
	Document doc("Shares fling beacon access from either of the parties in a treaty to the other (or both).");
	Argument starter("To Starter", AT_Boolean, "True", doc="Whether the receiver shares fling beacons with the starter.");
	Argument other("To Other", AT_Boolean, "True", doc="Whether the starter shares fling beacons with the receiver.");

#section server
	void onTick(Treaty@ treaty, Clause@ clause, double time) const override {
		int mask = computeMask(treaty);
		for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
			Empire@ giver = treaty.joinedEmpires[i];
			// Are we sharing to everyone the treaty says we should share to?
			// If not, let's do that now.
			if(giver.FlingShareMask & mask != mask) {
				updateSharing(treaty, giver, mask);
			}
		}
	}

	int computeMask(Treaty@ treaty) {
		if(other.boolean) {
			if(starter.boolean) // Share to all treaty members.
				return treaty.presentMask;
			else if(treaty.leader !is null) // Share to all except starter.
				return treaty.presentMask & ~treaty.leader.mask;
		} 
		else if(starter.boolean && treaty.leader !is null) {
			return treaty.leader.mask; // Share only to starter.
		}
		return 0; // Share to nobody? This shouldn't be a thing, but it's technically *possible*...
	}

	void updateSharing(Treaty@ treaty, Empire@ giver, int mask) {
		auto@ data = giver.getFlingBeacons();
		Object@ obj;
		while(receive(data, obj)) {
			if(obj is null)
				continue;				
			for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
				Empire@ otherEmp = treaty.joinedEmpires[i];
				// Is this someone the treaty says we should be sharing to?
				// And are we not sharing to them yet?
				if(mask & otherEmp.mask != 0 && giver.FlingShareMask & otherEmp.mask == 0) {
					otherEmp.registerFriendlyFlingBeacon(obj);
				}
			}
		}
		giver.FlingShareMask |= mask;
	}

	void onEnd(Treaty@ treaty, Clause@ clause) const override {
		int mask = computeMask(treaty);
		for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
			Empire@ giver = treaty.joinedEmpires[i];
			// Formally stop sharing to all treaty members. (Except us, obviously!)
			// Other sharing treaties with those empires may notice we've stopped sharing,
			// in which case they'll tell us to start sharing again in the next tick.
			// (This also applies to the mask changes in onLeave(), below.)
			giver.FlingShareMask.value &= ~mask | giver.mask;
			auto@ data = giver.getFlingBeacons();
			Object@ obj;
			while(receive(data, obj)) {
				if(obj is null)
					continue;
				for(uint j = 0; j < cnt; ++j) {
					Empire@ otherEmp = treaty.joinedEmpires[j];
					// Were we sharing to them? Well, not anymore!
					if(otherEmp !is giver && mask & otherEmp.mask != 0) {
						otherEmp.unregisterFriendlyFlingBeacon(obj);
					}
				}
			}
		}
	}

	void onLeave(Treaty@ treaty, Clause@ clause, Empire@ left) const override {
		int mask = computeMask(treaty);
		// Were we being shared to? If so, tell everyone to stop sharing.
		if(mask & left.mask != 0) {
			for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
				Empire@ otherEmp = treaty.joinedEmpires[i];
				if(otherEmp !is left) {
					otherEmp.FlingShareMask &= ~left.mask;
					auto@ data = otherEmp.getFlingBeacons();
					Object@ obj;
					while(receive(data, obj)) {
						if(obj is null)
							continue;
						left.unregisterFriendlyFlingBeacon(obj);
					}
				}
			}
		}

		// Were we sharing to others? If so, tell them we're not sharing anymore.
		left.FlingShareMask.value &= ~mask | left.mask;
		if(mask & ~left.mask != 0) {
			auto@ data = left.getFlingBeacons();
			Object@ obj;
			while(receive(data, obj)) {
				if(obj is null)
					continue;
				for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
					Empire@ otherEmp = treaty.joinedEmpires[i];
					if(otherEmp !is left && mask & otherEmp.mask != 0) 
						otherEmp.unregisterFriendlyFlingBeacon(obj);
				}
			}
		}
	}
#section all
};