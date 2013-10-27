#include <Cheats.hh>
#include <MsgPopup.hh>
#include <TextEntry.hh>
#include <util/gui/ViewStack.hh>
#include <main/EmuCheatViews.hh>
#include <main/Cheats_GBC.hh>
#include <gambatte.h>
extern MsgPopup popup;
extern ViewStack viewStack;
extern gambatte::GB gbEmu;
StaticDLList<GbcCheat, EmuCheats::MAX> cheatList;
extern bool cheatsModified;

static bool strIsGGCode(const char *str)
{
	return strlen(str) == 11 && str[3] == '-' && str[7] == '-' &&
		string_isHexValue(&str[0], 3) &&
		string_isHexValue(&str[4], 3) &&
		string_isHexValue(&str[8], 3);
}

static bool strIsGSCode(const char *str)
{
	return strlen(str) == 8 && string_isHexValue(str, 8);
}

void applyCheats()
{
	if(EmuSystem::gameIsRunning())
	{
		std::string ggCodeStr, gsCodeStr;
		forEachInDLList(&cheatList, e)
		{
			if(!e.isOn())
				continue;
			std::string &codeStr = strstr(e.code, "-") ? ggCodeStr : gsCodeStr;
			if(codeStr.size())
				codeStr += ";";
			codeStr += e.code;
		}
		gbEmu.setGameGenie(ggCodeStr);
		gbEmu.setGameShark(gsCodeStr);
		if(ggCodeStr.size())
			logMsg("set GG codes: %s", ggCodeStr.c_str());
		if(gsCodeStr.size())
			logMsg("set GS codes: %s", gsCodeStr.c_str());
	}
}

void writeCheatFile_GBC()
{
	if(!cheatsModified)
		return;

	FsSys::cPath filename;
	sprintf(filename, "%s/%s.gbcht", EmuSystem::savePath(), EmuSystem::gameName);

	if(!cheatList.size)
	{
		logMsg("deleting cheats file %s", filename);
		FsSys::remove(filename);
		cheatsModified = 0;
		return;
	}

	auto file = IoSys::create(filename);
	if(!file)
	{
		logMsg("error creating cheats file %s", filename);
		return;
	}
	logMsg("writing cheats file %s", filename);

	int version = 0;
	file->writeVar((uint8)version);
	file->writeVar((uint16)cheatList.size);
	forEachInDLList(&cheatList, e)
	{
		file->writeVar((uint8)e.flags);
		file->writeVar((uint16)strlen(e.name));
		file->fwrite(e.name, strlen(e.name), 1);
		file->writeVar((uint8)strlen(e.code));
		file->fwrite(e.code, strlen(e.code), 1);
	}
	file->close();
	cheatsModified = 0;
}

void readCheatFile_GBC()
{
	FsSys::cPath filename;
	sprintf(filename, "%s/%s.gbcht", EmuSystem::savePath(), EmuSystem::gameName);
	auto file = IoSys::open(filename);
	if(!file)
	{
		return;
	}
	logMsg("reading cheats file %s", filename);

	uint8 version = 0;
	file->readVar(version);
	if(version != 0)
	{
		logMsg("skipping due to version code %d", version);
		file->close();
		return;
	}
	uint16 size = 0;
	file->readVar(size);
	iterateTimes(size, i)
	{
		GbcCheat cheat;
		uint8 flags = 0;
		file->readVar(flags);
		cheat.flags = flags;
		uint16 nameLen = 0;
		file->readVar(nameLen);
		file->read(cheat.name, std::min(uint16(sizeof(cheat.name)-1), nameLen));
		uint8 codeLen = 0;
		file->readVar(codeLen);
		file->read(cheat.code, std::min(uint8(sizeof(cheat.code)-1), codeLen));
		if(!cheatList.addToEnd(cheat))
		{
			logMsg("cheat list full while reading from file");
			break;
		}
	}
	file->close();
}

void SystemEditCheatView::renamed_GBC(const char *str)
{
	string_copy(cheat->name, str);
	cheatsModified = 1;
}

void SystemEditCheatView::removed_GBC()
{
	cheatList.remove(*cheat);
	cheatsModified = 1;
	refreshCheatViews();
	applyCheats();
}

void SystemEditCheatView::init_gbc(bool highlightFirst, GbcCheat &cheat)
{
	this->cheat = &cheat;

	uint i = 0;
	loadNameItem(cheat.name, item, i);
	ggCode.init(cheat.code); item[i++] = &ggCode;
	loadRemoveItem(item, i);
	assert(i <= sizeofArray(item));
	BaseMenuView::init(item, i, highlightFirst);
}

/* SystemEditCheatView::SystemEditCheatView(): EditCheatView("Edit Code"),
	ggCode
	{
		"Code",
		[this](DualTextMenuItem &item, const Input::Event &e)
		{
			auto &textInputView = *allocModalView<CollectTextInputView>();
			textInputView.init("Input xxxxxxxx (GS) or xxx-xxx-xxx (GG) code", cheat->code);
			textInputView.onText() =
				[this](const char *str)
				{
					if(str)
					{
						if(!strIsGGCode(str) && !strIsGSCode(str))
						{
							popup.postError("Invalid format");
							Base::displayNeedsUpdate();
							return 1;
						}
						string_copy(cheat->code, str);
						string_toUpper(cheat->code);
						cheatsModified = 1;
						applyCheats();
						ggCode.compile();
						Base::displayNeedsUpdate();
					}
					removeModalView();
					return 0;
				};
			View::addModalView(textInputView);
		}
	}
{} Riley Testut */

void EditCheatListView::loadAddCheatItems_GBC(MenuItem *item[], uint &items)
{
	addGGGS.init(); item[items++] = &addGGGS;
}

void EditCheatListView::loadCheatItems_GBC(MenuItem *item[], uint &items)
{
	int cheats = std::min(cheatList.size, (int)sizeofArray(cheat));
	auto it = cheatList.iterator();
	iterateTimes(cheats, c)
	{
		auto &thisCheat = it.obj();
		cheat[c].init(thisCheat.name); item[items++] = &cheat[c];
		cheat[c].onSelect() =
			[this, c](TextMenuItem &, const Input::Event &e)
			{
				auto &editCheatView = *menuAllocator.allocNew<SystemEditCheatView>();
				editCheatView.init_gbc(!e.isPointer(), *cheatList.index(c));
				viewStack.pushAndShow(&editCheatView, &menuAllocator);
			};
		it.advance();
	}
}

/* Riley Testut

EditCheatListView::EditCheatListView():
	addGGGS
	{
		"Add Game Genie / GameShark Code",
		[this](TextMenuItem &item, const Input::Event &e)
		{
			auto &textInputView = *allocModalView<CollectTextInputView>();
			textInputView.init("Input xxxxxxxx (GS) or xxx-xxx-xxx (GG) code");
			textInputView.onText() =
				[this](const char *str)
				{
				if(str)
				{
					if(!strIsGGCode(str) && !strIsGSCode(str))
					{
						popup.postError("Invalid format");
						Base::displayNeedsUpdate();
						return 1;
					}
					GbcCheat c;
					string_copy(c.code, str);
					string_toUpper(c.code);
					string_copy(c.name, "Unnamed Cheat");
					if(!cheatList.addToEnd(c))
					{
						popup.postError("Error adding cheat");
						removeModalView();
						return 0;
					}
					logMsg("added new cheat, %d total", cheatList.size);
					cheatsModified = 1;
					applyCheats();
					removeModalView();
					refreshCheatViews();

					auto &textInputView = *allocModalView<CollectTextInputView>();
					textInputView.init("Input description");
					textInputView.onText() =
						[this](const char *str)
						{
							if(str)
							{
								string_copy(cheatList.last()->name, str);
								removeModalView();
								refreshCheatViews();
							}
							else
							{
								removeModalView();
							}
							return 0;
						};
					View::addModalView(textInputView);
				}
				else
				{
					removeModalView();
				}
				return 0;
			};
			View::addModalView(textInputView);
		}
	}
{}*/

void CheatsView::loadCheatItems_GBC(MenuItem *item[], uint &i)
{
	int cheats = std::min(cheatList.size, (int)sizeofArray(cheat));
	auto it = cheatList.iterator();
	iterateTimes(cheats, cIdx)
	{
		auto &thisCheat = it.obj();
		cheat[cIdx].init(thisCheat.name, thisCheat.isOn()); item[i++] = &cheat[cIdx];
		cheat[cIdx].onSelect() =
			[this, cIdx](BoolMenuItem &item, const Input::Event &e)
			{
				item.toggle();
				auto c = cheatList.index(cIdx);
				c->toggleOn();
				cheatsModified = 1;
				applyCheats();
			};
		logMsg("added cheat %s : %s", thisCheat.name, thisCheat.code);
		it.advance();
	}
}
