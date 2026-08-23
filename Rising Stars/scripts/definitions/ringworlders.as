import attributes;
import hooks;
import bonus_effects;

class SetAsHome : EmpireTrigger {
	Document doc("Sets the empire homeworld to the object. Only affects planets.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		Planet@ pl = cast<Planet>(obj);
		if(pl !is null)
			@emp.Homeworld = pl;
	}
	
#section all
}