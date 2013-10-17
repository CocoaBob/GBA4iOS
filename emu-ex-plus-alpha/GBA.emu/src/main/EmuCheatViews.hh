#pragma once
#include <Cheats.hh>

#ifdef GBC_EMU_BUILD
#include <main/Cheats_GBC.hh>
#endif

class SystemEditCheatView : public EditCheatView
{
private:
    DualTextMenuItem ggCode;
	DualTextMenuItem code;
	uint idx = 0;
    
#ifdef GBC_EMU_BUILD
    GbcCheat *cheat = nullptr;
#endif
	MenuItem *item[5] {nullptr};

	void renamed(const char *str) override;
	void removed() override;
    
public:
	SystemEditCheatView();
	void init_gba(bool highlightFirst, int cheatIdx);
#ifdef GBC_EMU_BUILD
    void init_gbc(bool highlightFirst, GbcCheat &cheat);
#endif
};

class EditCheatListView : public BaseEditCheatListView
{
private:
	TextMenuItem addGS12CBCode, addGS3Code;
	TextMenuItem cheat[EmuCheats::MAX];
    TextMenuItem addGGGS;

	void loadAddCheatItems(MenuItem *item[], uint &items) override;
	void loadCheatItems(MenuItem *item[], uint &items) override;
	void addNewCheat(int isGSv3);

public:
	EditCheatListView();
};

class CheatsView : public BaseCheatsView
{
private:
	BoolMenuItem cheat[EmuCheats::MAX];

	void loadCheatItems(MenuItem *item[], uint &i) override;

public:
	CheatsView() {}
};

extern CheatsView cheatsMenu;
