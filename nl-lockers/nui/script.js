/**
 * Warehouse Storage Management System - Laptop UI
 */

const $ = id => document.getElementById(id);
const params = new URLSearchParams(window.location.search);
const IS_DUI = params.get('mode') === 'dui';

if (IS_DUI) document.body.classList.add('dui-mode');

/** Escape for safe use in HTML text and attributes (prevents XSS) */
function escapeHtml(str) {
    if (str == null) return '';
    const s = String(str);
    return s
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function post(name, data = {}) {
    fetch(`https://nl-lockers/${name}`, {
        method: 'POST',
        body: JSON.stringify(data)
    }).catch(() => { });
}

// Notification System
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

/* ═══════════════════════════════════════════════════════════════════════════
   ADMIN PANEL (Preserved)
   ═══════════════════════════════════════════════════════════════════════════ */

if (!IS_DUI) {
    let adminLockers = [];
    let pendingCreateCoords = null;
    let laptopTypingActive = false;

    document.addEventListener('keydown', e => {
        if (laptopTypingActive) {
            e.preventDefault();
            e.stopPropagation();
            if (e.key === 'Escape' || e.key === 'Enter') {
                laptopTypingActive = false;
                post('laptop:inputDone');
                if (e.key === 'Enter') post('laptop:keyPress', { key: 'Enter' });
                return;
            }
            if (e.key.length > 1 && e.key !== 'Backspace') return;
            post('laptop:keyPress', { key: e.key });
            return;
        }
        if (e.key === 'Escape') {
            $('admin-panel')?.classList.add('hidden');
            $('delete-modal')?.classList.add('hidden');
            post('closeUI');
        }
    });

    $('admin-close')?.addEventListener('click', () => {
        $('admin-panel')?.classList.add('hidden');
        post('closeUI');
    });

    $('btn-create')?.addEventListener('click', () => {
        $('admin-panel')?.classList.add('hidden');
        post('admin:pickZone', {});
    });

    $('create-cancel')?.addEventListener('click', () => {
        $('create-inline')?.classList.add('hidden');
        pendingCreateCoords = null;
    });

    $('create-confirm')?.addEventListener('click', () => {
        if (!pendingCreateCoords) return;
        const label = $('create-label')?.value?.trim() || '';
        const price = parseInt($('create-price')?.value) || 0;
        if (!label) { $('create-label')?.focus(); return; }

        $('create-inline')?.classList.add('hidden');

        // Optimistically add to UI (will be replaced with real ID from server)
        const tempId = Date.now(); // Temporary ID
        adminLockers.push({
            id: tempId,
            label: label,
            coords: pendingCreateCoords.coords,
            price: price,
            available: true,
            rental: null
        });
        renderAdminList($('admin-search')?.value || '');

        // Send to server
        post('admin:confirmCreate', {
            label,
            price,
            coords: pendingCreateCoords.coords,
            keypad: pendingCreateCoords.keypad
        });

        pendingCreateCoords = null;
        $('create-label').value = '';
        $('create-price').value = '';
    });

    $('delete-cancel')?.addEventListener('click', () => $('delete-modal')?.classList.add('hidden'));
    $('admin-search')?.addEventListener('input', e => renderAdminList(e.target.value));

    // Store the delete confirmation handler
    let pendingDeleteId = null;

    function renderAdminList(filterText) {
        const list = $('admin-list');
        if (!list) return;
        const total = adminLockers.length;
        const avail = adminLockers.filter(l => l.available).length;
        const rented = total - avail;
        if ($('stat-total')) $('stat-total').textContent = total;
        if ($('stat-available')) $('stat-available').textContent = avail;
        if ($('stat-rented')) $('stat-rented').textContent = rented;
        const query = (filterText || '').toLowerCase().trim();
        const filtered = query
            ? adminLockers.filter(l => String(l.id).includes(query) || (l.label || '').toLowerCase().includes(query))
            : adminLockers;
        if (!filtered.length) {
            list.innerHTML = '<div class="admin-empty">No lockers match your search.</div>';
            return;
        }
        list.innerHTML = filtered.map(l => {
            const status = l.available ? 'available' : 'rented';
            const statusTxt = l.available ? 'Available' : 'Rented';
            const labelSafe = escapeHtml(l.label || 'Locker #' + l.id);
            const ownerSafe = l.rental ? escapeHtml(l.rental.owner || '') : '';
            return `
                <div class="locker-row">
                    <div class="lr-id">#${Number(l.id)}</div>
                    <div class="lr-name">
                        <div class="lr-name-main">${labelSafe}</div>
                        ${l.rental ? `<div class="lr-name-by">${ownerSafe}</div>` : ''}
                    </div>
                    <div><span class="lr-price">${Number(l.price) || 0}</span></div>
                    <div><span class="locker-status ${status}">${statusTxt}</span></div>
                    <div class="locker-actions">
                        <button type="button" class="btn-icon btn-icon--delete" data-locker-id="${Number(l.id)}" data-locker-label="${labelSafe}" title="Delete locker">
                            <i class="fa-solid fa-trash"></i>
                        </button>
                    </div>
                </div>`;
        }).join('');

        list.querySelectorAll('.btn-icon--delete').forEach(btn => {
            btn.addEventListener('click', function () {
                const id = this.getAttribute('data-locker-id');
                const label = this.getAttribute('data-locker-label') || ('#' + id);
                pendingDeleteId = Number(id);
                if ($('delete-label')) $('delete-label').textContent = label;
                $('delete-modal')?.classList.remove('hidden');
            });
        });
    }

    // Handle delete confirmation
    $('delete-confirm')?.addEventListener('click', () => {
        if (!pendingDeleteId) return;

        const idToDelete = pendingDeleteId;
        $('delete-modal')?.classList.add('hidden');

        // Instantly remove from UI
        adminLockers = adminLockers.filter(l => l.id !== idToDelete);
        renderAdminList($('admin-search')?.value || '');

        // Send to server
        post('admin:delete', { id: idToDelete });

        pendingDeleteId = null;
    });

    window.addEventListener('message', e => {
        if (!e.data?.action) return;
        if (e.data.action === 'showAdmin') {
            $('admin-panel')?.classList.remove('hidden');
            renderAdminList();
        }
        if (e.data.action === 'adminData') {
            adminLockers = e.data.lockers || [];
            renderAdminList();
        }
        if (e.data.action === 'showCreateInline') {
            pendingCreateCoords = { coords: e.data.coords, keypad: e.data.keypad };
            $('admin-panel')?.classList.remove('hidden');
            $('create-inline')?.classList.remove('hidden');
            $('create-label')?.focus();
            renderAdminList();
        }
        if (e.data.action === 'laptopTyping') {
            laptopTypingActive = !!e.data.value;
        }
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// SOUND PLAYER — Receives playStorageSound from SendNUIMessage (Lua)
// ═══════════════════════════════════════════════════════════════════════════

window.addEventListener('message', e => {
    if (e.data?.action === 'playStorageSound') {
        const file = e.data.file || 'sound/garagesound.ogg';
        const vol = e.data.volume != null ? e.data.volume : 0.7;
        console.log('[NUI SOUND] Received playStorageSound, file:', file, 'vol:', vol);

        // Method 1: HTML Audio element
        try {
            const audio = new Audio(file);
            audio.volume = vol;
            audio.play()
                .then(() => console.log('[NUI SOUND] Audio.play() succeeded!'))
                .catch(err => console.error('[NUI SOUND] Audio.play() FAILED:', err.message));
        } catch (e1) {
            console.error('[NUI SOUND] new Audio() threw:', e1.message);
        }

        // Method 2: AudioContext (fallback)
        try {
            const ctx = new (window.AudioContext || window.webkitAudioContext)();
            console.log('[NUI SOUND] AudioContext state:', ctx.state);
            fetch(file)
                .then(r => {
                    console.log('[NUI SOUND] fetch status:', r.status);
                    return r.arrayBuffer();
                })
                .then(buf => ctx.decodeAudioData(buf))
                .then(decoded => {
                    const src = ctx.createBufferSource();
                    const gain = ctx.createGain();
                    src.buffer = decoded;
                    gain.gain.value = vol;
                    src.connect(gain).connect(ctx.destination);
                    src.start(0);
                    console.log('[NUI SOUND] AudioContext playback started!');
                })
                .catch(err => console.error('[NUI SOUND] AudioContext FAILED:', err.message));
        } catch (e2) {
            console.error('[NUI SOUND] AudioContext threw:', e2.message);
        }
    }
});

/* ═══════════════════════════════════════════════════════════════════════════
   LAPTOP INTERFACE (DUI Mode) - Handled by laptop.js
   ═══════════════════════════════════════════════════════════════════════════ */

// DUI mode is now handled entirely by laptop.js
// This section is kept for reference but not executed
/*
    let lockerInfo = null;
    const duiCursor = $('dui-cursor');

    // Navigation
    document.querySelectorAll('.nav-btn[data-view]').forEach(btn => {
        btn.addEventListener('click', () => {
            const view = btn.dataset.view;
            if (btn.classList.contains('active')) return;

            document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
            $(`view-${view}`)?.classList.add('active');
        });
    });

    $('nav-exit')?.addEventListener('click', () => post('laptop:close'));

    // Render Dashboard
    function renderDashboard() {
        if (!lockerInfo) return;

        // Unit ID in titlebar
        if ($('titlebar-unit')) $('titlebar-unit').textContent = lockerInfo.label || `#${lockerInfo.id}`;

        // Storage Capacity (usedWeight from server; 0 until ox_inventory integration)
        const used = Number(lockerInfo.usedWeight) || 0;
        const max = Number(lockerInfo.maxWeight) || Number(lockerInfo.weight) || 50000;
        const percent = max > 0 ? Math.min(100, Math.round((used / max) * 100)) : 0;
        if ($('weight-display')) $('weight-display').textContent = `${(used/1000).toFixed(1)} / ${(max/1000)} kg`;
        if ($('capacity-fill')) $('capacity-fill').style.width = percent + '%';
        if ($('capacity-percent')) $('capacity-percent').textContent = percent + '%';

        // Rental Status
        if (lockerInfo.expires_at) {
            const d = new Date(lockerInfo.expires_at * 1000);
            const days = Math.ceil((d.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
            if ($('rental-time')) $('rental-time').textContent = days > 0 ? `${days} Days` : 'Expired';
            if ($('rental-expires')) $('rental-expires').textContent = days > 0 ? `Expires in ${days} days` : 'Lease expired';
        } else {
            if ($('rental-time')) $('rental-time').textContent = '—';
            if ($('rental-expires')) $('rental-expires').textContent = 'No active lease';
        }

        // Security Status
        const secStatus = $('security-status');
        if (secStatus) {
            if (lockerInfo.has_code) {
                secStatus.classList.add('locked');
                secStatus.innerHTML = '<i class="fa-solid fa-lock"></i><span>PIN Set</span>';
            } else {
                secStatus.classList.remove('locked');
                secStatus.innerHTML = '<i class="fa-solid fa-lock-open"></i><span>No PIN</span>';
            }
        }

        // Unit Info
        if ($('info-slots')) $('info-slots').textContent = lockerInfo.slots || 50;
        if ($('info-tier')) $('info-tier').textContent = lockerInfo.upgrade_level || 0;
        if ($('info-access')) $('info-access').textContent = (lockerInfo.invites || []).length;
    }

    // Render Upgrades
    function renderUpgrades() {
        if (!lockerInfo || !lockerInfo.upgradeConfig) return;
        const level = lockerInfo.upgrade_level || 0;
        const max = lockerInfo.upgradeConfig.length;
        if ($('upgrade-current')) $('upgrade-current').textContent = level;
        if ($('upgrade-max')) $('upgrade-max').textContent = max;
        if ($('upgrade-progress')) $('upgrade-progress').style.width = ((level / max) * 100) + '%';

        const grid = $('upgrades-grid');
        if (!grid) return;
        grid.innerHTML = lockerInfo.upgradeConfig.map((u, i) => {
            const tier = i + 1;
            const isUnlocked = tier <= level;
            const isNext = tier === level + 1;
            const classes = ['upgrade-card'];
            if (isUnlocked) classes.push('unlocked');
            if (isNext) classes.push('next');
            if (!isUnlocked && !isNext) classes.push('locked');

            return `
                <div class="${classes.join(' ')}">
                    <div class="upgrade-card-header">
                        <div>
                            <div class="upgrade-card-title">${u.label}</div>
                            <div class="upgrade-card-detail">${u.weight/1000}kg • ${u.slots} slots</div>
                        </div>
                        ${isUnlocked ? '<span class="upgrade-badge unlocked">Unlocked</span>' : ''}
                        ${!isUnlocked && !isNext ? `<span class="upgrade-badge locked">$${u.price.toLocaleString()}</span>` : ''}
                    </div>
                    ${isNext ? `<button class="upgrade-price" onclick="doUpgrade()">Purchase $${u.price.toLocaleString()}</button>` : ''}
                </div>`;
        }).join('');
    }

    window.doUpgrade = function() {
        const btn = event.target;
        btn.classList.add('loading');
        post('laptop:upgrade');
        setTimeout(() => {
            btn.classList.remove('loading');
            showNotification('Upgrade purchased successfully', 'success');
        }, 1000);
    };

    // Render Access List (escape for XSS; use data-cid for remove)
    function renderAccess() {
        const list = $('access-list');
        if (!list) return;
        if (!lockerInfo || !lockerInfo.invites || !lockerInfo.invites.length) {
            list.innerHTML = '<div class="empty-message">No authorized users</div>';
            return;
        }
        list.innerHTML = lockerInfo.invites.map(cid => {
            const cidSafe = escapeHtml(cid);
            return `
            <div class="access-item">
                <span class="access-cid">${cidSafe}</span>
                <button type="button" class="access-remove" data-cid="${cidSafe}" title="Remove access">
                    <i class="fa-solid fa-xmark"></i>
                </button>
            </div>`;
        }).join('');

        list.querySelectorAll('.access-remove').forEach(btn => {
            btn.addEventListener('click', function() {
                const cid = this.getAttribute('data-cid') || '';
                this.classList.add('loading');
                post('laptop:removeInvite', { citizenid: cid });
                setTimeout(() => {
                    this.classList.remove('loading');
                    showNotification('User removed from access list', 'success');
                }, 500);
            });
        });
    }

    // Button Handlers
    $('btn-renew')?.addEventListener('click', function() {
        this.classList.add('loading');
        post('laptop:renew');
        setTimeout(() => {
            this.classList.remove('loading');
            showNotification('Lease renewed successfully', 'success');
        }, 1000);
    });

    $('btn-save-pin')?.addEventListener('click', function() {
        const code = $('input-pin')?.value?.trim() || '';
        this.classList.add('loading');
        post('laptop:setCode', { code });
        setTimeout(() => {
            this.classList.remove('loading');
            this.classList.add('success');
            showNotification(code ? 'PIN saved successfully' : 'PIN removed', 'success');
            setTimeout(() => this.classList.remove('success'), 500);
        }, 500);
        if ($('input-pin')) $('input-pin').value = '';
    });

    $('btn-add-access')?.addEventListener('click', function() {
        const citizenid = $('input-citizen')?.value?.trim() || '';
        if (!citizenid) {
            const input = $('input-citizen');
            if (input) {
                input.style.borderColor = 'var(--accent-red)';
                showNotification('Please enter a Citizen ID', 'error');
                setTimeout(() => input.style.borderColor = '', 500);
            }
            return;
        }
        this.classList.add('loading');
        post('laptop:addInvite', { citizenid });
        setTimeout(() => {
            this.classList.remove('loading');
            this.classList.add('success');
            showNotification('User added to access list', 'success');
            setTimeout(() => this.classList.remove('success'), 500);
        }, 500);
        if ($('input-citizen')) $('input-citizen').value = '';
    });

    // Input Focus Handlers
    $('input-pin')?.addEventListener('focus', () => post('laptop:inputFocused'));
    $('input-citizen')?.addEventListener('focus', () => post('laptop:inputFocused'));
    $('input-pin')?.addEventListener('blur', () => post('laptop:inputDone'));
    $('input-citizen')?.addEventListener('blur', () => post('laptop:inputDone'));

    // Message Handler
    window.addEventListener('message', e => {
        if (!e.data?.type) return;

        if (e.data.type === 'open') {
            lockerInfo = e.data.locker;
            $('terminal')?.classList.remove('hidden');
            duiCursor?.classList.add('visible');
            renderDashboard();
            renderUpgrades();
            renderAccess();
        }

        if (e.data.type === 'close') {
            $('terminal')?.classList.add('hidden');
            duiCursor?.classList.remove('visible');
            lockerInfo = null;
        }

        if (e.data.type === 'cursor') {
            const x = e.data.x, y = e.data.y;
            if (duiCursor) {
                duiCursor.style.left = x + 'px';
                duiCursor.style.top = y + 'px';
            }
            const el = document.elementFromPoint(x, y);
            if (el) el.dispatchEvent(new MouseEvent('mousemove', { clientX: x, clientY: y, bubbles: true }));
        }

        if (e.data.type === 'click') {
            const x = e.data.x, y = e.data.y;
            if (duiCursor) {
                duiCursor.style.left = x + 'px';
                duiCursor.style.top = y + 'px';
            }
            const el = document.elementFromPoint(x, y);
            if (el) {
                if (e.data.pressed) {
                    el.dispatchEvent(new MouseEvent('mousedown', { clientX: x, clientY: y, bubbles: true }));
                } else {
                    el.dispatchEvent(new MouseEvent('mouseup', { clientX: x, clientY: y, bubbles: true }));
                    el.dispatchEvent(new MouseEvent('click', { clientX: x, clientY: y, bubbles: true }));
                    if (el.tagName === 'INPUT') {
                        el.focus();
                        el.dispatchEvent(new Event('focus', { bubbles: true }));
                    } else if (el.tagName === 'BUTTON') {
                        el.focus();
                    }
                }
            }
        }

        if (e.data.type === 'scroll') {
            const x = e.data.x, y = e.data.y;
            const dy = e.data.dy || 0;
            const el = document.elementFromPoint(x, y);
            if (el) {
                let scrollTarget = el;
                while (scrollTarget && scrollTarget !== document.body) {
                    const overflowY = window.getComputedStyle(scrollTarget).overflowY;
                    if ((overflowY === 'auto' || overflowY === 'scroll') && scrollTarget.scrollHeight > scrollTarget.clientHeight) {
                        break;
                    }
                    scrollTarget = scrollTarget.parentElement;
                }
                if (scrollTarget && scrollTarget !== document.body) {
                    scrollTarget.scrollTop -= dy * 30;
                } else {
                    window.scrollBy(0, -dy * 30);
                }
            }
        }

        if (e.data.type === 'key') {
            const active = document.activeElement;
            if (active && active.tagName === 'INPUT') {
                if (e.data.key === 'Backspace') {
                    active.value = active.value.slice(0, -1);
                } else if (e.data.key === 'Enter') {
                    if (active.id === 'input-pin') {
                        const code = active.value.trim();
                        post('laptop:setCode', { code });
                        active.value = '';
                    } else if (active.id === 'input-citizen') {
                        const citizenid = active.value.trim();
                        if (citizenid) post('laptop:addInvite', { citizenid });
                        active.value = '';
                    }
                    active.blur();
                    post('laptop:inputDone');
                } else if (e.data.key && e.data.key.length === 1) {
                    active.value += e.data.key;
                }
            }
        }

        if (e.data.type === 'refreshData' && e.data.locker) {
            lockerInfo = e.data.locker;
            renderDashboard();
            renderUpgrades();
            renderAccess();
        }
    });
*/
// End of commented out DUI code - now handled by laptop.js

