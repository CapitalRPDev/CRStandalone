class Particle {
    constructor(canvas, options) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.x = Math.random() * this.canvas.width;
        this.y = Math.random() * this.canvas.height;
        this.size = Math.random() * 5 + 1;
        this.speedX = Math.random() * 3 - 1.5;
        this.speedY = Math.random() * 3 - 1.5;
        
        this.color = options.colors[Math.floor(Math.random() * options.colors.length)];
        this.alpha = Math.random() * 0.6 + 0.2; 
    }

    update() {
        this.x += this.speedX;
        this.y += this.speedY;

        if (this.x > this.canvas.width || this.x < 0) {
            this.speedX *= -1;
        }
        if (this.y > this.canvas.height || this.y < 0) {
            this.speedY *= -1;
        }
    }

    draw() {
        this.ctx.beginPath();
        this.ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        this.ctx.fillStyle = this.color;
        this.ctx.globalAlpha = this.alpha;
        this.ctx.fill();
        this.ctx.globalAlpha = 1;
    }
}

class ParticleEffect {
    constructor(canvas, options = {}) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.particles = [];
        this.options = Object.assign({
            count: 50,
            colors: ['#ffffff', '#f0f0f0'], 
            connectParticles: true,
            connectDistance: 100,
            lineColor: 'rgba(255, 255, 255, 0.15)',
            responsive: true
        }, options);

        this.init();
        
        if (this.options.responsive) {
            window.addEventListener('resize', () => this.resize());
        }
    }

    init() {
        this.resize();
        this.createParticles();
        this.animate();
    }

    resize() {
        this.canvas.width = this.canvas.offsetWidth;
        this.canvas.height = this.canvas.offsetHeight;
        
        if (this.particles.length > 0) {
            for (let i = 0; i < this.particles.length; i++) {
                if (this.particles[i].x > this.canvas.width) {
                    this.particles[i].x = Math.random() * this.canvas.width;
                }
                if (this.particles[i].y > this.canvas.height) {
                    this.particles[i].y = Math.random() * this.canvas.height;
                }
            }
        }
    }

    createParticles() {
        for (let i = 0; i < this.options.count; i++) {
            this.particles.push(new Particle(this.canvas, this.options));
        }
    }

    connectParticles() {
        const connectDistance = this.options.connectDistance;
        
        for (let a = 0; a < this.particles.length; a++) {
            for (let b = a; b < this.particles.length; b++) {
                const dx = this.particles[a].x - this.particles[b].x;
                const dy = this.particles[a].y - this.particles[b].y;
                const distance = Math.sqrt(dx * dx + dy * dy);
                
                if (distance < connectDistance) {
                    const opacity = 1 - (distance / connectDistance);
                    this.ctx.strokeStyle = this.options.lineColor;
                    this.ctx.lineWidth = 1;
                    this.ctx.globalAlpha = opacity;
                    this.ctx.beginPath();
                    this.ctx.moveTo(this.particles[a].x, this.particles[a].y);
                    this.ctx.lineTo(this.particles[b].x, this.particles[b].y);
                    this.ctx.stroke();
                    this.ctx.globalAlpha = 1;
                }
            }
        }
    }

    animate() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        
        for (let i = 0; i < this.particles.length; i++) {
            this.particles[i].update();
            this.particles[i].draw();
        }
        
        if (this.options.connectParticles) {
            this.connectParticles();
        }
        
        requestAnimationFrame(() => this.animate());
    }
}