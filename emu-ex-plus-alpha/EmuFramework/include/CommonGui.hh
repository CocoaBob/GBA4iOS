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

extern bool isGBAROM;
bool isMenuDismissKey(const Input::Event &e);
void startGameFromMenu();
bool touchControlsApplicable();
void loadGameCompleteFromFilePicker(uint result, const Input::Event &e);
extern ViewStack viewStack;
extern StackAllocator menuAllocator;
extern uint8 modalViewStorage[2][4096] __attribute__((aligned));
extern uint modalViewStorageIdx;
extern WorkDirStack<1> workDirStack;
extern bool updateInputDevicesOnResume;
#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
extern SysVController vController;
#endif
extern InputManagerView *imMenu;
extern EmuNavView viewNav;
extern bool menuViewIsActive;
extern MsgPopup popup;
extern EmuView emuView;
extern SystemMenuView mMenu;
#ifdef CONFIG_BLUETOOTH
BluetoothAdapter *bta = nullptr;
#endif

namespace Gfx
{
void onViewChange(Gfx::GfxViewState * = 0);
}

#if !defined(CONFIG_AUDIO_ALSA) && !defined(CONFIG_AUDIO_SDL) && !defined(CONFIG_AUDIO_PS3)
	// use WIP direct buffer write API
	#define USE_NEW_AUDIO
#endif

//static int soundRateDelta = 0;

void setupStatusBarInMenu();

void setupStatusBarInGame();

void applyOSNavStyle();

void startGameFromMenu();

void restoreMenuFromGame();

void handleInputEvent(const Input::Event &e);

void setupFont();

void mainInitCommon();

template <size_t NAV_GRAD_SIZE>
static void mainInitWindowCommon(const Gfx::LGradientStopDesc (&navViewGrad)[NAV_GRAD_SIZE])
{
	Base::setWindowTitle(CONFIG_APP_NAME);
	Gfx::setClear(1);
	if(!optionDitherImage.isConst)
	{
		Gfx::setDither(optionDitherImage);
	}

	#if defined CONFIG_BASE_ANDROID && CONFIG_ENV_ANDROID_MINSDK >= 9
	if((int8)optionProcessPriority != 0)
		Base::setProcessPriority(optionProcessPriority);

	optionSurfaceTexture.defaultVal = Gfx::supportsAndroidSurfaceTextureWhitelisted();
	if(!Gfx::supportsAndroidSurfaceTexture())
	{
		optionSurfaceTexture = 0;
		optionSurfaceTexture.isConst = 1;
	}
	else if(optionSurfaceTexture == OPTION_SURFACE_TEXTURE_UNSET)
	{
		optionSurfaceTexture = Gfx::useAndroidSurfaceTexture();
	}
	else
	{
		logMsg("using surface texture setting from config file");
		Gfx::setUseAndroidSurfaceTexture(optionSurfaceTexture);
	}
	// optionSurfaceTexture is treated as a boolean value after this point
	#endif

	#ifdef SUPPORT_ANDROID_DIRECT_TEXTURE
	optionDirectTexture.defaultVal = Gfx::supportsAndroidDirectTextureWhitelisted();
	if(!Gfx::supportsAndroidDirectTexture())
	{
		optionDirectTexture = 0;
		optionDirectTexture.isConst = 1;
	}
	else if(optionDirectTexture == OPTION_DIRECT_TEXTURE_UNSET)
	{
		optionDirectTexture = Gfx::useAndroidDirectTexture();
	}
	else
	{
		logMsg("using direct texture setting from config file");
		Gfx::setUseAndroidDirectTexture(optionDirectTexture);
	}
	// optionDirectTexture is treated as a boolean value after this point
	#endif

	#ifdef CONFIG_EMUFRAMEWORK_VCONTROLLER_RESOLUTION_CHANGE
	if(!optionTouchCtrlImgRes.isConst)
		optionTouchCtrlImgRes.initDefault((Gfx::viewPixelWidth() * Gfx::viewPixelHeight() > 380000) ? 128 : 64);
	#endif

	View::defaultFace = ResourceFace::loadSystem();
	assert(View::defaultFace);

	updateInputDevices();
	if((int)optionTouchCtrl == 2)
		EmuControls::updateAutoOnScreenControlVisible();
	else
		EmuControls::setOnScreenControls(optionTouchCtrl);
	#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
	vController.updateMapping(0);
	#endif
	EmuSystem::configAudioRate_GBA();
	Base::setIdleDisplayPowerSave(optionIdleDisplayPowerSave);
	applyOSNavStyle();
	setupStatusBarInMenu();

	emuView.disp.init();
	#if defined CONFIG_BASE_ANDROID && defined CONFIG_GFX_OPENGL_USE_DRAW_TEXTURE
	emuView.disp.flags = Gfx::Sprite::HINT_NO_MATRIX_TRANSFORM;
	#endif
	emuView.vidImgOverlay.setEffect(optionOverlayEffect);
	emuView.vidImgOverlay.intensity = optionOverlayEffectLevel/100.;

	if(optionDPI != 0U)
		Base::setDPI(optionDPI);
	setupFont();
	popup.init();
	#ifdef CONFIG_EMUFRAMEWORK_VCONTROLS
	vController.init((int)optionTouchCtrlAlpha / 255.0, Gfx::xMMSize(int(optionTouchCtrlSize) / 100.));
	EmuControls::updateVControlImg();
	EmuControls::resolveOnScreenCollisions();
	EmuControls::setupVControllerPosition();
	emuView.menuIcon.init(getArrowAsset());
	#endif

	View::onRemoveModalView() =
		[]()
		{
			if(!menuViewIsActive)
			{
				startGameFromMenu();
			}
		};
	//logMsg("setting up view stack");
	viewNav.init(View::defaultFace, View::needsBackControl ? getArrowAsset() : nullptr,
			!Config::envIsPS3 ? getArrowAsset() : nullptr, navViewGrad, sizeofArray(navViewGrad));
	viewNav.setRightBtnActive(0);
	viewStack.init();
	if(optionTitleBar)
	{
		//logMsg("title bar on");
		viewStack.setNavView(&viewNav);
	}
	mMenu.init(Input::keyInputIsPresent());
	//logMsg("setting menu orientation");
	// set orientation last since it can trigger onViewChange()
	Gfx::setValidOrientations(optionMenuOrientation, 1);
	Base::setAcceptDnd(1);

	#if defined CONFIG_BASE_ANDROID && CONFIG_ENV_ANDROID_MINSDK >= 9
	if(!Base::apkSignatureIsConsistent())
	{
		auto &ynAlertView = *allocModalView<YesNoAlertView>();
		ynAlertView.init("Warning: App has been modified by 3rd party, use at your own risk", 0);
		ynAlertView.onNo() =
			[](const Input::Event &e)
			{
				Base::exit();
			};
		View::addModalView(ynAlertView);
	}
	#endif

	Gfx::onViewChange();
	mMenu.show();

	Base::displayNeedsUpdate();
}
