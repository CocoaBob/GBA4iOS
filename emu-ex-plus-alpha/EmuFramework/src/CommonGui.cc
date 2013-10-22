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

#include <CommonGui.hh>

MsgPopup popup;
StackAllocator menuAllocator;
EmuView emuView;
EmuNavView viewNav;
uint8 modalViewStorage[2][4096] __attribute__((aligned)) { {0} };
uint modalViewStorageIdx = 0;
InputManagerView *imMenu = nullptr;
WorkDirStack<1> workDirStack;

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

void setupStatusBarInMenu()
{
	if(!optionHideStatusBar.isConst)
		Base::setStatusBarHidden(optionHideStatusBar > 1);
}

void applyOSNavStyle()
{
	if(Base::hasHardwareNavButtons())
		return;
	uint flags = 0;
	if(optionLowProfileOSNav) flags|= Base::OS_NAV_STYLE_DIM;
	if(optionHideOSNav) flags|= Base::OS_NAV_STYLE_HIDDEN;
	Base::setOSNavigationStyle(flags);
}


void startGameFromMenu() {
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

void setupFont()
{
	float size = optionFontSize / 1000.;
	logMsg("setting up font size %fmm", (double)size);
	View::defaultFace->applySettings(FontSettings(Gfx::ySMMSizeToPixel(size)));
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
            }
            else
            {
                EmuSystem::loadAutoState_GBC();
            }
            EmuSystem::saveBackupMem();
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