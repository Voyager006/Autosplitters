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
}

startup
{
    // Settings
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

    EventHandler ExportSplitsToLogFile = (s, e) =>
    {
        if (timer.CurrentPhase == TimerPhase.Ended)
        {
            List<int> segments = vars.segments;
            string resultsTable = GenerateResultsTable();
            int totalTime = segments.Sum();
            string totalTimeFormat = GetTimeFormat(totalTime).Replace(':', '.');
            long unixTimestamp = DateTimeOffset.Now.ToUnixTimeSeconds();
            string filename = String.Join(fileSeparator, GetCategory(fileSeparator), unixTimestamp, FormatTime(totalTime, totalTimeFormat) + ".log");
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

    if (old.raceState == 1 && current.raceState == 0)
    {
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
        vars.LogSplit(current.mapName, current.time);
        return true;
    }
    else
    {
        return false;
    }
}
