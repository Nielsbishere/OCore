#include "graphics/shaderbuffer.h"
#include "graphics/graphics.h"
using namespace oi::gc;
using namespace oi;

///Shader buffer object

ShaderBufferObject::ShaderBufferObject(ShaderBufferObject *parent, u32 offset, u32 length, u32 arraySize, String name, TextureFormat format) : parent(parent), offset(offset), length(length), arraySize(arraySize), name(name), format(format) {}
ShaderBufferObject::ShaderBufferObject() : ShaderBufferObject(nullptr, 0, 0, 0, "", 0) {}

void ShaderBufferObject::addChild(ShaderBufferObject *obj) { childs.push_back(obj); }

ShaderBufferObject *ShaderBufferObject::find(String name) {
	for (ShaderBufferObject *child : childs)
		if (child->name == name)
			return child;
	return nullptr;
}

///Shader buffer info

ShaderBufferInfo::ShaderBufferInfo(ShaderRegisterType type, u32 size, u32 elements, bool allocate) : type(type), size(size), elements(elements), allocate(allocate), self(nullptr, 0, size, 1, "", TextureFormat::Undefined) {}
ShaderBufferInfo::ShaderBufferInfo() : ShaderBufferInfo(ShaderRegisterType::Undefined, 0, 0, false) {}

void ShaderBufferInfo::addRoot(ShaderBufferObject *obj) { self.childs.push_back(obj); }
u32 ShaderBufferInfo::getRoots() { return (u32) self.childs.size(); }

ShaderBufferObject &ShaderBufferInfo::operator[](u32 i) { return elements[i]; }
ShaderBufferObject &ShaderBufferInfo::getRoot(u32 i) { return *self.childs[i]; }

u32 ShaderBufferInfo::lookup(ShaderBufferObject *elem) {

	u32 i = 1U;

	for (ShaderBufferObject &e : elements)
		if (&e == elem) return i;
		else ++i;

	return 0U;
}

ShaderBufferInfo &ShaderBufferInfo::operator=(const ShaderBufferInfo &info) {
	copy(info);
	return *this;
}

ShaderBufferInfo::ShaderBufferInfo(const ShaderBufferInfo &info) {
	copy(info);
}

void ShaderBufferInfo::copy(const ShaderBufferInfo &info) {

	type = info.type;
	size = info.size;
	allocate = info.allocate;
	self = info.self;
	elements = info.elements;

	for (auto &elem : elements) {

		for (auto *&ptr : elem.childs)
			if (ptr == &info.self)
				ptr = &self;
			else
				ptr = elements.data() + (u32)(ptr - info.elements.data());

		if (elem.parent == &info.self)
			elem.parent = &self;
		else
			elem.parent = elements.data() + (u32)(elem.parent - info.elements.data());
	}

}

///ShaderBufferVar

ShaderBufferVar::ShaderBufferVar(ShaderBufferObject &obj, Buffer buf, bool available) : obj(obj), buf(buf), available(available) {}

///ShaderBuffer

const ShaderBufferInfo ShaderBuffer::getInfo() { return info; }

ShaderBufferVar ShaderBuffer::get() {
	return { info.self, current, isOpen }; 
}

u32 ShaderBuffer::getElements(){ return (u32) info.self.childs.size(); }
u32 ShaderBuffer::getSize() { return (u32) info.size; }

void ShaderBuffer::setBuffer(GBuffer *buf) {
	if (buffer == nullptr)
		buffer = buf;
	else
		Log::throwError<ShaderBuffer, 0x0>("Can't set the buffer when it's already set");
}

GBuffer *ShaderBuffer::getBuffer() {
	return buffer;
}

void ShaderBuffer::open() {

	isOpen = true;

	if (buffer != nullptr)
		buffer->open();
	else
		Log::throwError<ShaderBuffer, 0x1>("Can't update a non-existent buffer");

}

void ShaderBuffer::copy(Buffer buf) {

	if (buffer == nullptr || buf.size() == 0U || !isOpen)
		Log::throwError<ShaderBuffer, 0x4>("ShaderBuffer::copy requires a buffer to be set and ShaderBuffer has to be open");

	buffer->copy(buf);

}

void ShaderBuffer::set(Buffer buf) {

	if (buffer == nullptr || buf.size() == 0U)
		Log::throwError<ShaderBuffer, 0x5>("ShaderBuffer::set requires a buffer to be set");

	buffer->set(buf);
}

void ShaderBuffer::close() {

	isOpen = false;

	if (buffer != nullptr)
		buffer->close();
	else
		Log::throwError<ShaderBuffer, 0x2>("Can't update a non-existent buffer");

}

ShaderBuffer::ShaderBuffer(ShaderBufferInfo info): info(info) {}
ShaderBuffer::~ShaderBuffer() {

	if (buffer != nullptr)
		g->destroy(buffer);

	if (info.allocate) 
		current.deconstruct();

}

bool ShaderBuffer::init() {

	if (info.allocate) {
		buffer = g->create(GBufferInfo((info.type.getValue() - 1) / 2, info.size));
		this->current = Buffer(buffer->getSize());
	}

	return true;
}

ShaderBufferVar ShaderBuffer::get(String path) {

	if (path == "") return get();

	ShaderBufferObject *sbo = &info.self;
	u32 offset = 0;

	for (String str : path.split(".")) {

		std::vector<String> strarr = str.split("[");

		if (strarr.size() < 1) {

			if ((sbo = sbo->find(str)) == nullptr)
				Log::throwError<ShaderBufferVar, 0x3>(String("Couldn't find the path \"") + path + "\"");

			offset += sbo->offset;

		} else {

			str = strarr[0];

			//TODO: Look it up

			//test[5][5][5][5].a
			//test[5]
			//test[][5]
			//test[][][5]
			//test[][][][5]
			//test[][][][].a

		}

	}

	return { *sbo, { current.addr() + offset, sbo->length }, isOpen };
}