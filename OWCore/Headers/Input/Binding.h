#pragma once
#include "Key.h"
#include "Click.h"
#include "Controller.h"

namespace oi {

	namespace wc {

		enum class BindingType {

			KEYBOARD,
			MOUSE,
			CONTROLLER_BUTTON,
			CONTROLLER_AXIS,

			UNDEFINED = 0xFF

		};

		class Binding {

		public:

			Binding(Key k);
			Binding(Click c);
			Binding(ControllerButton cb, u32 controllerId = 0);
			Binding(ControllerAxis ca, u32 controllerId = 0);

			Binding(OString name);

			//Get as uint
			operator u32();

			BindingType getType();
			u32 getControllerId();
			u32 getCode();

			Key toKey();
			Click toClick();
			ControllerButton toButton();
			ControllerAxis toAxis();

			OString toString();

		private:

			u8 bindingType;
			u8 controllerId;
			u16 code;
		};

	}
}