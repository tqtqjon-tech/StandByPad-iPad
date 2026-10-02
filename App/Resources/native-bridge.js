(() => {
  'use strict';
  const battery = new EventTarget();
  Object.assign(battery, {level: null, charging: null, chargingTime: Infinity, dischargingTime: Infinity,
    onlevelchange: null, onchargingchange: null});
  const connection = new EventTarget();
  connection.type = 'unknown';
  let state = null;
  let resolveBattery;
  const readyBattery = new Promise(resolve => { resolveBattery = resolve; });
  const emit = (target, name) => {
    const event = new Event(name);
    target.dispatchEvent(event);
    if (typeof target['on' + name] === 'function') target['on' + name].call(target, event);
  };
  Object.defineProperty(navigator, 'getBattery', {value: () => readyBattery, configurable: true});
  Object.defineProperty(navigator, 'connection', {get: () => connection, configurable: true});
  // Preserve WebKit's value until the first native network observation.
  const webOnline = navigator.onLine;
  Object.defineProperty(navigator, 'onLine', {get: () => state?.network.online ?? webOnline, configurable: true});
  const api = new EventTarget();
  Object.defineProperty(api, 'state', {get: () => state});
  api.refresh = () => window.webkit.messageHandlers.standByPad.postMessage('getState');
  api._receive = next => {
    const previous = state;
    state = next;
    if (next.battery.level !== null && next.battery.charging !== null) {
      const oldLevel = battery.level, oldCharging = battery.charging;
      battery.level = next.battery.level;
      battery.charging = next.battery.charging;
      battery.state = next.battery.state;
      resolveBattery(battery);
      if (oldLevel !== battery.level) emit(battery, 'levelchange');
      if (oldCharging !== battery.charging) emit(battery, 'chargingchange');
    }
    if (connection.type !== next.network.type) {
      connection.type = next.network.type;
      emit(connection, 'change');
    }
    if (next.network.online !== null && previous?.network.online !== next.network.online) {
      window.dispatchEvent(new Event(next.network.online ? 'online' : 'offline'));
    }
    api.dispatchEvent(new CustomEvent('statechange', {detail: next}));
    window.dispatchEvent(new CustomEvent('standbypad-native-state', {detail: next}));
    // Upstream only recognizes wifi/cellular. Keep its indicator accurate for Ethernet too.
    const indicator = document.getElementById('deviceStatus');
    if (indicator) indicator.dataset.network = next.network.type;
  };
  window.StandByPadNative = api;
  api.refresh();
  document.addEventListener('DOMContentLoaded', api.refresh);
})();
