const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
    checkAdminStatus: () => ipcRenderer.invoke('check-admin-status'),
    restartAsAdmin: () => ipcRenderer.invoke('restart-as-admin'),
    getSystemInfo: () => ipcRenderer.invoke('get-system-info'),
    getScreenSources: () => ipcRenderer.invoke('get-screen-sources'),
    startEnforcement: (config) => ipcRenderer.invoke('proctoring:start-enforcement', config),
    preExamKill: () => ipcRenderer.invoke('proctoring:pre-exam-kill'),

    // Event listeners
    onViolation: (callback) => ipcRenderer.on('proctoring:violation', (event, ...args) => callback(...args)),
    onNetworkRiskUpdate: (callback) => ipcRenderer.on('proctoring:network-risk-update', (event, ...args) => callback(...args)),
});
