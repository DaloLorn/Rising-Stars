import resources;
import hooks;

class TerraformRequireUnlockTag : ResourceHook {
	Document doc("This resource can only be terraformed to if a specific unlock tag has been unlocked by the empire.");
	Argument tag(AT_UnlockTag, doc="The unlock tag to check. Unlock tags can be named any arbitrary thing, and will be created as specified. Use the same tag value in the UnlockTag() or similar hook that should unlock it.");

	bool canTerraform(Object@ from, Object@ to) const override {
		if(from.owner is null || !from.owner.valid)
			return false;
		return from.owner.isTagUnlocked(tag.integer);
	}
}