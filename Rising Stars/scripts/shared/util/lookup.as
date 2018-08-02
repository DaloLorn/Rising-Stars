//Search for a match in multiple values without a ugly
//if (foo == bar) || (foo == baz) || ..." list
//Allow a syntax close to a switch / case structure with variables
class Lookup {
	private int _value;

	Lookup(int value) {
		_value = value;
	}

	bool isIn(const int[]& values) {
		for(uint i = 0, cnt = values.length; i < cnt; ++i) {
			if (_value == values[i])
				return true;
		}
			return false;
	}
};
