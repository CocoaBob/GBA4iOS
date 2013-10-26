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

#include <data-type/image/png/sys.hh>
#include <gui/View.hh>
#include <gui/AlertView.hh>
#include "EmuSystem.hh"
#include "Recent.hh"
#include <util/gui/ViewStack.hh>
#include <VideoImageOverlay.hh>
#include "EmuOptions.hh"
#include <EmuInput.hh>
#include "MsgPopup.hh"
#include "MultiChoiceView.hh"
#include "ConfigFile.hh"
#include "FilePicker.hh"
#include <InputManagerView.hh>
#include <EmuView.hh>
#include <TextEntry.hh>
#include <MenuView.hh>
#include <FileUtils.hh>
#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
#include <VController.hh>
#include <TouchConfigView.hh>
#endif
#include <meta.h>
#include <main/EmuMenuViews.hh>

MsgPopup popup;
StackAllocator menuAllocator;
EmuView emuView;
EmuNavView viewNav;
uint8 modalViewStorage[2][4096] __attribute__((aligned)) { {0} };
uint modalViewStorageIdx = 0;
InputManagerView *imMenu = nullptr;
WorkDirStack<1> workDirStack;

extern bool isGBAROM;
bool isMenuDismissKey(const Input::Event &e);
void startGameFromMenu();
bool touchControlsApplicable();
void loadGameCompleteFromFilePicker(uint result, const Input::Event &e);
bool updateInputDevicesOnResume = 0;
#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
extern SysVController vController;
#endif
bool menuViewIsActive = 1;

SystemMenuView mMenu;
ViewStack viewStack(mMenu);

void EmuNavView::onLeftNavBtn(const Input::Event &e)
{
	viewStack.popAndShow();
};

void EmuNavView::onRightNavBtn(const Input::Event &e)
{
	if(EmuSystem::gameIsRunning())
	{
		startGameFromMenu();
	}
};

namespace Gfx
{
    void onViewChange(Gfx::GfxViewState * = 0);
}

#if !defined(CONFIG_AUDIO_ALSA) && !defined(CONFIG_AUDIO_SDL) && !defined(CONFIG_AUDIO_PS3)
// use WIP direct buffer write API
#define USE_NEW_AUDIO
#endif

//static int soundRateDelta = 0;

void setupStatusBarInMenu()
{
	if(!optionHideStatusBar.isConst)
		Base::setStatusBarHidden(optionHideStatusBar > 1);
}

void setupStatusBarInGame()
{
	if(!optionHideStatusBar.isConst)
		Base::setStatusBarHidden(optionHideStatusBar);
}

static bool trackFPS = 0;
static TimeSys prevFrameTime;
static uint frameCount = 0;

void applyOSNavStyle()
{
	if(Base::hasHardwareNavButtons())
		return;
	uint flags = 0;
	if(optionLowProfileOSNav) flags|= Base::OS_NAV_STYLE_DIM;
	if(optionHideOSNav) flags|= Base::OS_NAV_STYLE_HIDDEN;
	Base::setOSNavigationStyle(flags);
}

void startGameFromMenu()
{
	applyOSNavStyle();
	Base::setIdleDisplayPowerSave(0);
	setupStatusBarInGame();
	if(!optionFrameSkip.isConst && (uint)optionFrameSkip != EmuSystem::optionFrameSkipAuto)
		Gfx::setVideoInterval((int)optionFrameSkip + 1);
	logMsg("running game");
	menuViewIsActive = 0;
	viewNav.setRightBtnActive(1);
	//logMsg("touch control state: %d", touchControlsAreOn);
#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
	vController.resetInput();
#endif
	// TODO: simplify this
	if(!Gfx::setValidOrientations(optionGameOrientation, 1))
		Gfx::onViewChange();
#ifndef CONFIG_GFX_SOFT_ORIENTATION
	Gfx::onViewChange();
#endif
	commonInitInput();
	emuView.ffGuiKeyPush = emuView.ffGuiTouch = 0;
    
	popup.clear();
	Input::setKeyRepeat(0);
	EmuControls::setupVolKeysInGame();
	/*if(optionFrameSkip == -1)
     {
     gfx_updateFrameTime();
     }*/
	/*if(optionFrameSkip != 0 && soundRateDelta != 0)
     {
     logMsg("reset sound rate delta");
     soundRateDelta = 0;
     audio_setPcmRate(audio_pPCM.rate);
     }*/
	Base::setRefreshRate(EmuSystem::vidSysIsPAL() ? 50 : 60);
	EmuSystem::start();
	Base::displayNeedsUpdate();
    
	if(trackFPS)
	{
		frameCount = 0;
		prevFrameTime.setTimeNow();
	}
}

void restoreMenuFromGame()
{
	menuViewIsActive = 1;
	Base::setIdleDisplayPowerSave(
#ifdef CONFIG_BLUETOOTH
                                  Bluetooth::devsConnected() ? 0 :
#endif
                                  (int)optionIdleDisplayPowerSave);
	//Base::setLowProfileNavigation(0);
	setupStatusBarInMenu();
	EmuSystem::pause();
	if(!optionFrameSkip.isConst)
		Gfx::setVideoInterval(1);
	//logMsg("setting valid orientations");
	if(!Gfx::setValidOrientations(optionMenuOrientation, 1))
		Gfx::onViewChange();
	Input::setKeyRepeat(1);
	Input::setHandleVolumeKeys(0);
	if(!optionRememberLastMenu)
		viewStack.popToRoot();
	Base::setRefreshRate(Base::REFRESH_RATE_DEFAULT);
	Base::displayNeedsUpdate();
	viewStack.show();
}

namespace Base
{
    
    void onExit(bool backgrounded)
    {
        Audio::closePcm();
        EmuSystem::pause();
        if(backgrounded)
        {
            if (isGBAROM)
            {
                EmuSystem::loadAutoState_GBA();
                EmuSystem::saveBackupMem_GBA();
            }
            else
            {
                EmuSystem::loadAutoState_GBC();
                EmuSystem::saveBackupMem_GBC();
            }
            
            if(optionNotificationIcon)
            {
                auto title = CONFIG_APP_NAME " was suspended";
                Base::addNotification(title, title, EmuSystem::gameName);
            }
        }
        else
        {
            EmuSystem::closeGame();
        }
        
        saveConfigFile();
        
#ifdef CONFIG_BLUETOOTH
		if(bta && (!backgrounded || (backgrounded && !optionKeepBluetoothActive)))
			Bluetooth::closeBT(bta);
#endif
        
#ifdef CONFIG_BASE_IOS
        if(backgrounded)
            FsSys::remove("/private/var/mobile/Library/Caches/" CONFIG_APP_ID "/com.apple.opengl/shaders.maps");
#endif
    }
    
    void onFocusChange(uint in)
    {
        if(optionPauseUnfocused && !menuViewIsActive)
        {
            if(in)
            {
#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
                vController.resetInput();
#endif
                EmuSystem::start();
            }
            else
            {
                EmuSystem::pause();
            }
            Base::displayNeedsUpdate();
        }
    }
    
    static void handleOpenFileCommand(const char *filename)
    {
        auto type = FsSys::fileType(filename);
        if(type == Fs::TYPE_DIR)
        {
            logMsg("changing to dir %s from external command", filename);
            restoreMenuFromGame();
            FsSys::chdir(filename);
            viewStack.popToRoot();
            auto &fPicker = *menuAllocator.allocNew<EmuFilePicker>();
            fPicker.init(Input::keyInputIsPresent());
            viewStack.useNavView = 0;
            viewStack.pushAndShow(&fPicker, &menuAllocator);
            return;
        }
        if(type != Fs::TYPE_FILE)
            return;
        if(!EmuFilePicker::defaultFsFilter(filename, type))
            return;
        FsSys::cPath dirnameTemp, basenameTemp;
        auto dir = string_dirname(filename, dirnameTemp);
        auto file = string_basename(filename, basenameTemp);
        FsSys::chdir(dir);
        logMsg("opening file %s in dir %s from external command", file, dir);
        restoreMenuFromGame();
        GameFilePicker::onSelectFile(file, Input::Event{});
    }
    
    void onDragDrop(const char *filename)
    {
        logMsg("got DnD: %s", filename);
        handleOpenFileCommand(filename);
    }
    
    void onInterProcessMessage(const char *filename)
    {
        logMsg("got IPC: %s", filename);
        handleOpenFileCommand(filename);
    }
    
    void onResume(bool focused)
    {
        if(updateInputDevicesOnResume)
        {
            updateInputDevices();
            EmuControls::updateAutoOnScreenControlVisible();
            updateInputDevicesOnResume = 0;
        }
        
        if(optionPauseUnfocused)
            onFocusChange(focused); // let focus handler deal with resuming emulation
        else
        {
            if(!menuViewIsActive) // resume emulation
            {
#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
                vController.resetInput();
#endif
                EmuSystem::start();
                Base::displayNeedsUpdate();
            }
        }
    }
    
}

namespace Gfx
{
    void onDraw(Gfx::FrameTimeBase frameTime)
    {
        emuView.draw(frameTime);
        if(likely(EmuSystem::isActive()))
        {
            if(trackFPS)
            {
                if(frameCount == 119)
                {
                    TimeSys now;
                    now.setTimeNow();
                    float total = now - prevFrameTime;
                    prevFrameTime = now;
                    logMsg("%f fps", double(120./total));
                    frameCount = 0;
                }
                else
                    frameCount++;
            }
            return;
        }
        
        if(View::modalView)
            View::modalView->draw(frameTime);
        else if(menuViewIsActive)
            viewStack.draw(frameTime);
        popup.draw();
    }
}

namespace Input
{
    
    void onInputDevChange(const DeviceChange &change)
    {
        logMsg("got input dev change");
        
        if(Base::appIsRunning())
        {
            updateInputDevices();
            EmuControls::updateAutoOnScreenControlVisible();
            
            if(change.added() || change.removed())
            {
                if(change.map == Input::Event::MAP_KEYBOARD || change.map == Input::Event::MAP_ICADE)
                {
#ifdef INPUT_HAS_SYSTEM_DEVICE_HOTSWAP
                    if(optionNotifyInputDeviceChange)
#endif
                    {
                        popup.post("Input devices have changed", 2, 0);
                        Base::displayNeedsUpdate();
                    }
                }
                else
                {
                    popup.printf(2, 0, "%s %d %s", Input::Event::mapName(change.map), change.devId + 1, change.added() ? "connected" : "disconnected");
                    Base::displayNeedsUpdate();
                }
            }
            
#ifdef CONFIG_BLUETOOTH
			if(viewStack.size == 1) // update bluetooth items
				viewStack.top()->onShow();
#endif
        }
        else
        {
            logMsg("delaying input device changes until app resumes");
            updateInputDevicesOnResume = 1;
        }
        
        if(menuViewIsActive)
            Base::setIdleDisplayPowerSave(
#ifdef CONFIG_BLUETOOTH
                                          Bluetooth::devsConnected() ? 0 :
#endif
                                          (int)optionIdleDisplayPowerSave);
    }
    
}

void handleInputEvent(const Input::Event &e)
{
	if(e.isPointer())
	{
		//logMsg("Pointer %s @ %d,%d", Input::eventActionToStr(e.state), e.x, e.y);
	}
	else
	{
		//logMsg("%s %s from %s", e.device->keyName(e.button), Input::eventActionToStr(e.state), e.device->name());
	}
	if(likely(EmuSystem::isActive()))
	{
		emuView.inputEvent(e);
	}
	else if(View::modalView)
		View::modalView->inputEvent(e);
	else if(menuViewIsActive)
	{
		if(e.state == Input::PUSHED && e.isDefaultCancelButton())
		{
			if(viewStack.size == 1)
			{
				//logMsg("cancel button at view stack root");
				if(EmuSystem::gameIsRunning())
				{
					startGameFromMenu();
				}
				else if(e.map == Input::Event::MAP_KEYBOARD && (Config::envIsAndroid || Config::envIsLinux))
					Base::exit();
			}
			else viewStack.popAndShow();
		}
		if(e.state == Input::PUSHED && isMenuDismissKey(e))
		{
			if(EmuSystem::gameIsRunning())
			{
				startGameFromMenu();
			}
		}
		else viewStack.inputEvent(e);
	}
}

void setupFont()
{
	float size = optionFontSize / 1000.;
	logMsg("setting up font size %fmm", (double)size);
	View::defaultFace->applySettings(FontSettings(Gfx::ySMMSizeToPixel(size)));
}

namespace Gfx
{
    void onViewChange(GfxViewState *)
    {
        logMsg("view change");
        GuiTable1D::setDefaultXIndent();
        popup.place();
        emuView.place();
        viewStack.place(Gfx::viewportRect());
        if(View::modalView)
            View::modalView->placeRect(Gfx::viewportRect());
        logMsg("done view change");
    }
}

Gfx::BufferImage *getArrowAsset()
{
	static Gfx::BufferImage res;
	if(!res)
	{
		PngFile png;
		if(png.loadAsset("padButton.png") != OK)
		{
			bug_exit("couldn't load padButton.png");
		}
		res.init(png);
	}
	return &res;
}

Gfx::BufferImage *getXAsset()
{
	static Gfx::BufferImage res;
	if(!res)
	{
		PngFile png;
		if(png.loadAsset("xButton.png") != OK)
		{
			bug_exit("couldn't load xButton.png");
		}
		res.init(png);
	}
	return &res;
}

void mainInitCommon()
{
    if (isGBAROM)
    {
        initOptions_GBA();
    }
    else
    {
        initOptions_GBC();
    }
    
#ifdef CONFIG_BLUETOOTH
	assert(EmuSystem::maxPlayers <= 5);
	Bluetooth::maxGamepadsPerType = EmuSystem::maxPlayers;
#endif
    
	loadConfigFile();
    
#ifdef USE_BEST_COLOR_MODE_OPTION
	Base::setWindowPixelBestColorHint(optionBestColorModeHint);
#endif
}

void OptionCategoryView::init(bool highlightFirst)
{
	//logMsg("running option category init");
	uint i = 0;
	forEachInArray(subConfig, e)
	{
		e->init(); item[i++] = e;
		e->onSelect() =
		[e_i](TextMenuItem &, const Input::Event &e)
		{
			auto &oCategoryMenu = *menuAllocator.allocNew<SystemOptionView>();
			oCategoryMenu.init(e_i, !e.isPointer());
			viewStack.pushAndShow(&oCategoryMenu, &menuAllocator);
		};
	}
	assert(i <= sizeofArray(item));
	BaseMenuView::init(item, i, highlightFirst);
}

