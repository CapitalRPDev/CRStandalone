class MusicPlayer {
    constructor(config) {
        this.config = config;
        this.song = config.music.songs[0];
        this.isPlaying = false;
        this.audio = new Audio();
        this.audio.volume = config.music.initialVolume || 0.5;
        this.audio.loop = true;
        this.init();
    }

    init() {
        this.audio.src = this.song.file;
        this.audio.load();

        this.createSpaceHint();

        if (this.config.music.autoplay) {
            this.audio.play().then(() => {
                this.isPlaying = true;
                this.updateHint();
            }).catch(error => {
                console.error('Autoplay blocked:', error);
            });
        }

        window.addEventListener('keydown', (event) => {
            if (event.code === 'Space') {
                event.preventDefault();
                this.togglePlay();
            }
        });
    }

    createSpaceHint() {
        const hint = document.createElement('div');
        hint.id = 'space-hint';
        hint.innerHTML = `
            <span class="hint-key">SPACE</span>
            <span class="hint-label" id="hint-label">Pause Music</span>
        `;
        document.body.appendChild(hint);
    }

    togglePlay() {
        if (this.isPlaying) {
            this.audio.pause();
            this.isPlaying = false;
        } else {
            this.audio.play().catch(e => console.error('Playback error:', e));
            this.isPlaying = true;
        }
        this.updateHint();
    }

    updateHint() {
        const label = document.getElementById('hint-label');
        if (label) label.textContent = this.isPlaying ? 'Pause Music' : 'Play Music';
    }
}

function initMusicPlayer(config) {
    new MusicPlayer(config);
}