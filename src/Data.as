const string SER_SEPARATOR = "§#§#§";

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

    PlayerStat(const string &in blob) {
        auto parts = blob.Split(SER_SEPARATOR, 2);
        this.name = parts[0];
        this.points = Text::ParseInt64(parts[1]);
        this.toAdd = 0;
    }

    string serialize() {
        return this.name + SER_SEPARATOR + Text::Format("%d", this.points);
    }

    int opCmp(PlayerStat@ other) {
        return this.points == other.points ? 0 : (this.points > other.points ? 1 : -1);
    }
}

array<PlayerStat>@ packPlayerStats(const dictionary &in playerScores, const dictionary &in currRound) {
    auto playerNames = playerScores.GetKeys();
    auto players = array<PlayerStat>(playerNames.Length);
    for (uint i = 0; i < playerNames.Length; i++) {
        int64 points = 0;
        if (playerScores.Get(playerNames[i], points)) {
            int64 toAdd = 0;
            currRound.Get(playerNames[i], toAdd);
            players[i] = PlayerStat(playerNames[i], points, toAdd);
        }
    }
    players.SortDesc();
    return players;
}


string serializeScores(const dictionary &in playerScores) {
    dictionary mockCurr = dictionary();
    auto players = packPlayerStats(playerScores, mockCurr);
    array<string> playerStrings = array<string>(players.Length);
    for (uint i = 0; i < players.Length; i++) {
        playerStrings[i] = players[i].serialize();
    }
    return string::Join(playerStrings, "\n");
}


array<PlayerStat>@ unserializeStats(const string &in blob) {
    auto playerStrings = blob.Split("\n");
    auto players = array<PlayerStat>(playerStrings.Length);
    for (uint i = 0; i < playerStrings.Length; i++) {
        players[i] = PlayerStat(playerStrings[i]);
    }
    return players;
}
