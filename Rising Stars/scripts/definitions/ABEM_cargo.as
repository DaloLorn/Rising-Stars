import cargo;
import trait_effects;
import traits;

class MakeResourceVisible : TraitEffect {
    Document doc("Forces a secondary resource to be visible in the resource bar regardless of its default visibility.");
    Argument type(AT_Cargo, "Ore", doc="The resource type to reveal.");

#section server
    void postInit(Empire& emp, any@ data) const override {
        emp.forceCargoTypeVisible(type.integer);
    }
#section all
}