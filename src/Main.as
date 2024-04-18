// Just for ease of access
const string pluginName = Meta::ExecutingPlugin().Name;

// Settings
[Setting name="Polling Rate Milliseconds" description="How often the plugin checks for players crossing the finish line"]
int dataPollingRateMs = 1000;

// UI toggles
bool isRecordingPoints = false;
bool windowVisible = false;
bool resetEveryTrack = false;

// Global state
string currentMap = "";
uint roundNumber = 0;
uint selectedOld = 0;
bool recentlyRecordedScore = false;
bool newDataToRender = false;
Knowledge currentMapMultilap = Knowledge::UNSURE;
dictionary trackedPlayers = dictionary();
dictionary playerPoints = dictionary();
dictionary playerPointsCurrRound = dictionary();
array<string> playedTracks = {};
array<string> previousScores = {};


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
            mergeScores();
        }
        UI::SameLine();
        if (UI::Button("Reset Points")) {
            playerPoints.DeleteAll();
            playerPointsCurrRound.DeleteAll();
            playedTracks.Resize(0);
            previousScores.Resize(0);
        }
        resetEveryTrack = UI::Checkbox("Reset/store scores for every track", resetEveryTrack);
        UI::EndGroup();
        if (!playedTracks.IsEmpty()) {
            UI::BeginGroup();
            if (UI::BeginCombo("##", selectedOld > 0 ? playedTracks[selectedOld-1] : "##")) {
                for (uint i = 0; i <= playedTracks.Length; i++) {
                    auto comboEntry = i == 0 ? "##" : playedTracks[i-1];
                    if (UI::Selectable(comboEntry, selectedOld == i)) {
                        selectedOld = i;
                    }
                }
                UI::EndCombo();
            }
            UI::EndGroup();
        }
        if (selectedOld > 0) {
            renderPlayerTable(previousScores[selectedOld-1]);
        } else {
            renderPlayerTable(playerPoints, playerPointsCurrRound, newDataToRender);
        }
        newDataToRender = false;
        UI::End();
    }
}


void mergeScores() {
    if (!playerPointsCurrRound.IsEmpty()) newDataToRender = true;
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
}


void recordMatchPoints() {
    // Double check recording is enabled
    if (!isRecordingPoints) return;

    // Check we are gaming
    auto app = cast<CTrackMania>(GetApp());
    if (app.CurrentPlayground is null || (app.CurrentPlayground.UIConfigs.Length < 1)) return;

    // If we changed track, let's clear player tracking and store scores
    auto mapName = StripFormatCodes(app.RootMap.MapName);
    if (currentMap != mapName) {
        mergeScores();
        if (resetEveryTrack && currentMap != "") {
            playedTracks.InsertLast(currentMap);
            previousScores.InsertLast(serializeScores(playerPoints));
            playerPoints.DeleteAll();
            playerPointsCurrRound.DeleteAll();
        }
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
            newDataToRender = true;
            continue;
        }

        // Player was tracked, but has not finished, meaning they started a new round, so we "untrack" them
        if (!isActuallyFinished && alreadyTracked) {
            trackedPlayers.Delete(player.WebServicesUserId);
        }
    }

    // Euristically guess round switching
    if (recentlyRecordedScore && trackedPlayers.IsEmpty()) {
        mergeScores();
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
        sleep(dataPollingRateMs);
    }
}
