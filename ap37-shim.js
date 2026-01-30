// ap37-shim.js
global.ap37 = {
  setTextSize: (n) => {},
  getScreenWidth: () => process.stdout.columns || 120,
  getScreenHeight: () => 40,
  getCornersWidth: () => 1,

  print: (x, y, text, color) => {
    // crude: just log; real AP37 would draw at coords with color
    console.log(text);
  },
  printMultipleColors: (x, y, text, colors) => {
    console.log(text);
  },

  setOnTouchListener: (fn) => {},
  setOnNotificationsListener: (fn) => {},
  setOnAppsListener: (fn) => {},

  // Date + battery
  getDate: () => {
    const d = new Date();
    return {
      year: d.getFullYear(),
      month: d.getMonth() + 1,
      day: d.getDate(),
      hour: d.getHours(),
      minute: d.getMinutes(),
    };
  },
  getBatteryLevel: () => 100,

  // Notifications
  notificationsActive: () => false,
  getNotifications: () => [],

  // Apps
  getApps: () => [],
  openApp: (id) => console.log(`[openApp] ${id}`),
  openNotification: (id) => console.log(`[openNotification] ${id}`),
};
