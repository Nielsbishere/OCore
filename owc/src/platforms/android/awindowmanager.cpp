#include <template/platformdefines.h>

#ifdef __ANDROID__

#include "window/windowmanager.h"
#include <android_native_app_glue.h>
using namespace oi::wc;

void WindowManager::waitAll() {
	
	if(getWindows() != 1)
		Log::throwError<WindowManager, 0x0>("Only one window supported for Android");
	
	initAll();
	
	Window *w = operator[](0);
	struct android_app *state = (struct android_app*) w->info.handle;
	
	while(getWindows() != 0){
		
		int ident, events;
		struct android_poll_source *source;
		
		while((ident = ALooper_pollAll(0, NULL, &events, (void**)&source)) >= 0){
			
			if(source != nullptr)
				source->process(state, source);
			
		}
		
		updateAll();
		
		if(state->destroyRequested != 0){
			Log::println("Destroy requested");
			remove(w);
		}
	}

}


#endif