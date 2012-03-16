/*
 * Copyright (C) 2001-2011 Ideaworks3D Ltd.
 * All Rights Reserved.
 *
 * This document is protected by copyright, and contains information
 * proprietary to Ideaworks Labs.
 * This file consists of source code released by Ideaworks Labs under
 * the terms of the accompanying End User License Agreement (EULA).
 * Please do not use this program/source code before you have read the
 * EULA and have agreed to be bound by its terms.
 */
#define IW_USE_SYSTEM_STDLIB
#include "s3eIOSIAd.h"
#include "s3eIOSIAd_autodefs.h"
#include "s3eEdk.h"
#include "s3eEdk_iphone.h"
#include "IwDebug.h"

#define S3E_CURRENT_EXT IOSIAD/*
 * Copyright (C) 2001-2011 Ideaworks3D Ltd.
 * All Rights Reserved.
 *
 * This document is protected by copyright, and contains information
 * proprietary to Ideaworks Labs.
 * This file consists of source code released by Ideaworks Labs under
 * the terms of the accompanying End User License Agreement (EULA).
 * Please do not use this program/source code before you have read the
 * EULA and have agreed to be bound by its terms.
 */
#define IW_USE_SYSTEM_STDLIB
#include "s3eIOSIAd.h"
#include "s3eIOSIAd_autodefs.h"
#include "s3eEdk.h"
#include "s3eEdk_iphone.h"
#include "IwDebug.h"

#define S3E_CURRENT_EXT IOSIAD
#include "s3eEdkError.h"
#define S3E_DEVICE_IOSIAD S3E_EXT_IOSIAD_HASH

#import <iAd/iAd.h>

#define degreesToRadian(x) (M_PI * (x) / 180.0)


ADBannerView* g_BannerView = NULL;
bool g_ShowBanner = false;
bool g_BannerLoaded = false;
static void adjustSurfaceView();

void s3eIOSIAdSetOrientation();

@interface s3eAdDelegate : NSObject <ADBannerViewDelegate>

- (void)bannerViewDidLoadAd:(ADBannerView *)banner;
- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error;
- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave;
- (void)bannerViewActionDidFinish:(ADBannerView *)banner;

@end

@implementation s3eAdDelegate

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
	IwTrace(IAD_VERBOSE, ("didload"));
	g_BannerLoaded = true;
	adjustSurfaceView();
	s3eEdkCallbacksEnqueue(S3E_EXT_IOSIAD_HASH, S3E_IOSIAD_CALLBACK_BANNER_LOADED);
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
    int errorcode = [error code];
    const char* buffer = [[error localizedDescription] UTF8String];
	IwTrace(IAD, ("didFailToReceiveAdWithError with: %s", buffer));
	s3eEdkCallbacksEnqueue(S3E_EXT_IOSIAD_HASH, S3E_IOSIAD_CALLBACK_FAILED, &errorcode, sizeof(int));
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
	IwTrace(IAD, ("ShouldBegin"));
	s3eEdkCallbacksEnqueue(S3E_EXT_IOSIAD_HASH, S3E_IOSIAD_CALLBACK_AD_STARTING);
	return YES;
}

- (void)bannerViewActionDidFinish:(ADBannerView *)banner
{
	IwTrace(IAD, ("DidFinish"));
	s3eEdkCallbacksEnqueue(S3E_EXT_IOSIAD_HASH, S3E_IOSIAD_CALLBACK_AD_FINISHED);
}

@end

s3eResult s3eIOSIAdInit()
{
	if (s3eEdkIPhoneGetVerMaj() < 4)
	{
		S3E_EXT_ERROR(UNSUPPORTED, ("iAd is only available on iOS 4.0 and newer"));
		return S3E_RESULT_ERROR;
	}
	
	s3eEdkCallbacksRegisterInternal(
		S3E_EDK_INTERNAL,
		S3E_EDK_CALLBACK_MAX,
		S3E_EDK_IPHONE_OSROTATION,
		(s3eCallback)s3eIOSIAdSetOrientation,
		NULL, S3E_FALSE);
		

	return S3E_RESULT_SUCCESS;
}

void s3eIOSIAdTerminate()
{
}

// Swap banner between being positioned on/off the screen
static void moveBanner(bool onScreen)
{
	int banner_height = (int)g_BannerView.bounds.size.height;
	s3eEdkOSOrientation dir = s3eEdkGetOSOrientation();
	if (onScreen)
		IwTrace(IAD_VERBOSE, ("moving banner on screen: height=%d orientation=%d", banner_height, dir));
	else
		IwTrace(IAD_VERBOSE, ("moving banner off screen: height=%d orientation=%d", banner_height, dir));
	
	CGFloat tx = 0;
	CGFloat ty = 0;
	switch (dir)
	{
		case S3E_EDK_OS_ORIENTATION_NORMAL:
			if (onScreen)
				ty = banner_height;
			else
				ty = -banner_height;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT90:
			if (onScreen)
				tx = -banner_height;
			else
				tx = banner_height;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT180:
			if (onScreen)
				ty = -banner_height;
			else
				ty = banner_height;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT270:
			if (onScreen)
				tx = banner_height;
			else
				tx = -banner_height;
			break;
	}
	
	IwTrace(IAD, ("move banner: transform x=%d, y=%d", (int)tx, (int)ty));
	[g_BannerView setCenter:CGPointMake(g_BannerView.center.x+tx, g_BannerView.center.y+ty)];
}

// Update surface view position and size to avoid banner
static void adjustSurfaceView()
{
	s3eEdkOSOrientation dir = s3eEdkGetOSOrientation();
	int banner_height = (int)[ADBannerView sizeFromBannerContentSizeIdentifier:g_BannerView.currentContentSizeIdentifier].height;

	CGRect frame = s3eEdkGetSurfaceUIView().frame;

	IwTrace(IAD, ("adjusting surface view: show=%d orientation=%d height=%d", g_ShowBanner, dir, banner_height));
	
	// adjust the size of the frame to account for the banner_size
	frame.size = s3eEdkGetUIView().frame.size;
	frame.origin = CGPointMake(0, 0);
	if (g_ShowBanner && g_BannerLoaded)
	{
		switch (dir)
		{
			case S3E_EDK_OS_ORIENTATION_NORMAL:
			case S3E_EDK_OS_ORIENTATION_ROT180:
				// shrink the height of the layer frame
				frame.size.height -= banner_height;
				break;
			case S3E_EDK_OS_ORIENTATION_ROT90:
			case S3E_EDK_OS_ORIENTATION_ROT270:
				// shrink the width of the layer frame
				frame.size.width -= banner_height;
				break;
		}
	}

	s3eEdkGetSurfaceUIViewLayer().frame = frame;

	if (g_ShowBanner && g_BannerLoaded)
	{
		switch (dir)
		{
			// also move the origin of the view frame
			case S3E_EDK_OS_ORIENTATION_NORMAL:
				frame.origin.y += banner_height;
				break;
			case S3E_EDK_OS_ORIENTATION_ROT270:
				frame.origin.x += banner_height;
				break;
				// origin stayes the same when add is on the right or the bottom of the the screen
			case S3E_EDK_OS_ORIENTATION_ROT90:
			case S3E_EDK_OS_ORIENTATION_ROT180:
				break;
		}
	}

	s3eEdkGetSurfaceUIView().frame = frame;
	if (s3eEdkGetGLUIView())
	{
        CGRect glFrame = CGRectMake(frame.origin.x, frame.origin.y, s3eEdkGetUIView().frame.size.width, s3eEdkGetUIView().frame.size.height);
		s3eEdkGetGLUIView().frame = glFrame;
		IwTrace(IAD_VERBOSE, ("adjusting GLView: %d %d %d %d", (int)glFrame.size.width, (int)glFrame.size.height, (int)glFrame.origin.x, (int)glFrame.origin.y));
	}

	// Set s3e Surface size - note scaling from UI coord space to pixels if using high-res scaling (on iPhone 4)
	s3eEdkSurfaceSetSize(true, s3eEdkGetSurfaceUIView().frame.size.width*s3eEdkGetIPhoneScaleFactor(), s3eEdkGetSurfaceUIView().frame.size.height*s3eEdkGetIPhoneScaleFactor());

	[s3eEdkGetUIViewController().view setNeedsLayout];
}

// Banner is "shown" by moving it on/off the screen
void showBanner(bool show)
{
	if (show && !g_ShowBanner)
	{
		g_ShowBanner = show;
		IwTrace(IAD, ("Showing banner"));
		moveBanner(true);
		adjustSurfaceView();
		s3eIOSIAdSetOrientation();
	}

	if (!show && g_ShowBanner)
	{
		g_ShowBanner = show;
		IwTrace(IAD, ("Hiding banner"));
		moveBanner(false);
		adjustSurfaceView();
	}
}

s3eResult s3eIOSIAdSetInt(s3eIOSIAdProperty prop, int32 value)
{
	switch (prop)
	{
		case S3E_IOSIAD_BANNER_SHOW:
			if (!g_BannerView)
			{
				S3E_EXT_ERROR(UNSUPPORTED, ("iAd is only available on iOS 4.0 and newer"));
				return S3E_RESULT_ERROR;
			}
			showBanner((bool)value);
			return S3E_RESULT_SUCCESS;
		default:
			break;
	}
	
	S3E_EXT_ERROR_SIMPLE(PARAM);
	return S3E_RESULT_ERROR;
}

int32 s3eIOSIAdGetInt(s3eIOSIAdProperty prop)
{
	switch (prop)
	{
		case S3E_IOSIAD_RUNNING:
			return g_BannerView != nil;
		case S3E_IOSIAD_BANNER_SHOW:
			return g_ShowBanner;
		case S3E_IOSIAD_BANNER_LOADED:
			return g_BannerLoaded;
		case S3E_IOSIAD_BANNER_WIDTH:
			if (!g_BannerView)
				return 0;
			return g_BannerView.bounds.size.width;
		case S3E_IOSIAD_BANNER_HEIGHT:
			if (!g_BannerView)
				return 0;
			return g_BannerView.bounds.size.height;
		default:
			break;
	}
	S3E_EXT_ERROR_SIMPLE(PARAM);
	return -1;
}

// Update orientation of the banner
void s3eIOSIAdSetOrientation()
{
	// Note that when dealing with native iOS UI code, coordinates and sizes use a DPI-dependant
	// coordinate system rather than absolute pixels: The screen is always 1024x680 on ipad and
	// 480x320 on iphone/ipod, even if an iPhone 4 is using 960x480 high res mode. Orientation is
	// also always normal/portrait since the native view itself does not rotate. Therefore,
	// coordinates must be scaled and/or rotated to s3e pixel-space when needed.
	
	if (!g_BannerView)
		return;

	s3eEdkOSOrientation dir = s3eEdkGetOSOrientation();
	IwTrace(IAD, ("s3eIOSIAdSetOrientation: %d", dir));

	CGAffineTransform transform = CGAffineTransformIdentity;
	CGSize viewSize = s3eEdkGetUIView().bounds.size;


	// Set banner size based on screen.
	// As an example, this demonstrates compile-time checking of iOS SDK version
	// and runtime checking of iOS firmware. The portrait/landsape constants were
	// introduced in 4.2 so won't compile against older SDKs (MAX_ALLOWED gives
	// base sdk) and also may cause an error on firmware too old to support them.
	// We could just use the deprecated 320/etc ones but this is future-proofed
	// against deprecated values being dropped.
	switch (dir)
	{
		case S3E_EDK_OS_ORIENTATION_NORMAL:
		case S3E_EDK_OS_ORIENTATION_ROT180:
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_2
			if (&ADBannerContentSizeIdentifierPortrait != nil)
				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
			else
#else
				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifier320x50;
#endif
			break;
		case S3E_EDK_OS_ORIENTATION_ROT90:
		case S3E_EDK_OS_ORIENTATION_ROT270:
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_2
            if (&ADBannerContentSizeIdentifierLandscape != nil)
				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifierLandscape;
			else
#else
				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifier480x32;
#endif
			break;
	}
	
	//[g_BannerView setNeedsLayout];
	
	CGSize bannerSize = [ADBannerView sizeFromBannerContentSizeIdentifier:g_BannerView.currentContentSizeIdentifier];
	CGFloat tx, ty;

	switch (dir)
	{
		case S3E_EDK_OS_ORIENTATION_NORMAL:
			transform = CGAffineTransformIdentity;//CGAffineTransformMakeRotation(degreesToRadian(0));
			tx = viewSize.width/2;
			ty = bannerSize.height/2;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT90:
			transform = CGAffineTransformMakeRotation(degreesToRadian(90));
			tx = viewSize.width - bannerSize.height/2;
			ty = viewSize.height/2;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT180:
			transform = CGAffineTransformMakeRotation(degreesToRadian(180));
			tx = viewSize.width/2;
			ty = viewSize.height - bannerSize.height/2;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT270:
		default:
			transform = CGAffineTransformMakeRotation(degreesToRadian(270));
			ty = viewSize.height/2;
			tx = bannerSize.height/2;
			break;
	}

	IwTrace(IAD, ("s3eIOSIAdSetOrientation transform: x=%d, y=%d", (int)tx, (int)ty));
	
	[g_BannerView setCenter:CGPointMake(tx, ty)];
	//[g_BannerView setTransform:CGAffineTransformTranslate(transform, tx, ty)];
	[g_BannerView setTransform:transform];
	
	if (!g_ShowBanner)
		moveBanner(false);
	
	adjustSurfaceView();
}

s3eResult s3eIOSIAdStart()
{
	if (g_BannerView)
	{
		S3E_EXT_ERROR(STATE, ("iAd is already running"));
		return S3E_RESULT_ERROR;
	}
	
	g_BannerView = [[ADBannerView alloc] initWithFrame:CGRectZero];
	g_BannerView.requiredContentSizeIdentifiers = [NSSet setWithObjects: ADBannerContentSizeIdentifier320x50, ADBannerContentSizeIdentifier480x32, nil];
	g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifier320x50;

	// add delegate
	s3eAdDelegate* delegate = [[s3eAdDelegate alloc] init];
	g_BannerView.delegate = delegate;

	
	// add to the view heirarchy
	[s3eEdkGetUIViewController().view addSubview:g_BannerView];
	[s3eEdkGetUIViewController().view bringSubviewToFront:g_BannerView];

	g_ShowBanner = false;
	g_BannerLoaded = false;

	s3eIOSIAdSetOrientation();
	IwTrace(IAD, ("Started"));
	return S3E_RESULT_SUCCESS;
}

s3eResult s3eIOSIAdStop()
{
	if (!g_BannerView)
	{
		S3E_EXT_ERROR(STATE, ("iAd is not running"));
		return S3E_RESULT_ERROR;
	}
	showBanner(false);
	g_BannerLoaded = false;
	[g_BannerView removeFromSuperview];
	[g_BannerView.delegate release];
	[g_BannerView release];
	g_BannerView = nil;
	IwTrace(IAD, ("Stopped"));
	return S3E_RESULT_SUCCESS;
}

s3eResult s3eIOSIAdCancel()
{
	if (!g_BannerView)
	{
		S3E_EXT_ERROR(STATE, ("iAd is not running"));
		return S3E_RESULT_ERROR;
	}
	[g_BannerView cancelBannerViewAction];
	return S3E_RESULT_SUCCESS;
}

#include "s3eEdkError.h"
#define S3E_DEVICE_IOSIAD S3E_EXT_IOSIAD_HASH

#import <iAd/iAd.h>

#define degreesToRadian(x) (M_PI * (x) / 180.0)


ADBannerView* g_BannerView = NULL;
bool g_ShowBanner = false;
bool g_BannerLoaded = false;
static void adjustSurfaceView();

void s3eIOSIAdSetOrientation();

@interface s3eAdDelegate : NSObject <ADBannerViewDelegate>

- (void)bannerViewDidLoadAd:(ADBannerView *)banner;
- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error;
- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave;
- (void)bannerViewActionDidFinish:(ADBannerView *)banner;

@end

@implementation s3eAdDelegate

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
	IwTrace(IAD_VERBOSE, ("didload"));
	g_BannerLoaded = true;
	s3eEdkCallbacksEnqueue(S3E_EXT_IOSIAD_HASH, S3E_IOSIAD_CALLBACK_BANNER_LOADED);
	adjustSurfaceView();
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
	IwTrace(IAD, ("error"));
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
	IwTrace(IAD, ("ShouldBegin"));
	s3eEdkCallbacksEnqueue(S3E_EXT_IOSIAD_HASH, S3E_IOSIAD_CALLBACK_AD_STARTING);
	return YES;
}

- (void)bannerViewActionDidFinish:(ADBannerView *)banner
{
	IwTrace(IAD, ("DidFinish"));
	s3eEdkCallbacksEnqueue(S3E_EXT_IOSIAD_HASH, S3E_IOSIAD_CALLBACK_AD_FINISHED);
}

@end

s3eResult s3eIOSIAdInit()
{
	if (s3eEdkIPhoneGetVerMaj() < 4)
	{
		S3E_EXT_ERROR(UNSUPPORTED, ("iAd is only available on iOS 4.0 and newer"));
		return S3E_RESULT_ERROR;
	}
	
	s3eEdkCallbacksRegisterInternal(
		S3E_EDK_INTERNAL,
		S3E_EDK_CALLBACK_MAX,
		S3E_EDK_IPHONE_OSROTATION,
		(s3eCallback)s3eIOSIAdSetOrientation,
		NULL, S3E_FALSE);
		

	return S3E_RESULT_SUCCESS;
}

void s3eIOSIAdTerminate()
{
}

// Swap banner between being positioned on/off the screen
static void moveBanner(bool onScreen)
{
	int banner_height = (int)g_BannerView.bounds.size.height;
	s3eEdkOSOrientation dir = s3eEdkGetOSOrientation();
	if (onScreen)
		IwTrace(IAD_VERBOSE, ("moving banner on screen: height=%d orientation=%d", banner_height, dir));
	else
		IwTrace(IAD_VERBOSE, ("moving banner off screen: height=%d orientation=%d", banner_height, dir));
	
	CGFloat tx = 0;
	CGFloat ty = 0;
	switch (dir)
	{
		case S3E_EDK_OS_ORIENTATION_NORMAL:
			if (onScreen)
				ty = banner_height;
			else
				ty = -banner_height;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT90:
			if (onScreen)
				tx = -banner_height;
			else
				tx = banner_height;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT180:
			if (onScreen)
				ty = -banner_height;
			else
				ty = banner_height;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT270:
			if (onScreen)
				tx = banner_height;
			else
				tx = -banner_height;
			break;
	}
	
	IwTrace(IAD, ("move banner: transform x=%d, y=%d", (int)tx, (int)ty));
	[g_BannerView setCenter:CGPointMake(g_BannerView.center.x+tx, g_BannerView.center.y+ty)];
}

// Update surface view position and size to avoid banner
static void adjustSurfaceView()
{
	s3eEdkOSOrientation dir = s3eEdkGetOSOrientation();
	int banner_height = (int)[ADBannerView sizeFromBannerContentSizeIdentifier:g_BannerView.currentContentSizeIdentifier].height;

	CGRect frame = s3eEdkGetSurfaceUIView().frame;

	IwTrace(IAD, ("adjusting surface view: show=%d orientation=%d height=%d", g_ShowBanner, dir, banner_height));
	
	// adjust the size of the frame to account for the banner_size
	frame.size = s3eEdkGetUIView().frame.size;
	frame.origin = CGPointMake(0, 0);
	if (g_ShowBanner && g_BannerLoaded)
	{
		switch (dir)
		{
			case S3E_EDK_OS_ORIENTATION_NORMAL:
			case S3E_EDK_OS_ORIENTATION_ROT180:
				// shrink the height of the layer frame
				frame.size.height -= banner_height;
				break;
			case S3E_EDK_OS_ORIENTATION_ROT90:
			case S3E_EDK_OS_ORIENTATION_ROT270:
				// shrink the width of the layer frame
				frame.size.width -= banner_height;
				break;
		}
	}

	s3eEdkGetSurfaceUIViewLayer().frame = frame;

	if (g_ShowBanner && g_BannerLoaded)
	{
		switch (dir)
		{
			// also move the origin of the view frame
			case S3E_EDK_OS_ORIENTATION_NORMAL:
				frame.origin.y += banner_height;
				break;
			case S3E_EDK_OS_ORIENTATION_ROT270:
				frame.origin.x += banner_height;
				break;
				// origin stayes the same when add is on the right or the bottom of the the screen
			case S3E_EDK_OS_ORIENTATION_ROT90:
			case S3E_EDK_OS_ORIENTATION_ROT180:
				break;
		}
	}

	s3eEdkGetSurfaceUIView().frame = frame;
	if (s3eEdkGetGLUIView())
	{
		s3eEdkGetGLUIView().frame = frame;
		frame = s3eEdkGetGLUIView().frame;
		IwTrace(IAD_VERBOSE, ("adjusting GLView: %d %d %d %d", (int)frame.size.width, (int)frame.size.height, (int)frame.origin.x, (int)frame.origin.y));
		s3eEdkGLViewUpdateFramebuffer(); //equivalent to [GLView updateFramebuffer]
	}

	// Set s3e Surface size - note scaling from UI coord space to pixels if using high-res scaling (on iPhone 4)
	s3eEdkSurfaceSetSize(false, s3eEdkGetSurfaceUIView().frame.size.width*s3eEdkGetIPhoneScaleFactor(), s3eEdkGetSurfaceUIView().frame.size.height*s3eEdkGetIPhoneScaleFactor());

	[s3eEdkGetUIViewController().view setNeedsLayout];
}

// Banner is "shown" by moving it on/off the screen
void showBanner(bool show)
{
	if (show && !g_ShowBanner)
	{
		g_ShowBanner = show;
		IwTrace(IAD, ("Showing banner"));
		moveBanner(true);
		adjustSurfaceView();
		s3eIOSIAdSetOrientation();
	}

	if (!show && g_ShowBanner)
	{
		g_ShowBanner = show;
		IwTrace(IAD, ("Hiding banner"));
		moveBanner(false);
		adjustSurfaceView();
	}
}

s3eResult s3eIOSIAdSetInt(s3eIOSIAdProperty prop, int32 value)
{
	switch (prop)
	{
		case S3E_IOSIAD_BANNER_SHOW:
			if (!g_BannerView)
			{
				S3E_EXT_ERROR(UNSUPPORTED, ("iAd is only available on iOS 4.0 and newer"));
				return S3E_RESULT_ERROR;
			}
			showBanner((bool)value);
			return S3E_RESULT_SUCCESS;
		default:
			break;
	}
	
	S3E_EXT_ERROR_SIMPLE(PARAM);
	return S3E_RESULT_ERROR;
}

int32 s3eIOSIAdGetInt(s3eIOSIAdProperty prop)
{
	switch (prop)
	{
		case S3E_IOSIAD_RUNNING:
			return g_BannerView != nil;
		case S3E_IOSIAD_BANNER_SHOW:
			return g_ShowBanner;
		case S3E_IOSIAD_BANNER_LOADED:
			return g_BannerLoaded;
		case S3E_IOSIAD_BANNER_WIDTH:
			if (!g_BannerView)
				return 0;
			return g_BannerView.bounds.size.width;
		case S3E_IOSIAD_BANNER_HEIGHT:
			if (!g_BannerView)
				return 0;
			return g_BannerView.bounds.size.height;
		default:
			break;
	}
	S3E_EXT_ERROR_SIMPLE(PARAM);
	return -1;
}

// Update orientation of the banner
void s3eIOSIAdSetOrientation()
{
	// Note that when dealing with native iOS UI code, coordinates and sizes use a DPI-dependant
	// coordinate system rather than absolute pixels: The screen is always 1024x680 on ipad and
	// 480x320 on iphone/ipod, even if an iPhone 4 is using 960x480 high res mode. Orientation is
	// also always normal/portrait since the native view itself does not rotate. Therefore,
	// coordinates must be scaled and/or rotated to s3e pixel-space when needed.
	
	if (!g_BannerView)
		return;

	s3eEdkOSOrientation dir = s3eEdkGetOSOrientation();
	IwTrace(IAD, ("s3eIOSIAdSetOrientation: %d", dir));

	CGAffineTransform transform = CGAffineTransformIdentity;
	CGSize viewSize = s3eEdkGetUIView().bounds.size;


	// Set banner size based on screen.
	// As an example, this demonstrates compile-time checking of iOS SDK version
	// and runtime checking of iOS firmware. The portrait/landsape constants were
	// introduced in 4.2 so won't compile against older SDKs (MAX_ALLOWED gives
	// base sdk) and also may cause an error on firmware too old to support them.
	// We could just use the deprecated 320/etc ones but this is future-proofed
	// against deprecated values being dropped.
	switch (dir)
	{
		case S3E_EDK_OS_ORIENTATION_NORMAL:
		case S3E_EDK_OS_ORIENTATION_ROT180:
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_2
//			if (&ADBannerContentSizeIdentifierPortrait != nil)
//				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
//			else
//#else
				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifier320x50;
//#endif
			break;
		case S3E_EDK_OS_ORIENTATION_ROT90:
		case S3E_EDK_OS_ORIENTATION_ROT270:
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_2
//            if (&ADBannerContentSizeIdentifierLandscape != nil)
//				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifierLandscape;
//			else
//#else
				g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifier480x32;
//#endif
			break;
	}
	
	//[g_BannerView setNeedsLayout];
	
	CGSize bannerSize = [ADBannerView sizeFromBannerContentSizeIdentifier:g_BannerView.currentContentSizeIdentifier];
	CGFloat tx, ty;

	switch (dir)
	{
		case S3E_EDK_OS_ORIENTATION_NORMAL:
			transform = CGAffineTransformIdentity;//CGAffineTransformMakeRotation(degreesToRadian(0));
			tx = viewSize.width/2;
			ty = bannerSize.height/2;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT90:
			transform = CGAffineTransformMakeRotation(degreesToRadian(90));
			tx = viewSize.width - bannerSize.height/2;
			ty = viewSize.height/2;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT180:
			transform = CGAffineTransformMakeRotation(degreesToRadian(180));
			tx = viewSize.width/2;
			ty = viewSize.height - bannerSize.height/2;
			break;
		case S3E_EDK_OS_ORIENTATION_ROT270:
		default:
			transform = CGAffineTransformMakeRotation(degreesToRadian(270));
			ty = viewSize.height/2;
			tx = bannerSize.height/2;
			break;
	}

	IwTrace(IAD, ("s3eIOSIAdSetOrientation transform: x=%d, y=%d", (int)tx, (int)ty));
	
	[g_BannerView setCenter:CGPointMake(tx, ty)];
	//[g_BannerView setTransform:CGAffineTransformTranslate(transform, tx, ty)];
	[g_BannerView setTransform:transform];
	
	if (!g_ShowBanner)
		moveBanner(false);
	
	adjustSurfaceView();
}

s3eResult s3eIOSIAdStart()
{
	if (g_BannerView)
	{
		S3E_EXT_ERROR(STATE, ("iAd is already running"));
		return S3E_RESULT_ERROR;
	}
	
	g_BannerView = [[ADBannerView alloc] initWithFrame:CGRectZero];
	g_BannerView.requiredContentSizeIdentifiers = [NSSet setWithObjects: ADBannerContentSizeIdentifier320x50, ADBannerContentSizeIdentifier480x32, nil];
	g_BannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifier320x50;

	// add delegate
	s3eAdDelegate* delegate = [[s3eAdDelegate alloc] init];
	g_BannerView.delegate = delegate;

	
	// add to the view heirarchy
	[s3eEdkGetUIViewController().view addSubview:g_BannerView];
	[s3eEdkGetUIViewController().view bringSubviewToFront:g_BannerView];

	g_ShowBanner = false;
	g_BannerLoaded = false;

	s3eIOSIAdSetOrientation();
	IwTrace(IAD, ("Started"));
	return S3E_RESULT_SUCCESS;
}

s3eResult s3eIOSIAdStop()
{
	if (!g_BannerView)
	{
		S3E_EXT_ERROR(STATE, ("iAd is not running"));
		return S3E_RESULT_ERROR;
	}
	showBanner(false);
	g_BannerLoaded = false;
	[g_BannerView removeFromSuperview];
	[g_BannerView.delegate release];
	[g_BannerView release];
	g_BannerView = nil;
	IwTrace(IAD, ("Stopped"));
	return S3E_RESULT_SUCCESS;
}

s3eResult s3eIOSIAdCancel()
{
	if (!g_BannerView)
	{
		S3E_EXT_ERROR(STATE, ("iAd is not running"));
		return S3E_RESULT_ERROR;
	}
	[g_BannerView cancelBannerViewAction];
	return S3E_RESULT_SUCCESS;
}
