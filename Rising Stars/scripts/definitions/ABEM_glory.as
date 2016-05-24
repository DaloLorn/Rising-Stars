import attitudes;
from attitudes import AttitudeHook;
import hooks;
import attributes;
import generic_hooks;

class CannotManuallyTake : AttitudeHook {
	Document doc("This attitude cannot be taken through regular means.");
	
	bool canTake(Empire& emp) const {
		return false;
	}
}

class NoProgressPastMaxLevel : AttitudeHook {
	Document doc("Prevents this attitude's progress value from exceeding the maximum required to reach its maximum level.");

#section server
	void tick(Attitude& att, Empire& emp, any@ data, double time) const {
		if(att.progress > att.levels[att.maxLevel].threshold)
			att.progress = att.levels[att.maxLevel].threshold;
	}
#section all
}

class SetGloryMeter : EmpireTrigger {
	Document doc("Set the empire's glory meter to a certain attitude.");
	Argument attitude(AT_Attitude, doc="Attitude to use.");
	Argument level_up(AT_Integer, "0", doc="Immediately provide level ups for this attitude as well.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(emp is null)
			return;
		emp.setGloryMeter(attitude.integer);
		int levelups = level_up.integer - int(emp.AttitudeStartLevel);
		if(levelups > 0)
			emp.levelAttitude(attitude.integer, levelups);
	}
#section all
};

class ProgressOverTime : AttitudeHook {
	Document doc("Slowly increases the progress value of this attitude over time.");
	Argument amount(AT_Decimal, "1.0", doc="How much progress to add every second.");
	Argument useProgressFactor(AT_Boolean, "True", doc="If set, the added progress is multiplied by the empire's attitude progression factor. (Example: Empire is affected by 'Zeitgeist: Actualization', increasing progression rates)");
	
#section server
	void tick(Attitude& att, Empire& emp, any@ data, double time) const {
		double amt = amount.decimal * time;
		if(useProgressFactor.boolean)
			amt *= emp.AttitudeProgressFactor;
		att.progress += amt;
	}
#section all
}

class DecayProgress : AttitudeHook {
	Document doc("Slowly decreases the progress value of this attitude over time.");
	Argument amount(AT_Decimal, "1.0", doc="How much progress to remove every second.");
	Argument useProgressFactor(AT_Boolean, "True", doc="If set, the removed progress is divided by the empire's attitude progression factor. (Example: Empire is affected by 'Zeitgeist: Actualization', decreasing decay rates)");
	
#section server
	void tick(Attitude& att, Empire& emp, any@ data, double time) const {
		double amt = amount.decimal * time;
		if(useProgressFactor.boolean)
			amt /= emp.AttitudeProgressFactor;
		att.progress = max(att.progress - amt, 0.0);
	}
#section all
}

class ProgressFromContested : AttitudeHook {
	Document doc("Progress based on the time that you are in contested systems.");
	Argument multiplier(AT_Decimal, "1.0", doc="How much progress to award per contested system.");
	Argument useProgressFactor(AT_Boolean, "True", doc="If set, the added progress is multiplied by the empire's attitude progression factor.");
	
#section server
	void tick(Attitude& att, Empire& emp, any@ data, double time) const {
		double amt = emp.ContestedSystems * multiplier.decimal * time;
		if(useProgressFactor.boolean) {
			amt *= emp.AttitudeProgressFactor;
		}
		att.progress += amt;
	}
#section all
}

class DecayProgressFromContested : AttitudeHook {
	Document doc("Decrease progress based on the time that you are in contested systems.");
	Argument multiplier(AT_Decimal, "1.0", doc="How much progress to remove per contested system.");
	Argument useProgressFactor(AT_Boolean, "True", doc="If set, the removed progress is divided by the empire's attitude progression factor.");

#section server
	void tick(Attitude& att, Empire& emp, any@ data, double time) const {
		double amt = emp.ContestedSystems * multiplier.decimal * time;
		if(useProgressFactor.boolean)
			amt /= emp.AttitudeProgressFactor;
		att.progress = max(att.progress - amt, 0.0);
	}
#section all
}

class ConsumeAttributeToProgress : AttitudeHook {
	Document doc("Increases progress by decreasing an empire attribute.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to consume.");
	Argument base(AT_Decimal, "1.0", doc="How much progress to grant per attribute point.");
	Argument multiplier(AT_EmpAttribute, doc="Attribute to multiply the decay by.");
	Argument useProgressFactor(AT_Boolean, "True", doc="If set, the added progress is multiplied by the empire's attribute progression factor.");
	
#section server
	void tick(Attitude& att, Empire& emp, any@ data, double time) const {
		double amt = emp.getAttribute(attribute.integer);
		if(amt > 0) {
			double mult = emp.getAttribute(multiplier.integer);
			emp.modAttribute(attribute.integer, AC_Multiply, 0);
			amt *= base.decimal;
			amt *= mult;
			if(useProgressFactor.boolean)
				amt *= emp.AttitudeProgressFactor;
			att.progress += amt;
		}
	}
#section all
}

class DecayFromNegativeAttribute : AttitudeHook {
	Document doc("Decreases progress by increasing a negative empire attribute.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to monitor.");
	Argument base(AT_Decimal, "1.0", doc="How much progress to remove per attribute point.");
	Argument multiplier(AT_EmpAttribute, doc="Attribute to multiply the decay by.");
	Argument useProgressFactor(AT_Boolean, "True", doc="If set, the removed progress is divided by the empire's attitude progression factor.");

#section server
	void tick(Attitude& att, Empire& emp, any@ data, double time) const {
		double amt = emp.getAttribute(attribute.integer);
		if(amt < 0) {
			double mult = emp.getAttribute(multiplier.integer);
			emp.modAttribute(attribute.integer, AC_Multiply, 0);
			amt *= -base.decimal;
			amt *= mult;
			if(useProgressFactor.boolean)
				amt /= emp.AttitudeProgressFactor;
			att.progress = max(att.progress - amt, 0.0);
		}
	}
#section all
}