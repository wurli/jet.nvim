cat `find lua -name \*.lua` | grep -v '^\s*--' | grep -v '^\s*$' | wc -l
