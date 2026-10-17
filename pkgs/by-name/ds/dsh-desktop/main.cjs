const { app, BrowserWindow, dialog, shell } = require("electron");
const { spawn } = require("node:child_process");
const path = require("node:path");

const HOST = "127.0.0.1";
const READY_TIMEOUT_MS = 120000;

let server = null;
let mainWindow = null;
let quitting = false;
let serverReady = false;

function serverEnv() {
  const env = { ...process.env };
  // Electron 會為自己的執行檔設定此變數。若保留它，子行程的 Node
  // 會走 Electron 的 run-as-node 路徑。
  delete env.ELECTRON_RUN_AS_NODE;
  return env;
}

function stopServer() {
  if (server === null || server.exitCode !== null || server.signalCode !== null) return;
  const pid = server.pid;
  try {
    process.kill(-pid, "SIGTERM");
  } catch {
    try {
      server.kill("SIGTERM");
    } catch {
      // 伺服器已經結束。
    }
  }
  const timer = setTimeout(() => {
    try {
      process.kill(-pid, "SIGKILL");
    } catch {
      // 伺服器已經結束。
    }
  }, 5000);
  timer.unref();
}

function fail(title, message) {
  quitting = true;
  stopServer();
  dialog.showErrorBox(title, message);
  app.exit(1);
}

function startServer() {
  return new Promise((resolve, reject) => {
    const child = spawn("dsh", ["web", "--no-open", "--host", HOST, "--port", "0"], {
      detached: true,
      env: serverEnv(),
      stdio: ["ignore", "pipe", "pipe"],
    });
    server = child;

    let buffer = "";
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      reject(new Error("DeepSeek Harness did not report a local URL."));
    }, READY_TIMEOUT_MS);

    const finish = (error, url) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (error) reject(error);
      else {
        serverReady = true;
        resolve(url);
      }
    };

    // 就緒那一行含有瀏覽器信任權杖，不要寫進日誌。
    child.stdout.on("data", (chunk) => {
      buffer += chunk.toString();
      const match = buffer.match(/https?:\/\/127\.0\.0\.1:\d+\/\?\S+/);
      if (match) finish(null, match[0]);
    });
    child.stderr.on("data", (chunk) => {
      process.stderr.write(chunk);
    });
    child.on("error", (error) => finish(error));
    child.on("exit", (code, signal) => {
      if (quitting) return;
      const message = `dsh web exited (${signal || code}).`;
      if (!settled) finish(new Error(message));
      else if (serverReady) fail("DeepSeek Harness stopped", message);
    });
  });
}

function createWindow(url) {
  const origin = new URL(url).origin;
  const window = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 840,
    minHeight: 640,
    show: false,
    autoHideMenuBar: true,
    backgroundColor: "#111111",
    icon: path.join(__dirname, "icon.png"),
    title: "DeepSeek Harness",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  mainWindow = window;

  window.once("ready-to-show", () => window.show());
  window.webContents.setWindowOpenHandler(({ url: target }) => {
    if (target.startsWith(origin)) return { action: "allow" };
    shell.openExternal(target);
    return { action: "deny" };
  });
  window.webContents.on("will-navigate", (event, target) => {
    if (target.startsWith(origin)) return;
    event.preventDefault();
    shell.openExternal(target);
  });
  window.webContents.on("did-fail-load", (_event, code, description, _validatedURL, isMainFrame) => {
    if (!isMainFrame || quitting || code === -3) return;
    fail("DeepSeek Harness failed to load", description || `error ${code}`);
  });
  window.webContents.on("render-process-gone", (_event, details) => {
    if (quitting) return;
    fail("DeepSeek Harness crashed", details.reason || "The window renderer exited.");
  });

  window.loadURL(url);
}

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (mainWindow === null || mainWindow.isDestroyed()) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
  });

  app.whenReady().then(async () => {
    try {
      createWindow(await startServer());
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      fail("Could not start DeepSeek Harness", message);
    }
  });

  app.on("before-quit", () => {
    quitting = true;
    stopServer();
  });

  app.on("window-all-closed", () => {
    app.quit();
  });
}
