// Laptop UI Script - Simplified
// Note: $ function and IS_DUI are already declared in script.js

// Debug flag - set via URL parameter or default to false
const DEBUG = new URLSearchParams(window.location.search).get('debug') === 'true' || false;

// Debug logging helper
function debugLog(...args) {
    if (DEBUG) console.log(...args);
}

// Initial debug logs
debugLog('[LAPTOP.JS] Script loaded');
debugLog('[LAPTOP.JS] IS_DUI:', IS_DUI);
debugLog('[LAPTOP.JS] URL:', window.location.href);

function showNotification(message, type = 'success') {
    const existing = document.querySelector('.notification');
    if (existing) existing.remove();

    const notif = document.createElement('div');
    notif.className = `notification ${type}`;
    notif.innerHTML = `
        <div class="notification-icon">
            <i class="fa-solid fa-${type === 'success' ? 'check-circle' : 'exclamation-circle'}"></i>
        </div>
        <div class="notification-text">${message}</div>
    `;
    document.body.appendChild(notif);

    setTimeout(() => {
        notif.style.animation = 'slideIn 0.3s ease-out reverse';
        setTimeout(() => notif.remove(), 300);
    }, 3000);
}

let lockerInfo = null;
let isWindowOpen = false;
let currencySymbol = '$';
const duiCursor = $('dui-cursor');

function hexToRgba(hex, a) {
    const m = hex.slice(1).match(/(.{2})/g);
    if (!m) return 'rgba(14, 165, 233, 0.15)';
    const [r, g, b] = m.map(x => parseInt(x, 16));
    return `rgba(${r},${g},${b},${a})`;
}

function applyUITheme(ui) {
    if (!ui) return;
    const root = document.documentElement;
    if (ui.accent) {
        root.style.setProperty('--accent', ui.accent);
        root.style.setProperty('--accent-hover', ui.accentHover || ui.accent);
        root.style.setProperty('--accent-muted', hexToRgba(ui.accent, 0.15));
    }
    if (ui.currency != null) currencySymbol = ui.currency;
}

// In DUI mode, ensure terminal is visible on load
if (IS_DUI) {
    debugLog('[LAPTOP.JS] DUI mode detected, setting up...');
    document.addEventListener('DOMContentLoaded', () => {
        debugLog('[LAPTOP.JS] DOM loaded');
        const terminal = document.getElementById('terminal');
        const desktopBg = document.querySelector('.desktop-bg');
        const taskbar = document.querySelector('.taskbar');
        const desktopIcon = document.getElementById('storage-icon');

        debugLog('[LAPTOP.JS] Terminal element:', terminal);
        debugLog('[LAPTOP.JS] Desktop BG:', desktopBg);
        debugLog('[LAPTOP.JS] Taskbar:', taskbar);
        debugLog('[LAPTOP.JS] Desktop Icon:', desktopIcon);

        if (terminal) {
            terminal.classList.remove('hidden');
            debugLog('[LAPTOP.JS] Terminal made visible');
            debugLog('[LAPTOP.JS] Terminal display:', window.getComputedStyle(terminal).display);
            debugLog('[LAPTOP.JS] Terminal background:', window.getComputedStyle(terminal).background);
        } else {
            console.error('[LAPTOP.JS] Terminal element not found!');
        }

        if (desktopBg) {
            debugLog('[LAPTOP.JS] Desktop BG display:', window.getComputedStyle(desktopBg).display);
            debugLog('[LAPTOP.JS] Desktop BG background:', window.getComputedStyle(desktopBg).background);
        }

        debugLog('[LAPTOP.JS] Body classes:', document.body.className);
    });
} else {
    debugLog('[LAPTOP.JS] Not in DUI mode');
}

// Update clock
function updateClock() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    if ($('clock')) $('clock').textContent = `${hours}:${minutes}`;
}
setInterval(updateClock, 1000);
updateClock();

// Desktop Icon Click - Open Window
$('storage-icon')?.addEventListener('click', () => {
    debugLog('[LAPTOP.JS] Desktop icon clicked, isWindowOpen:', isWindowOpen);
    if (isWindowOpen) return;
    openWindow();
});

// Taskbar App Click - Show/Hide Window
$('taskbar-storage')?.addEventListener('click', () => {
    if (isWindowOpen) {
        minimizeWindow();
    } else {
        openWindow();
    }
});

function openWindow() {
    debugLog('[LAPTOP.JS] openWindow called');
    const windowEl = $('storage-window');
    const taskbarApp = $('taskbar-storage');
    const desktopIcon = $('storage-icon');

    debugLog('[LAPTOP.JS] Window:', windowEl, 'Taskbar:', taskbarApp, 'Icon:', desktopIcon);

    if (windowEl && taskbarApp) {
        windowEl.classList.remove('hidden', 'minimized');
        taskbarApp.classList.add('active');
        if (desktopIcon) desktopIcon.style.display = 'none';
        isWindowOpen = true;
        debugLog('[LAPTOP.JS] Window opened');
    } else {
        console.error('[LAPTOP.JS] Missing elements for opening window');
    }
}

function minimizeWindow() {
    const windowEl = $('storage-window');
    const taskbarApp = $('taskbar-storage');
    const desktopIcon = $('storage-icon');

    if (windowEl && taskbarApp) {
        windowEl.classList.add('minimized');
        setTimeout(() => {
            windowEl.classList.add('hidden');
            windowEl.classList.remove('minimized');
            if (desktopIcon) desktopIcon.style.display = 'flex';
        }, 300);
        taskbarApp.classList.remove('active');
        isWindowOpen = false;
    }
}

// Window Controls
$('btn-minimize')?.addEventListener('click', () => minimizeWindow());
$('nav-exit')?.addEventListener('click', () => {
    minimizeWindow();
    setTimeout(() => post('laptop:close'), 300);
});

// Render Data
function renderData() {
    if (!lockerInfo) return;

    // Status Bar
    if ($('unit-name')) $('unit-name').textContent = lockerInfo.label || `#${lockerInfo.id}`;

    // Storage Capacity
    const used = Number(lockerInfo.usedWeight) || 0;
    const max = Number(lockerInfo.maxWeight) || Number(lockerInfo.weight) || 50000;
    const usedKg = (used / 1000).toFixed(1);
    const maxKg = (max / 1000);

    if ($('storage-capacity')) {
        $('storage-capacity').textContent = `${usedKg} / ${maxKg} kg`;
    }

    // Rental Days + Overview expiry warning
    const expiryEl = $('expiry-warning');
    if (lockerInfo.expires_at) {
        const d = new Date(lockerInfo.expires_at * 1000);
        const days = Math.ceil((d.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
        if ($('rental-days')) {
            $('rental-days').textContent = days > 0 ? `${days} days` : 'Expired';
        }
        if (expiryEl) {
            if (days <= 0) {
                expiryEl.className = 'expiry-warning danger';
                expiryEl.innerHTML = '<i class="fas fa-exclamation-circle"></i><span>Rental expired. Renew in the Rental tab to keep access.</span>';
                expiryEl.classList.remove('hidden');
            } else if (days <= 2) {
                expiryEl.className = 'expiry-warning warning';
                expiryEl.innerHTML = `<i class="fas fa-clock"></i><span>Expires in ${days} day${days === 1 ? '' : 's'}. Renew soon.</span>`;
                expiryEl.classList.remove('hidden');
            } else {
                expiryEl.classList.add('hidden');
            }
        }
    } else {
        if ($('rental-days')) $('rental-days').textContent = '—';
        if (expiryEl) expiryEl.classList.add('hidden');
    }

    // Security Status
    const secStatus = $('security-status');
    const removePinBtn = $('btn-remove-pin');
    if (secStatus) {
        if (lockerInfo.has_code) {
            secStatus.classList.add('success');
            secStatus.innerHTML = '<i class="fas fa-lock"></i><span>PIN code is set</span>';
            if (removePinBtn) removePinBtn.style.display = 'flex';
        } else {
            secStatus.classList.remove('success');
            secStatus.innerHTML = '<i class="fas fa-lock-open"></i><span>No PIN set</span>';
            if (removePinBtn) removePinBtn.style.display = 'none';
        }
    }

    // Selected days sync with server renewDays; default active button
    const renewDays = lockerInfo?.renewDays || 7;
    selectedDays = renewDays;
    $('duration-options')?.querySelectorAll('.duration-btn').forEach(btn => {
        btn.classList.toggle('active', parseInt(btn.dataset.days) === renewDays);
    });
    updateRentalPrice();

    // Upgrade Info
    const baseKg = (Number(lockerInfo.weight) || 50000) / 1000;
    const cfg = lockerInfo.upgradeConfig || [];
    const level = lockerInfo.upgrade_level || 0;
    let currentKg = baseKg;
    for (let i = 0; i < level; i++) currentKg += (cfg[i]?.weight || 0) / 1000;
    const nextTier = cfg[level];
    const nextKg = nextTier ? currentKg + (nextTier.weight / 1000) : currentKg;
    const upgradePrice = nextTier?.price || 0;
    if ($('upgrade-current')) $('upgrade-current').textContent = `${currentKg} kg`;
    if ($('upgrade-next')) $('upgrade-next').textContent = nextTier ? `${nextKg} kg` : '—';
    if ($('upgrade-price')) $('upgrade-price').textContent = upgradePrice ? `${currencySymbol}${upgradePrice}` : '—';
    const btnUpgrade = $('btn-upgrade');
    if (btnUpgrade) btnUpgrade.style.display = nextTier ? 'inline-flex' : 'none';

    renderAccessList();
    updateRentalPrice();
}

// Render Access List
function renderAccessList() {
    const list = $('access-list');
    if (!list) return;
    if (!lockerInfo || !lockerInfo.invites || !lockerInfo.invites.length) {
        list.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-user-slash"></i>
                <p>No players authorized</p>
            </div>`;
        return;
    }
    list.innerHTML = lockerInfo.invites.map(cid => {
        const cidSafe = escapeHtml(cid);
        return `
        <div class="user-item">
            <div class="user-info">
                <i class="fas fa-user"></i>
                <span class="user-id">${cidSafe}</span>
            </div>
            <button type="button" class="btn-remove" data-cid="${cidSafe}">
                <i class="fas fa-xmark"></i>
            </button>
        </div>`;
    }).join('');

    list.querySelectorAll('.btn-remove').forEach(btn => {
        btn.addEventListener('click', function () {
            const cid = this.getAttribute('data-cid') || '';
            this.classList.add('loading');
            post('laptop:removeInvite', { citizenid: cid });
            setTimeout(() => {
                this.classList.remove('loading');
                showNotification('User removed', 'success');
            }, 500);
        });
    });
}

// Button Handlers
$('btn-open-storage')?.addEventListener('click', function () {
    post('laptop:openStorage');
});

$('btn-renew')?.addEventListener('click', function () {
    this.classList.add('loading');
    post('laptop:renew', { days: selectedDays });
    setTimeout(() => {
        this.classList.remove('loading');
        showNotification('Rental renewed', 'success');
    }, 1000);
});

$('btn-upgrade')?.addEventListener('click', function () {
    this.classList.add('loading');
    post('laptop:upgrade');
    setTimeout(() => {
        this.classList.remove('loading');
        showNotification('Storage upgraded', 'success');
    }, 1000);
});

$('btn-save-pin')?.addEventListener('click', function () {
    const code = $('input-pin')?.value?.trim() || '';
    this.classList.add('loading');
    post('laptop:setCode', { code });
    setTimeout(() => {
        this.classList.remove('loading');
        showNotification(code ? 'PIN saved' : 'PIN removed', 'success');
    }, 500);
    if ($('input-pin')) $('input-pin').value = '';
});

$('btn-add-access')?.addEventListener('click', function () {
    const citizenid = $('input-citizen')?.value?.trim() || '';
    if (!citizenid) {
        showNotification('Enter a Citizen ID', 'error');
        return;
    }
    this.classList.add('loading');
    post('laptop:addInvite', { citizenid });
    setTimeout(() => {
        this.classList.remove('loading');
        showNotification('User added', 'success');
    }, 500);
    if ($('input-citizen')) $('input-citizen').value = '';
});

// Rental duration preset buttons
let selectedDays = 14;

function updateRentalPrice() {
    const renewPrice = lockerInfo?.renewPrice || 5000;
    const renewDays = lockerInfo?.renewDays || 7;
    const pricePerDay = Math.ceil(renewPrice / renewDays);
    const totalPrice = selectedDays * pricePerDay;
    if ($('rental-price')) $('rental-price').textContent = `${currencySymbol}${totalPrice}`;
}

function initDurationButtons() {
    const container = $('duration-options');
    if (!container) return;
    container.querySelectorAll('.duration-btn').forEach(btn => {
        btn.addEventListener('click', function () {
            container.querySelectorAll('.duration-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            selectedDays = parseInt(this.dataset.days) || 7;
            updateRentalPrice();
        });
    });
}
initDurationButtons();

// Side tab switching
document.querySelectorAll('.side-tab').forEach(tab => {
    tab.addEventListener('click', function () {
        const target = this.dataset.tab;
        document.querySelectorAll('.side-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
        this.classList.add('active');
        const panel = document.getElementById('panel-' + target);
        if (panel) panel.classList.add('active');
    });
});

// Remove PIN Button
$('btn-remove-pin')?.addEventListener('click', function () {
    this.classList.add('loading');
    post('laptop:setCode', { code: '' });
    setTimeout(() => {
        this.classList.remove('loading');
        showNotification('PIN removed', 'success');
    }, 500);
});

// Input Focus
$('input-pin')?.addEventListener('focus', () => post('laptop:inputFocused'));
$('input-citizen')?.addEventListener('focus', () => post('laptop:inputFocused'));
$('input-pin')?.addEventListener('blur', () => post('laptop:inputDone'));
$('input-citizen')?.addEventListener('blur', () => post('laptop:inputDone'));

// Message Handler
window.addEventListener('message', e => {
    debugLog('[LAPTOP.JS] Message received:', e.data);

    if (!e.data?.type) return;

    if (e.data.type === 'open') {
        debugLog('[LAPTOP.JS] Opening laptop with data:', e.data.locker);
        applyUITheme(e.data.ui);
        lockerInfo = e.data.locker;
        const terminal = $('terminal');
        if (terminal) {
            terminal.classList.remove('hidden');
            debugLog('[LAPTOP.JS] Terminal shown, display:', window.getComputedStyle(terminal).display);
        }
        if (duiCursor) duiCursor.classList.add('visible');
        renderData();
        // Auto-open Storage Manager so user doesn't need to click the icon (DUI clicks can miss small targets)
        openWindow();
    }

    if (e.data.type === 'close') {
        debugLog('[LAPTOP.JS] Closing laptop');
        $('terminal')?.classList.add('hidden');
        if (duiCursor) duiCursor.classList.remove('visible');
        lockerInfo = null;
        isWindowOpen = false;
    }

    if (e.data.type === 'refreshData' && e.data.locker) {
        debugLog('[LAPTOP.JS] Refreshing data:', e.data.locker);
        lockerInfo = e.data.locker;
        renderData();
    }

    // Cursor movement
    if (e.data.type === 'cursor') {
        const x = e.data.x, y = e.data.y;
        if (duiCursor) {
            duiCursor.style.left = x + 'px';
            duiCursor.style.top = y + 'px';
        }
        const el = document.elementFromPoint(x, y);
        if (el) el.dispatchEvent(new MouseEvent('mousemove', { clientX: x, clientY: y, bubbles: true }));
    }

    // Click events
    if (e.data.type === 'click') {
        const x = e.data.x, y = e.data.y;
        if (duiCursor) {
            duiCursor.style.left = x + 'px';
            duiCursor.style.top = y + 'px';
        }
        const el = document.elementFromPoint(x, y);
        debugLog('[LAPTOP.JS] Click at', x, y, 'element:', el?.tagName, el?.id, el?.className);
        if (el) {
            if (e.data.pressed) {
                el.dispatchEvent(new MouseEvent('mousedown', { clientX: x, clientY: y, bubbles: true }));
            } else {
                el.dispatchEvent(new MouseEvent('mouseup', { clientX: x, clientY: y, bubbles: true }));
                el.click();
                debugLog('[LAPTOP.JS] Clicked element:', el);
                if (el.tagName === 'INPUT') {
                    el.focus();
                } else if (el.tagName === 'BUTTON') {
                    el.focus();
                }
            }
        }
    }

    // Scroll events — find scrollable ancestor and scroll directly (CEF WheelEvent can be unreliable)
    if (e.data.type === 'scroll') {
        const x = e.data.x, y = e.data.y;
        const dy = e.data.dy || 0;
        const el = document.elementFromPoint(x, y);
        if (el && dy !== 0) {
            let scrollTarget = el;
            while (scrollTarget && scrollTarget !== document.body) {
                const style = window.getComputedStyle(scrollTarget);
                const overflowY = style.overflowY;
                if ((overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'overlay') &&
                    scrollTarget.scrollHeight > scrollTarget.clientHeight) {
                    scrollTarget.scrollTop -= dy * 40;
                    break;
                }
                scrollTarget = scrollTarget.parentElement;
            }
        }
    }

    // Keyboard events
    if (e.data.type === 'key') {
        const focused = document.activeElement;
        if (focused && focused.tagName === 'INPUT') {
            if (e.data.key === 'Backspace') {
                focused.value = focused.value.slice(0, -1);
                focused.dispatchEvent(new Event('input', { bubbles: true }));
            } else if (e.data.key.length === 1) {
                focused.value += e.data.key;
                focused.dispatchEvent(new Event('input', { bubbles: true }));
            }
        }
    }

    // Sound playback (DUI has user interaction so CEF allows audio)
    if (e.data.type === 'playSound') {
        const file = e.data.file || 'sound/garagesound.ogg';
        const vol = e.data.volume != null ? e.data.volume : 0.7;
        console.log('[DUI SOUND] Received playSound, file:', file, 'vol:', vol);
        try {
            const audio = new Audio(file);
            audio.volume = vol;
            audio.play()
                .then(() => console.log('[DUI SOUND] Audio.play() succeeded!'))
                .catch(err => console.error('[DUI SOUND] Audio.play() FAILED:', err.message));
        } catch (ex) {
            console.error('[DUI SOUND] Error:', ex.message);
        }
    }
});
