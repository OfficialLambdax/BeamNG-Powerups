
File Architecture for the powerups to correctly work

	You are right now looking at the directory that defines "sets".
	Each directory in here contains groups
	eg. "template" and "open" are two sets of groups.
	
	A filepath to a set is what the powerups library needs in order to load powerups.
	
	Click one of the two and you will see multiple directories and lua files.
	Each .lua file defines a "group". A group defines levels and the according powerups along side the rendering of the powerups that a vehicle can pickup. If a group lua file is named eg "template" then the directory that contains all its powerups needs to be named the same.
	
	Click on a group folder.
	In there you will atleast find 1 lua file and maybe some other folders.
	Important is the lua file. it might be named "template.lua".
	
	This file contains the powerup definition and logic.
	
	
	File tree ####
	
	/powerups <=== directory containing all the sets
	
	/powerups/* <=== directory contains group definitions and rendering logic for each group
		eg. template.lua
		M.leveling = {
			"powerup_1", ----------  Level 1
			"powerup_2",           | Level 2
			"powerup_3"            | Level 3
		}                          |
		                           |
	/powerups/"groupname"/* <=== directory contains powerup definitions for that group
                                   |
		eg. powerup_1.lua <--------  Name must match (without the .lua)
		
		The powerup itself may requires more assets to fully work. However that is totally up to each powerup. One may uses a set, another maybe needs to load sounds. etc.
		At default a powerup only needs this file and thats it.
		
		In order to keep powerups and all its assets together i advise to put them right next to the powerup or in a folder beside it.
			eg. /powerups/"groupname"/"powerup"/sounds/*
				
		This would ofc also work
				/art/sounds
				
		But yeah, makes it easier to have everything together for when things are copied around or into other mods. My opinion. Asset duplication hooray! :x