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
		uint mask = 0;
		if(treaty.leader !is null)
			mask = treaty.leader.mask;
		for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i)
			mask |= treaty.joinedEmpires[i].mask;

		if(starter.boolean && treaty.leader !is null)
			treaty.leader.GateShareMask |= mask;
		if(other.boolean) {
			for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i) {
				if(treaty.joinedEmpires[i] !is treaty.leader)
					treaty.joinedEmpires[i].GateShareMask |= mask;
			}
		}
	}

	void onEnd(Treaty@ treaty, Clause@ clause) const override {
		if(treaty.leader !is null)
			treaty.leader.GateShareMask.value = treaty.leader.mask;
		for(uint i = 0, cnt = treaty.joinedEmpires.length; i < cnt; ++i)
			treaty.joinedEmpires[i].GateShareMask.value = treaty.joinedEmpires[i].mask;
	}

	void onLeave(Treaty@ treaty, Clause@ clause, Empire@ left) const override {
		left.GateShareMask.value = left.mask;
		onEnd(treaty, clause);
		onTick(treaty, clause, 0.0);
	}
#section all
};