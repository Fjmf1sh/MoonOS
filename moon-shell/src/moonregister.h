#pragma once

class QQmlApplicationEngine;

namespace Moon {

// Instantiates the Moon OS services and registers them as QML singletons
// under the "MoonOS" import. Called from the patched moonlight-qt main().
void registerTypes(QQmlApplicationEngine* engine);

} // namespace Moon
