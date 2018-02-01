import attributes;
import hook_globals;
import generic_effects;

class ModSpacetimeDragFactor : GenericEffect, TriggerableGeneric {
	Document doc("Modifies the spacetime drag factor of the object.");
	Argument amount(AT_Decimal, doc="Spacetime drag factor modifier.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.modSpacetimeDrag(+amount.decimal);
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.modSpacetimeDrag(-amount.decimal);
	}
#section all
};