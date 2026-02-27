const { app, BrowserWindow, ipcMain, desktopCapturer } = require('electron');
const path = require('path');
const { exec } = require('child_process');
const os = require('os');
const si = require('systeminformation');

let mainWindow;

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1200,
        height: 800,
        show: false,
        webPreferences: {
            preload: path.join(__dirname, 'preload.cjs'),
            contextIsolation: true,
            nodeIntegration: false,
        },
        title: "ProctorWatch 3.0"
    });

    const isDev = process.env.VITE_DEV_SERVER_URL || !app.isPackaged;
    const devUrl = 'http://localhost:5173';
    const prodPath = path.join(__dirname, '../dist/index.html');

    if (isDev) {
        mainWindow.loadURL(process.env.VITE_DEV_SERVER_URL || devUrl);
        mainWindow.webContents.openDevTools();
    } else {
        mainWindow.loadFile(prodPath);
    }

    mainWindow.once('ready-to-show', () => {
        mainWindow.show();
    });

    mainWindow.on('closed', () => {
        mainWindow = null;
    });
}

app.whenReady().then(() => {
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

// IPC Handlers
ipcMain.handle('check-admin-status', async () => {
    return new Promise((resolve) => {
        exec('net session', (err) => {
            resolve(!err);
        });
    });
});

ipcMain.handle('restart-as-admin', async () => {
    if (process.platform === 'win32') {
        const { shell } = require('electron');
        const exePath = app.getPath('exe');
        // In dev mode, app.getPath('exe') is electron.exe
        // We might need a different approach for dev vs prod
        app.quit();
        // Simplified for now, real implementation would use ShellExecute with 'runas'
        console.log("Restarting as admin...");
    }
});

ipcMain.handle('get-system-info', async () => {
    const cpu = await si.cpu();
    const mem = await si.mem();
    const osInfo = await si.osInfo();
    return {
        cpu: `${cpu.manufacturer} ${cpu.brand}`,
        ram: `${Math.round(mem.total / (1024 ** 3))} GB`,
        os: `${osInfo.distro} ${osInfo.release}`
    };
});

ipcMain.handle('get-screen-sources', async () => {
    const sources = await desktopCapturer.getSources({ types: ['window', 'screen'] });
    return sources.map(source => ({
        id: source.id,
        name: source.name,
        thumbnail: source.thumbnail.toDataURL()
    }));
});

// Placeholder handlers for enforcement (to be expanded)
ipcMain.handle('proctoring:start-enforcement', async (event, config) => {
    console.log("Starting enforcement with config:", config);
    return { success: true };
});

ipcMain.handle('proctoring:pre-exam-kill', async () => {
    console.log("Pre-exam process cleanup...");
    return { success: true, killed: [] };
});
