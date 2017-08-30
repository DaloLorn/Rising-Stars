import attributes;
import hooks;
import bonus_effects;

class SetAsHome : EmpireTrigger {
	Document doc("Sets the empire home to the object.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		@emp.HomeObj = obj;
	}
	
#section all
}