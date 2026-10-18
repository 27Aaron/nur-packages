# dsh-desktop

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的 Linux 桌面應用程式。上游的 Electron 外殼在 [`apps/desktop`](https://github.com/deepseek-ai/deepseek-harness/tree/master/apps/desktop)，安裝套件只發布 Windows 與 macOS。這個套件不改上游原始碼，只把已經建置好的應用程式配上 nixpkgs 的 Electron，裝成 Linux 上可以啟動的目錄樹。

這個倉庫只發布這一個套件。內建的 dsh 執行環境是桌面應用程式的一部分，沒有單獨的 `dsh` 指令。

版本、原始碼提交與相依雜湊釘在旁邊的 [`hashes.json`](./hashes.json)。

## 安裝

```console
nix build .#dsh-desktop
./result/bin/dsh-desktop
```

或在 NixOS 裡：

```nix
environment.systemPackages = [
  inputs.nur-packages.packages.${pkgs.system}.dsh-desktop
];
```

啟動器裡的名稱是 DeepSeek Harness，指令是 `dsh-desktop`。

## 桌面身分

Wayland 的 app id、X11 的 `WM_CLASS`、`.desktop` 檔名與 `StartupWMClass` 必須是同一個名稱，工作列才能對上圖示。上游清單只有套件名稱 `@deepseek-ai/dsh-desktop`，沒有 `desktopName`。Electron 會把它轉成小寫連字號 slug，視窗回報的就是 `deepseek-ai-dsh-desktop`。這是官方套件名稱的自動結果，不是另外取的品牌名稱。本套件沿用這個 id，不改寫清單。

## 視窗毛玻璃

上游只為 macOS 做了半透明模糊。Linux 上的視窗是透明的，模糊要由合成器自己開啟。niri 26.04 及以上可以加上：

```kdl
window-rule {
    match app-id=r#"^deepseek-ai-dsh-desktop$"#
    background-effect {
        blur true
    }
}
```

沒有這條規則時，視窗只是透明，桌布會直接透出來。niri 實際讀取的檔案由 `NIRI_CONFIG` 決定，不一定是 `~/.config/niri/config.kdl`。如果設定裡已經有不帶 `match`、且 `blur true` 的規則，所有視窗都已經是毛玻璃，不必再加。

## Linux 上補上的行為

這些修補只改打包後的 `resources/app/lib/main.js`。錨點會在建置時核對；上游把對應程式碼移走時，建置會失敗，而不是裝出一個只改了一半的外殼。

- **系統匣。** 關掉視窗只是隱藏，頁面與 Host 仍在執行。上游只在 Windows 上建立系統匣。Linux 使用同一個系統匣：按一下重新開啟，右鍵可以開啟或結束。GNOME 需要 AppIndicator 擴充功能才看得到圖示。
- **通知。** Electron 在 Linux 上透過 `libnotify` 發送通知。找不到函式庫時會悄悄關掉通知，所以啟動器帶上這個函式庫，建置時也會探測一次。
- **選單列。** `DSH_DESKTOP_HIDE_MENUBAR=1`（預設）隱藏選單列，快速鍵仍可使用。設為 `0` 可以重新顯示。
- **訊號結束。** `SIGINT` 與 `SIGTERM` 走外殼自己的清理流程。Host 在獨立行程群組裡啟動，終端機訊號不會把它一起關掉。

## 限制

- 只支援 `x86_64-linux`。
- 自動更新不會生效。上游帶了 `electron-updater`，由 Nix 管理的安裝不會被它更新，升級請走 `nix`。
- 這是下游重新打包，與 DeepSeek 沒有隸屬關係。

## 更新

```console
pkgs/by-name/ds/dsh-desktop/update.sh
```

也可以從倉庫根目錄執行 `nix run .#update-sources`。腳本會先建置候選版本，成功後才改 `hashes.json`。
