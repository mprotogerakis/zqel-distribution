# zqel-distribution

Die **ausgelieferten Binärpakete** von zqel — und nichts sonst.

Gebaut wird in einem eigenen, nicht-öffentlichen Baum; hier landet nur, was
alle Tore bestanden hat. Der Quelltext liegt bewusst nicht bei: ein Paket
trägt ein Binary und die Verträge, gegen die man übersetzt.

## Was hier liegt

| Release | Bedeutung |
|---|---|
| `nightly` | beweglicher Zeiger auf den letzten **grünen** Bau. Die Assets werden bei jedem Lauf ersetzt. |
| `v…` | getaggte Versionen. Unveränderlich. |

Zu jedem Archiv liegt ein `.sha256` daneben. Nachrechnen:

```sh
curl -fLO https://github.com/mprotogerakis/zqel-distribution/releases/download/nightly/zqel-nightly-linux-x86_64.tar.gz
curl -fLO https://github.com/mprotogerakis/zqel-distribution/releases/download/nightly/zqel-nightly-linux-x86_64.tar.gz.sha256
sha256sum -c zqel-nightly-linux-x86_64.tar.gz.sha256
```

## Was ein Paket über sich selbst sagt

```sh
./zqel/zqel --version
./zqel/zqel toolchain --json
```

`toolchain --json` nennt den Beweiser, mit dem dieses Paket rechnet, und ob er
der gepinnte ist. Eine Versionsangabe allein sagt das **nicht**: zwei Bauten
mit derselben Zahl können mit verschiedenen Beweisern gerechnet haben.

## Stand

Frisch angelegt am 2026-09-19. Noch liegt nichts hier — die Auslieferung zieht
gerade von `dl.zqel.org` hierher um.
