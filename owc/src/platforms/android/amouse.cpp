#ifdef __ANDROID__

#include "input/mouse.h"
#include "window/windowinterface.h"
#include "window/window.h"
using namespace oi::wc;

void Mouse::update(Window *w, f32 dt) {
	prev = next;
}


#endif