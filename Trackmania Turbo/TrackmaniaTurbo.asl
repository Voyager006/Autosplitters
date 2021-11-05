// Trackmania Turbo autosplitter
// Made by donadigo and Voyager006

state("TrackmaniaTurbo")
{
    // Game object which is instantiated on map load
    int currentPlayground : "TrackmaniaTurbo.exe", 0x17DB820, 0x22C;

    // Command string issued for main menu + init challenge
    string21 command : "TrackmaniaTurbo.exe", 0x17DAE90, 0x0;

    // Map name part of aforementioned string
    string3 mapName : "TrackmaniaTurbo.exe", 0x17DAE90, 0x17;

    // Values: BeforeStart (0), Running (1), Finished (2), Eliminated (3)
    int raceState : "TrackmaniaTurbo.exe", 0x181B818, 0x14, 0x1E4;

    // Current race time in milliseconds. If there is no race underway, but a map is loaded, its value is -1.
    int time : "TrackmaniaTurbo.exe", 0x181B818, 0x14, 0x1CC;
}

startup
{
	// Timer will not reset in case of a game crash
    vars.currentRunTime = 0;
    vars.firstMapName = "";
}

start
{
    // RTA starts after the countdown on the first map
    if (!old.command.Contains("init challenge") && current.command.Contains("init challenge"))
    {
        vars.firstMapName = current.mapName;
    }
    
    if (current.command.Contains("init challenge")
        && vars.firstMapName == current.mapName
        && old.time == -1
        && current.time >= 0)
    {
		vars.currentRunTime = current.time;
        return true;
    }
    else
    {
        return false;
    }
}

update
{
    // IGT is updated according to the current race time
    if (current.currentPlayground != 0 && current.time >= 0)
    {
		int oldTime = Math.Max(old.time, 0);
		int newTime = Math.Max(current.time, 0);
		vars.currentRunTime += newTime - oldTime;
    }

    return true;
}

isLoading
{
	// Manually supply the IGT value in gameTime
    return true;
}

gameTime
{
    return System.TimeSpan.FromMilliseconds(vars.currentRunTime);
}

reset
{
    // The autosplitter resets when the player restarts the map that started the speedrun
    if (current.command.Contains("init challenge")
        && vars.firstMapName == current.mapName
        && old.time == -1
        && current.time >= 0)
    {
		vars.currentRunTime = current.time;
        return true;
    }
    else
    {
        return false;
    }
}

split
{
    // The autosplitter splits once the player reaches the finish line
	if (current.currentPlayground != 0
		&& current.time >= 0
		&& old.raceState == 1
		&& current.raceState == 2)
    {
        print("Splitting at " + vars.currentRunTime + " ms");
        return true;
    }

    return false;
}
