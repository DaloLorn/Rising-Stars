double hasShield(const Effector& eff, const Object& obj, const Object& target) {
	if(target.isShip)
		return cast<Ship>(target).Shield > 0.0 ? 1.0 : 0.0;
	if(target.isOrbital)
		return cast<Orbital>(target).shield > 0.0 ? 1.0 : 0.0;
	return 0.0;
}