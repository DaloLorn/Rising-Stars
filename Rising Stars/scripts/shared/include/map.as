#priority init 1501
import maps;

const int DEFAULT_SYSTEM_COUNT = 60;
// DOF - Scaling
const double DEFAULT_SPACING = 130000.0;
const double MIN_SPACING = 130000.0;

void init() {
	auto@ mapClass = getClass("Map");
	for(uint i = 0, cnt = THIS_MODULE.classCount; i < cnt; ++i) {
		auto@ cls = THIS_MODULE.classes[i];
		if(cls !is mapClass && cls.implements(mapClass))
			cls.create();
	}
}
