local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"", {spectate = false}, "VE", 0, 1, 'PowerUpExtender.setGrip(2)'},
	{"", {spectate = false}, "VE", 0, 1, 'PowerUpExtender.pushForward(6)'},
	{"", {spectate = false}, "VE", 200, 5, 'PowerUpExtender.pushForward(3)'},
	{"", {spectate = false}, "VE", 2000, 1, 'PowerUpExtender.resetGrip()'},
}

return set