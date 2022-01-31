// Trackmania Turbo autosplitter
// Made by Voyager006 based on donadigo's TMF autosplitter
// https://github.com/donadigo/AutoSplitters/blob/master/Trackmania%20Forever.asl

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

    // The number of checkpoints crossed during the current race.
    int checkpoints : "TrackmaniaTurbo.exe", 0x181B818, 0x14, 0x1DC;

    // The current lap time in milliseconds.
    int curLapTime : "TrackmaniaTurbo.exe", 0x1819750, 0x37C, 0x3C0, 0x0;
}

startup
{
    // Settings
	settings.Add("SplitOnCp", false, "Split on each checkpoint");
	settings.Add("SplitOnLap", false, "Split on each lap");

    // Variables for log export
    string fileSeparator = "_";
    string headerSeparator = " - ";
    string tableColSeparator = "   ";

    // State
    vars.currentRunTime = 0;
    vars.firstMapName = "";
    vars.mapNames = new List<string>();
    vars.segments = new List<int>();

    // Logging functionality
    // Times here are calculated as if thousandths were counted
    Action<string, int> LogSplit = (mapName, segment) =>
    {
        vars.mapNames.Add(mapName);
        vars.segments.Add(segment);
    };
    vars.LogSplit = LogSplit;

    EventHandler ResetSplits = (s, e) =>
    {
        vars.mapNames = new List<string>();
        vars.segments = new List<int>();
    };
    vars.ResetSplits = ResetSplits;
    timer.OnStart += vars.ResetSplits;

    Func<int, string> GetTimeFormat = referenceTime =>
    {
        if (referenceTime < 10000) return @"s\.fff";
        if (referenceTime < 60000) return @"ss\.fff";
        if (referenceTime < 600000) return @"m\:ss\.fff";
        if (referenceTime < 3600000) return @"mm\:ss\.fff";
        if (referenceTime < 36000000) return @"H\:mm\:ss\.fff";
        return @"HH\:mm\:ss\.fff";
    };

    Func<int, string, string> FormatTime = (time, format) => TimeSpan.FromMilliseconds(time).ToString(format);

    Func<string, string> GetCategory = separator =>
    {
        return String.Join(separator, timer.Run.CategoryName, String.Join(separator, timer.Run.Metadata.VariableValueNames.Values));
    };

    Func<string> GenerateResultsTable = () =>
    {
        string mapColHeader = "Name";
        string segmentColHeader = "Duration";
        string sumColHeader = "Finished at";

        List<string> mapNames = vars.mapNames;
        List<int> segments = vars.segments;

        int mapColWidth = Math.Max(mapColHeader.Length, mapNames.Select(x => x.Length).Max());

        int largestSegment = segments.Max();
        string segmentTimeFormat = GetTimeFormat(largestSegment);
        int segmentColWidth = Math.Max(segmentColHeader.Length, FormatTime(largestSegment, segmentTimeFormat).Length);

        int largestSum = segments.Sum();
        string sumTimeFormat = GetTimeFormat(largestSum);
        int sumColWidth = Math.Max(sumColHeader.Length, FormatTime(largestSum, sumTimeFormat).Length);

        StringBuilder table = new StringBuilder();
        Func<string, int, string> Pad = (text, length) => String.Format("{0,-" + length + "}", text);
        Action<string, string, string> PrintRow = (mapName, segment, sum) =>
        {
            table.AppendLine(String.Join(tableColSeparator, Pad(mapName, mapColWidth), Pad(segment, segmentColWidth), Pad(sum, sumColWidth)));
        };

        table.AppendLine(String.Join(headerSeparator, "Trackmania Turbo", GetCategory(headerSeparator)));
        table.AppendLine();
        PrintRow(mapColHeader, segmentColHeader, sumColHeader);
        table.Append('-', mapColWidth + segmentColWidth + sumColWidth + 2 * tableColSeparator.Length);
        table.AppendLine();
        for (int i = 0; i < segments.Count; i++)
        {
            string mapName = mapNames[i];
            string segment = FormatTime(segments[i], segmentTimeFormat);
            string sum = FormatTime(segments.GetRange(0, i + 1).Sum(), sumTimeFormat);
            PrintRow(mapName, segment, sum);
        }
        return table.ToString();
    };

    Action<string, string> SaveFile = (content, path) =>
    {
        string directoryName = Path.GetDirectoryName(path);
        if (!Directory.Exists(directoryName))
        {
            Directory.CreateDirectory(directoryName);
        }
        File.AppendAllText(path, content);
    };

    Func<string> GetBase36TimeString = () =>
    {
        string base36Chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        long minutesDateTime = (long)(DateTime.Now - new DateTime(2016, 03, 24)).TotalMinutes;
        string base36DateTime = "";
        while(minutesDateTime > 0) {
            base36DateTime = base36Chars[(int)(minutesDateTime % 36)] + base36DateTime;
            minutesDateTime /= 36;
        }
        return base36DateTime;
    };

    EventHandler ExportSplitsToLogFile = (s, e) =>
    {
        if (timer.CurrentPhase == TimerPhase.Ended)
        {
            List<int> segments = vars.segments;
            string resultsTable = GenerateResultsTable();
            int totalTime = segments.Sum();
            string totalTimeFormat = GetTimeFormat(totalTime).Replace(':', '.');
            string filename = String.Join(fileSeparator, GetCategory(fileSeparator), GetBase36TimeString(), FormatTime(totalTime, totalTimeFormat) + ".log");
            string path = Path.Combine(Directory.GetCurrentDirectory(), "TrackmaniaTurboTimes", filename);
            SaveFile(resultsTable, path);
        }
    };
    vars.ExportSplitsToLogFile = ExportSplitsToLogFile;
    timer.OnSplit += vars.ExportSplitsToLogFile;
}

shutdown
{
    timer.OnStart -= vars.ResetSplits;
    timer.OnSplit -= vars.ExportSplitsToLogFile;
}

start
{
    // RTA starts after the countdown on the first map
    if (old.command != null && !old.command.Contains("init challenge") && current.command.Contains("init challenge"))
    {
        vars.firstMapName = current.mapName;
    }
    
    if (current.currentPlayground != 0
        && vars.firstMapName == current.mapName
        && old.time == -1
        && current.time >= 0)
    {
        print("[Autosplitter] start");
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
    // IGT is updated according to the current race time, rounded down to the nearest .XX
    if (current.currentPlayground != 0 && current.time >= 0)
    {
        int oldTime = (Math.Max(old.time, 0) / 10) * 10;
        int newTime = (Math.Max(current.time, 0) / 10) * 10;
        vars.currentRunTime += newTime - oldTime;
    }

    // Log reset if player restarts the current run
    if (old.raceState == 1 && old.time >= 0 && current.time == -1)
    {
        print("[Autosplitter] reset : " + old.time);
        vars.LogSplit(current.mapName + " (Reset)", old.time);
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
    if (current.command != null
        && current.command.Contains("init challenge")
        && vars.firstMapName == current.mapName
        && old.raceState >= 1
        && current.raceState == 0)
    {
        print("[Autosplitter] reset");
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
	if (current.currentPlayground != 0
        && current.time >= 0
        && old.raceState == 1
        && current.raceState == 2)
    {
        // Split on map finish
        print("[Autosplitter] split : " + current.time);
        vars.LogSplit(current.mapName, current.time);
        return true;
    }
    else if (current.time >= 0 && current.curLapTime < old.curLapTime)
    {
        // Split on lap
        return settings["SplitOnLap"];
    }
    else if (current.checkpoints > old.checkpoints)
    {
        // Split on checkpoint
        return settings["SplitOnCp"];
    }
    else
    {
        return false;
    }
}
