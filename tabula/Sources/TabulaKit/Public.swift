// macOne'ın kullandığı genel API (ana iş parçacığından çağır).

/// ⌘X/⌘V Finder kısayollarını başlatır; Erişilebilirlik izni gelene kadar yeniden dener. Birden çok çağrı zararsız.
public func finderShortcutsStart() { startShortcuts() }

/// Olay dinleyicisini ve yeniden deneme zamanlayıcısını kaldırır.
public func finderShortcutsStop() { stopShortcuts() }
