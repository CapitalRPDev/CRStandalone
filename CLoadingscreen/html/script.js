async function loadConfig() {
    try {
        const response = await fetch('config.json');
        const config = await response.json();
        applyConfig(config);
    } catch (error) {
        console.error('Error loading configuration:', error);
    }
}

function applyConfig(config) {
    const backgroundOverlay = document.querySelector('.background-overlay');
    backgroundOverlay.style.backgroundImage = `url(${config.backgroundImage})`;
    
    document.documentElement.style.setProperty('--primary-color', config.colorTheme.primary);
    document.documentElement.style.setProperty('--secondary-color', config.colorTheme.secondary);
    document.documentElement.style.setProperty('--text-color', config.colorTheme.text);
    document.documentElement.style.setProperty('--background-color', config.colorTheme.background);
    
    document.body.style.color = config.colorTheme.text;
    
    if (config.particles && config.particles.enabled) {
        initParticles(config);
    }
    
    const titleContainer = document.getElementById('title-container');
    if (config.useLogo) {
        const logoImg = document.createElement('img');
        logoImg.src = config.logoImage;
        logoImg.alt = config.title;
        logoImg.classList.add('title-logo');
        
        if (config.logoSize) {
            logoImg.style.maxHeight = `${config.logoSize}px`;
        }
        
        titleContainer.appendChild(logoImg);
    } else {
        const titleText = document.createElement('h1');
        titleText.classList.add('title-text');
        titleText.innerHTML = config.title;
        
        if (config.titleTextGradient) {
            titleText.style.background = config.titleTextGradient;
            titleText.style.webkitBackgroundClip = 'text';
            titleText.style.webkitTextFillColor = 'transparent';
            titleText.style.backgroundClip = 'text';
        }
        
        titleContainer.appendChild(titleText);
    }
    
    const subtitleContainer = document.getElementById('subtitle-container');
    subtitleContainer.textContent = config.subtitle;
    

    const progressBar = document.querySelector('.progress');
    progressBar.style.backgroundColor = config.colorTheme.primary;
    

    const loadingText = document.getElementById('loading-text');
    loadingText.textContent = config.loadingText || 'Loading...';
    

    const footerText = document.getElementById('footer-text');
    footerText.innerHTML = config.footerText;
    

    if (config.music && config.music.enabled && config.music.songs && config.music.songs.length > 0) {
        initMusicPlayer(config);
    }
    

    if (config.socialIcons && config.socialIcons.length > 0) {
        const socialIconsContainer = document.querySelector('.social-icons');
        
        config.socialIcons.forEach(icon => {
            const iconElement = document.createElement('a');
            iconElement.href = icon.link;
            iconElement.target = '_blank';
            iconElement.rel = 'noopener noreferrer';
            iconElement.classList.add('social-icon');
            iconElement.style.backgroundColor = icon.background || config.colorTheme.primary;
            
            const iconInner = document.createElement('i');
            iconInner.className = icon.iconClass;
            
            iconElement.appendChild(iconInner);
            socialIconsContainer.appendChild(iconElement);
        });
    }
    

    simulateLoading();
}

function simulateLoading() {
    const progressBar = document.querySelector('.progress');
    const loadingPercentage = document.getElementById('loading-percentage');
    let progress = 0;
    
    const interval = setInterval(() => {
        const increment = Math.floor(Math.random() * 5) + 1;
        progress += increment;
        
        if (progress >= 100) {
            progress = 100;
            clearInterval(interval);
            
            setTimeout(() => {
                console.log('Loading complete');
            }, 1000);
        }
        
        progressBar.style.width = `${progress}%`;
        loadingPercentage.textContent = `${progress}%`;
    }, 200);
}

function initParticles(config) {
    const canvas = document.getElementById('particles-canvas');
    
    const colors = [
        config.colorTheme.primary,
        config.colorTheme.secondary,
        adjustColor(config.colorTheme.primary, 20), 
        adjustColor(config.colorTheme.secondary, -20) 
    ];
    
    new ParticleEffect(canvas, {
        count: config.particles.count || 80,
        colors: colors,
        connectParticles: config.particles.connectParticles !== undefined ? config.particles.connectParticles : true,
        connectDistance: config.particles.connectDistance || 120,
        lineColor: `rgba(${hexToRgb(config.colorTheme.primary)}, 0.15)`
    });
}

function adjustColor(hex, percent) {
    let r = parseInt(hex.substring(1, 3), 16);
    let g = parseInt(hex.substring(3, 5), 16);
    let b = parseInt(hex.substring(5, 7), 16);

    r = Math.max(0, Math.min(255, r + percent));
    g = Math.max(0, Math.min(255, g + percent));
    b = Math.max(0, Math.min(255, b + percent));

    return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
}

function hexToRgb(hex) {
    hex = hex.replace('#', '');
    
    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);
    
    return `${r}, ${g}, ${b}`;
}

document.addEventListener('DOMContentLoaded', loadConfig);