# Automatic-Doors
Starbound Automatic Doors mod - also additional functionality

This accomplishes serveral things.

1.  Making doors operate in a reasonable automatic fashion
2.  Adding support for additional attributes beyond what the vanilla doors.lua accomplishes.  Therefore modders can use this as a base to have more feature complete doors(or other variable collision profile objects) or with more novelty features.
3.  Doors can act as a proximity sensor.  They need have a second output node.  This will output when the scanned target is found in the defined scan radius or zone.
4.  Doors can remain interactable and automatic while being also opened by wire input.  They need to have a second input node.
5.  The implimentation of doorOccupiesSpace() has been improved.  This function is called frequently by the colony deed code and the location data is now calculated and saved during init() rather than calculated over and over again, large colonies would see a performance improvement.

Some things yet to be accomplished.

1.  Allow doors to recieve commands from a console etc.  The main purpose would be to enable or disable automatic functionality.  But doors could be locked, scan targets could be adjusted, and really most any variable what would normally be set through JSON could potentially be altered.  Now the colsole probably isn't going to have every variable because that becomes to complex and cumbersome to use, but it could.
2.  The same functionality could allow opening an otherwise un-openable door.  Say a door in a protected micro-dungeon.  You complete a procedural type-quest on the same planet and the door is told to open.  A ship's airlocks could be opened by SAIL alone, etc.
3.  This could be accomplished in either a simple door-specific implimentation, or a more complete entity-to-entity communication package... and I'm leaning on the second because that's project exists already even if in a preliminary state.  But I don't want to go one way and switch later... because then if people build their objects with this in mind, it would break the objects.
