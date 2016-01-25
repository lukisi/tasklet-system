NULL = 
ACLOCAL_AMFLAGS = -I m4
.PHONY: check

lib_LTLIBRARIES = \
	libtasklet-system.la \
	$(NULL)

libtasklet_system_la_SOURCES = \
	tasklet_system.vala \
	$(NULL)

libtasklet_system_la_VALAFLAGS = \
	-H tasklet-system.h \
	--library tasklet-system \
	--pkg gee-0.8 \
	$(NULL)

libtasklet_system_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libtasklet_system_la_LIBADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NULL)


vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	tasklet-system.vapi \
	$(NULL)

include_HEADERS = \
	tasklet-system.h \
	$(NULL)

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = \
	tasklet-system.pc \
	$(NULL)

EXTRA_DIST = \
	tasklet-system.pc.in \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/tasklet-system.vapi \
	$(NULL)

tasklet-system.vapi: libtasklet_system_la_vala.stamp

