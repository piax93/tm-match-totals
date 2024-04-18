array<PlayerStat> cachedStats = {};


void renderPlayerTable(const dictionary &in playerScores, const dictionary &in currRound, bool newData = true) {
    if (playerScores.IsEmpty() || !UI::BeginTable("playerpoints", 2, UI::TableFlags::SizingFixedFit)) {
        return;
    }
    if (newData || cachedStats.IsEmpty()) {
        cachedStats = packPlayerStats(playerScores, currRound);
    }
    drawScoreTable(cachedStats);
}


void renderPlayerTable(const string &in storedScores) {
    if (UI::BeginTable("playerpoints", 2, UI::TableFlags::SizingFixedFit)) {
        auto players = unserializeStats(storedScores);
        drawScoreTable(players);
    }
}


void drawScoreTable(const array<PlayerStat> &in players) {
    UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
    UI::TableSetupColumn("Points", UI::TableColumnFlags::WidthStretch);
    UI::TableHeadersRow();
    UI::TableNextRow();
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
