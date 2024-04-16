// Just for ease of access
const string pluginName = Meta::ExecutingPlugin().Name;

// UI toggles
bool isRecordingPoints = false;
bool windowVisible = false;

// Global state
string currentMap = "";
uint roundNumber = 0;
bool recentlyRecordedScore = false;
Knowledge currentMapMultilap = Knowledge::UNSURE;
dictionary trackedPlayers = dictionary();
dictionary playerPoints = dictionary();
dictionary playerPointsCurrRound = dictionary();


class PlayerStat {
    string name;
    int64 points;
    int64 toAdd;

    PlayerStat() {
        this.name = "";
        this.points = -1;
        this.toAdd = 0;
    }

    PlayerStat(const string &in name, int64 points, int64 toAdd) {
        this.name = name;
        this.points = points;
        this.toAdd = toAdd;
    }

    int opCmp(PlayerStat@ other) {
        return this.points == other.points ? 0 : (this.points > other.points ? 1 : -1);
    }
}


void RenderMenu() {
    if (UI::MenuItem("\\$66F" + Icons::FileTextO + "\\$z " + pluginName, "", windowVisible) && !windowVisible) {
        windowVisible = !windowVisible;
    }
}


void RenderInterface() {
    if (windowVisible) {
        UI::Begin(pluginName, windowVisible, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);
        UI::BeginGroup();
        if (!isRecordingPoints && UI::Button("Start Recording")) {
            print("Started recording match points");
            isRecordingPoints = true;
        }
        if (isRecordingPoints && UI::Button("Stop Recording")) {
            print("Stopped recording match points");
            isRecordingPoints = false;
            currentMap = "";
            roundNumber = 0;
            recentlyRecordedScore = false;
            trackedPlayers.DeleteAll();
            playerPointsCurrRound.DeleteAll();
        }
        UI::SameLine();
        if (UI::Button("Reset Points")) {
            playerPoints.DeleteAll();
            playerPointsCurrRound.DeleteAll();
        }
        UI::EndGroup();
        renderPlayerTable();
        UI::End();
    }
}


void renderPlayerTable() {
    if (playerPoints.IsEmpty() || !UI::BeginTable("playerpoints", 2, UI::TableFlags::SizingFixedFit)) {
        return;
    }
    UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
    UI::TableSetupColumn("Points", UI::TableColumnFlags::WidthStretch);
    UI::TableHeadersRow();
    UI::TableNextRow();
    auto players = array<PlayerStat>(50);
    auto playerNames = playerPoints.GetKeys();
    if (playerNames.Length > players.Length) {
        players.Resize(playerNames.Length);
    }
    for (uint i = 0; i < playerNames.Length; i++) {
        int64 points = 0;
        if (playerPoints.Get(playerNames[i], points)) {
            int64 toAdd = 0;
            playerPointsCurrRound.Get(playerNames[i], toAdd);
            players[i] = PlayerStat(playerNames[i], points, toAdd);
        }
    }
    players.SortDesc();
    for (uint i = 0; i < players.Length; i++) {
        if (players[i].points >= 0) {
            UI::TableNextColumn();
            UI::Text(players[i].name);
            UI::TableNextColumn();
            if (players[i].toAdd > 0) {
                UI::Text(Text::Format("%d", players[i].points) + Text::Format("  (+%d)", players[i].toAdd));
            } else {
                UI::Text(Text::Format("%d", players[i].points));
            }
            UI::TableNextRow();
        }
    }
    UI::EndTable();
}


void recordMatchPoints() {
    // Double check recording is enabled
    if (!isRecordingPoints) return;

    // Check we are gaming
    auto app = cast<CTrackMania>(GetApp());
    if (app.CurrentPlayground is null || (app.CurrentPlayground.UIConfigs.Length < 1)) return;

    // If we changed track, let's clear player tracking
    auto mapName = StripFormatCodes(app.RootMap.MapName);
    if (currentMap != mapName) {
        roundNumber = 0;
        trackedPlayers.DeleteAll();
        currentMapMultilap = Knowledge::UNSURE;
        currentMap = mapName;
    }

    // Fetch player data
    auto mlf = MLFeed::GetRaceData_V4();
    for (uint i = 0; i < mlf.SortedPlayers_Race.Length; i++) {
        auto player = cast<MLFeed::PlayerCpInfo_V4>(mlf.SortedPlayers_Race[i]);
        bool alreadyTracked = trackedPlayers.Exists(player.WebServicesUserId);

        // With multilap finishes we get the amazing state of having finished before even starting
        if (currentMapMultilap == Knowledge::UNSURE) {
            if (player.CpCount == 0 && player.IsFinished && player.IsSpawned) {
                currentMapMultilap = Knowledge::YEP;
            } else if (player.IsFinished && player.LastCpTime != 0) {
                currentMapMultilap = Knowledge::NOPE;
            }
        }
        bool isActuallyFinished = (currentMapMultilap != Knowledge::YEP && player.IsFinished) || player.CpCount > mlf.CpCount;

        // New finish for the player, we store it
        if (isActuallyFinished && !alreadyTracked && player.LastCpTime != 0) {
            int64 currPoints = 0;
            if (!playerPoints.Exists(player.Name)) playerPoints.Set(player.Name, currPoints);
            playerPointsCurrRound.Get(player.Name, currPoints);
            playerPointsCurrRound.Set(player.Name, currPoints + player.RoundPoints);
            trackedPlayers.Set(player.WebServicesUserId, 1);
            recentlyRecordedScore = true;
            continue;
        }

        // Player was tracked, but has not finished, meaning they started a new round, so we "untrack" them
        if (!isActuallyFinished && alreadyTracked) {
            trackedPlayers.Delete(player.WebServicesUserId);
        }
    }

    // Euristically guess round switching
    if (recentlyRecordedScore && trackedPlayers.IsEmpty()) {
        auto playerNames = playerPointsCurrRound.GetKeys();
        for (uint i = 0; i < playerNames.Length; i++) {
            int64 currPoints = 0;
            if (playerPointsCurrRound.Get(playerNames[i], currPoints)) {
                int64 points = 0;
                playerPoints.Get(playerNames[i], points);
                playerPoints.Set(playerNames[i], points + currPoints);
                playerPointsCurrRound.Delete(playerNames[i]);
            }
        }
        roundNumber++;
        recentlyRecordedScore = false;
    }

}


void Main() {
    DepCheck();
    while (true) {
        if (isRecordingPoints) {
            recordMatchPoints();
        }
        sleep(1000);
    }
}
