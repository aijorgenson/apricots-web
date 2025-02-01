bin_PROGRAMS = apricots

apricots_SOURCES = \
	SDLfont.h \
	ai.cpp \
	all.cpp \
	apricots.cpp \
	collide.cpp \
	data.h \
	fall.cpp \
	game.cpp \
	SDLfont.cpp \
	apricots.h \
	drak.cpp \
	finish.cpp \
	init.cpp \
	sampleio.cpp \
	sampleio.h \
	setup.cpp \
	shape.cpp \
	drawall.cpp \
	linkedlist.h \
	shape.h

apricots_LDADD =

SUBDIRS = data docs

# set the include path found by configure
AM_CPPFLAGS= $(all_includes) -DAP_PATH="\"@prefix@/share/apricots/\"" -DSYSCONFIG_PATH="\"@sysconfdir@\""

# the library search path.
apricots_LDFLAGS = $(all_libraries)

APRICOTS_DATA_FILES = $(srcdir)/data

EXTRA_DIST = $(APRICOTS_DATA_FILES)

install-data-local:
	$(mkinstalldirs) ${DESTDIR}$(pkgdatadir)/
	find "$(APRICOTS_DATA_FILES)" -type f ! -name "Makefile*" -exec $(INSTALL_DATA) {} ${DESTDIR}$(pkgdatadir) \;

uninstall-local:
	-rm -rf ${DESTDIR}$(pkgdatadir)
