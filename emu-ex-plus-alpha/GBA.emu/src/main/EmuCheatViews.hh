#pragma once
#include <Cheats.hh>

#include <main/Cheats_GBC.hh>

class SystemEditCheatView : public EditCheatView
{
private:
    DualTextMenuItem ggCode;
	DualTextMenuItem code;
	uint idx = 0;
    
    GbcCheat *cheat = nullptr;
	MenuItem *item[5] {nullptr};

	void renamed_GBA(const char *str) override;
    void renamed_GBC(const char *str) override;
	void removed_GBA() override;
    void removed_GBC() override;
    
public:
	SystemEditCheatView();
	void init_gba(bool highlightFirst, int cheatIdx);
    void init_gbc(bool highlightFirst, GbcCheat &cheat);
};

class EditCheatListView : public BaseEditCheatListView
{
private:
	TextMenuItem addGS12CBCode, addGS3Code;
	TextMenuItem cheat[EmuCheats::MAX];
    TextMenuItem addGGGS;

	void loadAddCheatItems_GBA(MenuItem *item[], uint &items) override;
    void loadAddCheatItems_GBC(MenuItem *item[], uint &items) override;
	void loadCheatItems_GBA(MenuItem *item[], uint &items) override;
    void loadCheatItems_GBC(MenuItem *item[], uint &items) override;
    void addNewCheat(int isGSv3);

public:
	EditCheatListView();
};

class CheatsView : public BaseCheatsView
{
private:
	BoolMenuItem cheat[EmuCheats::MAX];

	void loadCheatItems_GBA(MenuItem *item[], uint &i) override;
    void loadCheatItems_GBC(MenuItem *item[], uint &i) override;

public:
	CheatsView() {}
};

extern CheatsView cheatsMenu;
