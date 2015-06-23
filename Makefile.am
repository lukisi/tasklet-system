NULL = 
ACLOCAL_AMFLAGS = -I m4
.PHONY: check

lib_LTLIBRARIES = \
	libntkd-tasklet-system.la \
	$(NULL)

libntkd_tasklet_system_la_SOURCES = \
	ntkd_tasklet.vala \
	$(NULL)

libntkd_tasklet_system_la_VALAFLAGS = \
	-H ntkd-tasklet-system.h \
	--library ntkd-tasklet-system \
	$(NULL)

libntkd_tasklet_system_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(NULL)

libntkd_tasklet_system_la_LIBADD = \
	$(GOBJECT_LIBS) \
	$(NULL)


vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	ntkd-tasklet-system.vapi \
	$(NULL)

include_HEADERS = \
	ntkd-tasklet-system.h \
	$(NULL)

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = \
	ntkd-tasklet-system.pc \
	$(NULL)

EXTRA_DIST = \
	ntkd-tasklet-system.pc.in \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/ntkd-tasklet-system.vapi \
	$(NULL)

ntkd-tasklet-system.vapi: libntkd_tasklet_system_la_vala.stamp

