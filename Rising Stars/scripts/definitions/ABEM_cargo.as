import cargo;
import trait_effects;
import traits;
import generic_hooks;

class MakeResourceVisible : TraitEffect {
    Document doc("Forces a secondary resource to be visible in the resource bar regardless of its default visibility.");
    Argument type(AT_Cargo, "Ore", doc="The resource type to reveal.");

#section server
    void postInit(Empire& emp, any@ data) const override {
        emp.forceCargoTypeVisible(type.integer);
    }
#section all
}

class AddGlobalCargo : BonusEffect {
    Document doc("Adds an amount of a particular secondary resource to the global pool.");
    Argument type(AT_Cargo, "Ore", doc="The resource type to add.");
    Argument amount(AT_Decimal, doc="Amount of resources to add.");

#section server
    void activate(Object@ obj, Empire@ emp) const override {
		if(emp is null)
			return;
		emp.addCargo(type.integer, amount.decimal);
	}
#section all
}