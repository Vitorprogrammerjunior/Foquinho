# Foquinho — build sem CMake: g++ + moc + rcc do Qt6
#
#   make install                    KDE Plasma 6 / Wayland (padrão)
#   make PLATFORM=openbox install   Openbox e outros gerenciadores X11 (sem KDE)
PLATFORM   ?= kde
ifeq ($(PLATFORM),x11)
override PLATFORM := openbox
endif

QT_MODULES := Qt6Quick Qt6Qml Qt6Gui Qt6Core Qt6Network Qt6DBus
CXX        ?= g++
PREFIX     ?= $(HOME)/.local
# Endereço do sistema de demandas sugerido no primeiro uso (opcional):
#   make HUB_SERVER=https://demandas.suaempresa.com.br install
HUB_SERVER ?=
DESTDIR    ?=
MOC        := /usr/lib/qt6/moc
RCC        := /usr/lib/qt6/rcc

ifeq ($(PLATFORM),kde)
PLAT_SRC   := src/platform_kde.cpp
PLAT_FLAGS := -I/usr/include/KF6/KGlobalAccel
PLAT_LIBS  := -lLayerShellQtInterface -lKF6GlobalAccel
else ifeq ($(PLATFORM),openbox)
PLAT_SRC   := src/platform_x11.cpp
PLAT_FLAGS := $(shell pkg-config --cflags xcb xcb-shape)
PLAT_LIBS  := $(shell pkg-config --libs xcb xcb-shape)
else
$(error PLATFORM deve ser kde ou openbox)
endif

B          := build/$(PLATFORM)
CXXFLAGS   += -O2 -std=c++17 -fPIC -Wall -Wextra -Isrc \
              $(shell pkg-config --cflags $(QT_MODULES)) $(PLAT_FLAGS) \
              -DFOCO_HUB_SERVER='"$(HUB_SERVER)"'
LDLIBS     += $(shell pkg-config --libs $(QT_MODULES)) $(PLAT_LIBS)

QML_FILES  := $(wildcard qml/*.qml) qml/qmldir
HEADERS    := src/backend.h src/media.h src/platform.h src/hub.h
OBJS       := $(B)/main.o $(B)/backend.o $(B)/media.o $(B)/hub.o $(B)/platform.o \
              $(B)/moc_backend.o $(B)/moc_media.o $(B)/moc_hub.o $(B)/moc_platform.o $(B)/qrc_resources.o
TARGET     := $(B)/foco-max

all: $(TARGET)

# Recompila o hub quando o HUB_SERVER muda.
$(B)/.hub_server: FORCE
	@mkdir -p $(B)
	@echo '$(HUB_SERVER)' | cmp -s - $@ || echo '$(HUB_SERVER)' > $@
$(B)/hub.o: $(B)/.hub_server
FORCE:
.PHONY: FORCE

$(B):
	@mkdir -p $(B)

$(B)/moc_%.cpp: src/%.h | $(B)
	$(MOC) $< -o $@

$(B)/qrc_resources.cpp: resources.qrc $(QML_FILES) | $(B)
	$(RCC) --name resources $< -o $@

$(B)/platform.o: $(PLAT_SRC) $(HEADERS) | $(B)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(B)/%.o: src/%.cpp $(HEADERS) | $(B)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(B)/moc_%.o: $(B)/moc_%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(B)/qrc_resources.o: $(B)/qrc_resources.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(CXX) -o $@ $^ $(LDLIBS)

install: all
	install -Dm755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/foco-max
	install -Dm644 data/foco-max.svg $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/foco-max.svg
	install -d $(DESTDIR)$(PREFIX)/share/applications
	sed "s|@BIN@|$(PREFIX)/bin/foco-max|g" data/foco-max.desktop.in > $(DESTDIR)$(PREFIX)/share/applications/foco-max.desktop
ifeq ($(PLATFORM),openbox)
	install -Dm644 data/openbox/rc.xml.exemplo $(DESTDIR)$(PREFIX)/share/foco-max/openbox/rc.xml.exemplo
	install -Dm644 data/openbox/menu.xml.exemplo $(DESTDIR)$(PREFIX)/share/foco-max/openbox/menu.xml.exemplo
endif
	@if [ -z "$(DESTDIR)" ]; then update-desktop-database $(PREFIX)/share/applications 2>/dev/null || true; fi

uninstall:
	rm -f $(PREFIX)/bin/foco-max $(PREFIX)/share/applications/foco-max.desktop \
	      $(PREFIX)/share/icons/hicolor/scalable/apps/foco-max.svg $(HOME)/.config/autostart/foco-max.desktop
	rm -rf $(PREFIX)/share/foco-max
	@if [ -f $(HOME)/.config/openbox/autostart ]; then sed -i '/# foquinho/d' $(HOME)/.config/openbox/autostart; fi

run: all
	./$(TARGET)

# atalhos para a versão Openbox
openbox:
	$(MAKE) PLATFORM=openbox
install-openbox:
	$(MAKE) PLATFORM=openbox install

clean:
	rm -rf build

.PHONY: all install uninstall run clean openbox install-openbox
