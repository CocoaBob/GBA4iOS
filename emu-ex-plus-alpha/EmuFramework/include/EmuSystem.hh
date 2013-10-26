#pragma once

/*  This file is part of EmuFramework.

	Imagine is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	Imagine is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with EmuFramework.  If not, see <http://www.gnu.org/licenses/> */

#include <io/Io.hh>
#include <fs/sys.hh>
#include <audio/Audio.hh>
#include <util/time/sys.hh>
#include <util/audio/PcmFormat.hh>
#include <config/env.hh>
#include <gui/FSPicker/FSPicker.hh>
#include <util/gui/ViewStack.hh>

extern bool isGBAROM;

class EmuSystem
{
	public:
	enum class State { OFF, STARTING, PAUSED, ACTIVE };
	static State state;
	static bool isActive() { return state == State::ACTIVE; }
	static bool isStarted() { return state == State::ACTIVE || state == State::PAUSED; }
	static FsSys::cPath gamePath, fullGamePath;
	static char gameName[256], fullGameName[256];
	static FsSys::cPath savePath_;
	static Base::CallbackRef *autoSaveStateCallbackRef;
	static int saveStateSlot;
	static TimeSys startTime;
	static Gfx::FrameTimeBase startFrameTime;
	static int emuFrameNow;
	static Audio::PcmFormat pcmFormat;
	static const uint optionFrameSkipAuto;
	static uint aspectRatioX, aspectRatioY;
	static const uint maxPlayers;

	static void cancelAutoSaveStateTimer();
	static void startAutoSaveStateTimer();
	static int loadState_GBA(int slot = saveStateSlot);
    static int loadState_GBC(int slot = saveStateSlot);
	static int saveState_GBA();
    static int saveState_GBC();
	static bool stateExists(int slot);
	static const char *savePath() { return strlen(savePath_) ? savePath_ : gamePath; }
    
    
	static void sprintStateFilename_GBA(char *str, size_t size, int slot,
		const char *statePath = savePath(), const char *gameName = EmuSystem::gameName);
	template <size_t S>
	static void sprintStateFilename_GBA(char (&str)[S], int slot,
		const char *statePath = savePath(), const char *gameName = EmuSystem::gameName)
	{
		sprintStateFilename_GBA(str, S, slot, statePath, gameName);
	}
    
    static void sprintStateFilename_GBC(char *str, size_t size, int slot,
                                        const char *statePath = savePath(), const char *gameName = EmuSystem::gameName);
	template <size_t S>
	static void sprintStateFilename_GBC(char (&str)[S], int slot,
                                        const char *statePath = savePath(), const char *gameName = EmuSystem::gameName)
	{
		sprintStateFilename_GBC(str, S, slot, statePath, gameName);
	}
    
    
	static bool loadAutoState_GBA();
    static bool loadAutoState_GBC();
	static void saveAutoState_GBA();
    static void saveAutoState_GBC();
	static void saveBackupMem_GBA();
    static void saveBackupMem_GBC();
	static void savePathChanged_GBA();
    static void savePathChanged_GBC();
	static void resetGame_GBA();
    static void resetGame_GBC();
	static void initOptions_GBA();
    static void initOptions_GBC();
	static void writeConfig_GBA(Io *io);
    static void writeConfig_GBC(Io *io);
	static bool readConfig_GBA(Io *io, uint key, uint readSize);
    static bool readConfig_GBC(Io *io, uint key, uint readSize);
	static int loadGame_GBA(const char *path);
    static int loadGame_GBC(const char *path);
	typedef DelegateFunc<void (uint result, const Input::Event &e)> LoadGameCompleteDelegate;
	static LoadGameCompleteDelegate loadGameCompleteDel;
	static LoadGameCompleteDelegate &onLoadGameComplete() { return loadGameCompleteDel; }
	static void runFrame_GBA(bool renderGfx, bool processGfx, bool renderAudio) ATTRS(hot);
    static void runFrame_GBC(bool renderGfx, bool processGfx, bool renderAudio) ATTRS(hot);
	static bool vidSysIsPAL();
	static uint multiresVideoBaseX();
	static uint multiresVideoBaseY();
	static void configAudioRate_GBA();
    static void configAudioRate_GBC();
	static void configAudioPlayback()
	{
		auto prevFormat = pcmFormat;
        
        if (isGBAROM)
        {
            configAudioRate_GBA();
        }
        else
        {
            configAudioRate_GBC();
        }
        
		
		if(prevFormat != pcmFormat && Audio::isOpen())
		{
			logMsg("PCM format has changed, closing existing playback");
			Audio::closePcm();
		}
	}
	static void clearInputBuffers_GBA();
    static void clearInputBuffers_GBC();
	static void handleInputAction_GBA(uint state, uint emuKey);
    static void handleInputAction_GBC(uint state, uint emuKey);
	static uint translateInputAction_GBA(uint input, bool &turbo);
    static uint translateInputAction_GBC(uint input, bool &turbo);
	static uint translateInputAction(uint input)
	{
		bool turbo;
        
        if (isGBAROM)
        {
            return translateInputAction_GBA(input, turbo);
        }
        else
        {
            return translateInputAction_GBC(input, turbo);
        }
		
	}
	static void stopSound();
	static void startSound();
	static int setupFrameSkip(uint optionVal, Gfx::FrameTimeBase frameTime);
	static void setupGamePaths(const char *filePath);

	static void clearGamePaths()
	{
		strcpy(gameName, "");
		strcpy(fullGameName, "");
		strcpy(gamePath, "");
		strcpy(fullGamePath, "");
	}

	static TimeSys benchmark()
	{
		auto now = TimeSys::timeNow();
		iterateTimes(180, i)
		{
            if (isGBAROM)
            {
                runFrame_GBA(0, 1, 0);
            }
            else
            {
                runFrame_GBC(0, 1, 0);
            }
        }
		auto after = TimeSys::timeNow();
		return after-now;
	}

	static bool gameIsRunning()
	{
		return !string_equal(gameName, "");
	}

	static void pause()
	{
		if(isActive())
			state = State::PAUSED;
		stopSound();
		cancelAutoSaveStateTimer();
	}

	static void start()
	{
		state = State::ACTIVE;
        
        if (isGBAROM)
        {
            clearInputBuffers_GBA();
        }
        else
        {
            clearInputBuffers_GBC();
        }
        
		
		emuFrameNow = -1;
		startSound();
		startTime = {};
		startFrameTime = 0;
		startAutoSaveStateTimer();
	}

	static void closeSystem_GBA();
    static void closeSystem_GBC();
	static void closeGame(bool allowAutosaveState = 1);
};

enum { STATE_RESULT_OK, STATE_RESULT_NO_FILE, STATE_RESULT_NO_FILE_ACCESS, STATE_RESULT_IO_ERROR,
	STATE_RESULT_INVALID_DATA, STATE_RESULT_OTHER_ERROR };

static const char *stateResultToStr(int res)
{
	switch(res)
	{
		case STATE_RESULT_NO_FILE: return "No State Exists";
		case STATE_RESULT_NO_FILE_ACCESS: return "File Permission Denied";
		case STATE_RESULT_IO_ERROR: return "File I/O Error";
		case STATE_RESULT_INVALID_DATA: return "Invalid State Data";
		default: bug_branch("%d", res); return 0;
	}
}

enum TriggerPosType { TRIGGERS_INLINE = 0, TRIGGERS_RIGHT = 1, TRIGGERS_LEFT = 2, TRIGGERS_SPLIT = 3 };

static const char *stateNameStr(int slot)
{
	assert(slot >= -1 && slot < 10);
	static const char *str[] = { "Auto", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" };
	return str[slot+1];
}

class EmuNavView : public BasicNavView
{
public:
	constexpr EmuNavView() { }
	void onLeftNavBtn(const Input::Event &e) override;
	void onRightNavBtn(const Input::Event &e) override;
};

extern StackAllocator menuAllocator;
extern uint8 modalViewStorage[2][4096] __attribute__((aligned));
extern uint modalViewStorageIdx;
template<typename T, typename... ARGS>
static T *allocModalView(ARGS&&... args)
{
	static_assert(sizeof(T) <= sizeof(modalViewStorage[0]), "out of modal view storage");
	auto obj = new(modalViewStorage[modalViewStorageIdx]) T(std::forward<ARGS>(args)...);
	modalViewStorageIdx = (modalViewStorageIdx + 1) % 2;
	return obj;
}

#if defined INPUT_SUPPORTS_POINTER
#define CONFIG_EMUFRAMEWORK_VCONTROLS
#endif

#include <CreditsView.hh>
#include <inGameActionKeys.hh>
#include <main/EmuConfig.hh>
