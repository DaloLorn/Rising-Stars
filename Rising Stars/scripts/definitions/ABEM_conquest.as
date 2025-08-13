import hooks;
import statuses;
from statuses import StatusHook;

class ModLoyaltyFractional : StatusHook {
    Document doc("Modifies the loyalty of the affected planet by a certain fractional amount for each stack of this status, rounded down.");
    Argument loyalty("Loyalty", AT_Decimal, doc="How much loyalty to add/subtract per stack. This also controls the minimum amount of stacks needed to change the planet's loyalty.");

#section server
    void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
        if(!obj.isPlanet || loyalty.decimal == 0) return;

        int prevStacks = status.stacks-1;
        int oldLoyalty = floor(abs(loyalty.decimal) * prevStacks);
        int newLoyalty = floor(abs(loyalty.decimal) * status.stacks);
        if(newLoyalty - oldLoyalty > 0)
            obj.modBaseLoyalty((newLoyalty - oldLoyalty) * (loyalty.decimal > 0 ? 1 : -1));
    }
    
    void onRemoveStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
        if(!obj.isPlanet || loyalty.decimal == 0) return;

        int prevStacks = status.stacks+1;
        int oldLoyalty = floor(abs(loyalty.decimal) * prevStacks);
        int newLoyalty = floor(abs(loyalty.decimal) * status.stacks);
        if(oldLoyalty - newLoyalty > 0)
            obj.modBaseLoyalty((oldLoyalty - newLoyalty) * (loyalty.decimal > 0 ? 1 : -1));
	}
#section all    
}
