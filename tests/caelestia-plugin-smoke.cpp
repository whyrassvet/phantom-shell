#include <QByteArray>
#include <QFile>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>

#include <cstdio>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData(R"QML(
import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.Settings
import Caelestia.Components
import Caelestia.Services
import Caelestia.Models
import Caelestia.Images
import Caelestia.Blobs
import Caelestia.I18n
Item {}
)QML", QUrl());
    QObject *object = component.create();
    if (!object) {
        for (const auto &error : component.errors())
            std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
        return 1;
    }

    QFile maps(QStringLiteral("/proc/self/maps"));
    if (!maps.open(QIODevice::ReadOnly)) {
        std::fprintf(stderr, "Cannot inspect loaded libraries\n");
        delete object;
        return 2;
    }
    const auto buildRoot = qgetenv("PHANTOM_PLUGIN_BUILD");
    if (buildRoot.isEmpty()) {
        std::fprintf(stderr, "PHANTOM_PLUGIN_BUILD is not set\n");
        delete object;
        return 3;
    }
    const auto buildPath = buildRoot + '/';
    const auto lines = maps.readAll().split('\n');
    int found = 0;
    for (const auto &line : lines) {
        if (!line.contains("libcaelestia") || !line.contains("r-xp"))
            continue;
        if (!line.contains(buildPath)) {
            std::fprintf(stderr, "Unexpected Caelestia library: %s\n", line.constData());
            delete object;
            return 3;
        }
        ++found;
    }
    delete object;
    if (found == 0) {
        std::fprintf(stderr, "No Caelestia libraries were loaded\n");
        return 4;
    }
    std::fprintf(stderr, "Loaded %d Caelestia libraries from the private tree\n", found);
    return 0;
}
