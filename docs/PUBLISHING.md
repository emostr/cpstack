# Публикация CPStack на GitHub

В репозитории уже есть два workflow GitHub Actions:

| Файл | Когда запускается | Что делает |
|---|---|---|
| `.github/workflows/ci.yml` | push в `master` и каждый pull request | собирает универсальное приложение (Apple Silicon + Intel) и DMG и прикладывает DMG к запуску как артефакт |
| `.github/workflows/release.yml` | push тега `v*`, например `v1.0.0` | собирает, при наличии секретов подписывает и нотаризует, затем создаёт GitHub Release с DMG и `SHA256SUMS.txt` |

Оба запускаются на раннере `macos-26` (Xcode 26).

## 1. Отправить код

Репозиторий уже связан с `https://github.com/emostr/cpstack`. Чтобы отправить новые коммиты, выполните:

```bash
cd ~/cpstack
git push origin master
```

Если нужно опубликовать проект в другом репозитории, создайте пустой репозиторий на github.com (без README, .gitignore и лицензии: они уже есть в проекте) и смените адрес:

```bash
git remote set-url origin https://github.com/<логин>/<репозиторий>.git
git push -u origin master
```

Затем откройте вкладку **Actions**: workflow **CI** соберёт проект. Готовый DMG появится внизу страницы запуска, в блоке **Artifacts**.

> Если Actions выключены, включите их в **Settings → Actions → General → Allow all actions**.
> Для релизов в том же разделе в **Workflow permissions** должно быть **Read and write permissions**. Workflow сам запрашивает `contents: write`, но настройки организации могут это запрещать.

## 2. Выпустить релиз

Версия берётся из тега: тег `v1.2.0` даёт `CPStack-1.2.0.dmg` и версию 1.2.0 в окне «О программе».

```bash
git tag v1.0.0
git push origin v1.0.0
```

Через 5–10 минут на странице **Releases** появится релиз «CPStack 1.0.0». В нём будут DMG, контрольная сумма и список изменений, который GitHub составит автоматически по коммитам.

Следующий релиз выпускается так же: закоммитьте изменения, поставьте новый тег (`v1.0.1`) и отправьте его.

Если нужно пересобрать релиз с тем же номером, удалите тег и поставьте его заново:

```bash
git tag -d v1.0.0 && git push origin :refs/tags/v1.0.0
git tag v1.0.0 && git push origin v1.0.0
```

## 3. Подпись и нотаризация (необязательно)

Без сертификата приложение подписывается ad-hoc. Всё работает, но при первом запуске macOS предупредит, что разработчик не проверен. Пользователю придётся нажать **Системные настройки → Конфиденциальность и безопасность → «Всё равно открыть»**. Это описано в README.

Чтобы предупреждения не было, нужен аккаунт [Apple Developer Program](https://developer.apple.com/programs/) (99 $ в год) и пять секретов в **Settings → Secrets and variables → Actions → New repository secret**:

| Секрет | Что это | Где взять |
|---|---|---|
| `MACOS_CERTIFICATE` | сертификат **Developer ID Application** в base64 | Xcode → Settings → Accounts → Manage Certificates → «+» → Developer ID Application. Затем в «Связке ключей» экспортируйте его вместе с ключом в `.p12` и выполните `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PASSWORD` | пароль, заданный при экспорте `.p12` | — |
| `APPLE_ID` | e-mail Apple ID разработчика | — |
| `APPLE_TEAM_ID` | Team ID из 10 символов | developer.apple.com → Membership details |
| `APPLE_APP_PASSWORD` | пароль приложения для нотаризации | account.apple.com → Вход и безопасность → Пароли приложений |

Когда секреты заданы, `release.yml` сам:

1. импортирует сертификат во временную связку ключей;
2. подпишет приложение с hardened runtime;
3. отправит DMG на нотаризацию (`notarytool`) и прикрепит к нему результат (`stapler`).

Если секретов нет, эти шаги пропускаются, и сборка проходит без них.

## 4. Как собрать то же самое локально

```bash
make dmg                                   # build/CPStack-1.0.0.dmg
VERSION=1.1.0 BUILD_NUMBER=7 make dmg      # с другой версией
CODESIGN_IDENTITY="Developer ID Application: Имя (TEAMID)" make dmg
```

Оформление DMG описано в двух файлах:

- `Scripts/make-dmg-background.swift` — фон окна со стрелкой и подписями;
- `Scripts/dmg-settings.py` — размер окна, позиции значков, иконка тома.

Если двигаете значки, координаты в обоих файлах должны совпадать.

## 5. Частые проблемы

- **`No runner matching macos-26`**. Значит, GitHub ещё не выдаёт этот образ вашему аккаунту. Поменяйте `runs-on` на `macos-latest`, но только если в нём есть Xcode 26 или новее: проекту нужен SDK macOS 26 ради Liquid Glass.
- **Релиз не создаётся, ошибка 403**. Проверьте **Workflow permissions** (см. шаг 1).
- **`notarytool` возвращает `Invalid`**. Посмотрите подробный журнал командой `xcrun notarytool log <submission-id> --apple-id … --team-id … --password …`. Обычно причина в том, что сертификат не Developer ID Application.
