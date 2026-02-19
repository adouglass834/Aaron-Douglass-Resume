// Visitor count function
async function getVisitorCount() {
    try {
        // Placeholder API URL - replace with actual API Gateway endpoint
        const apiUrl = const apiUrl = '%%API_URL_PLACEHOLDER%%';
        
        const response = await fetch(apiUrl, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Update the visitor count display
        const visitorCountElement = document.getElementById('visitor-count');
        if (visitorCountElement) {
            visitorCountElement.textContent = data.count || '0';
        }
        
        return data.count;
    } catch (error) {
        console.error('Error fetching visitor count:', error);
        
        // Fallback to local storage for demo purposes
        let count = localStorage.getItem('visitor-count') || '1';
        const visitorCountElement = document.getElementById('visitor-count');
        if (visitorCountElement) {
            visitorCountElement.textContent = count;
        }
        
        return count;
    }
}

// Future analytics function for Kinesis Firehose integration
function collectTelemetry() {
    // Prepare telemetry data object
    const telemetryData = {
        userAgent: navigator.userAgent,
        screenResolution: {
            width: screen.width,
            height: screen.height
        },
        viewportSize: {
            width: window.innerWidth,
            height: window.innerHeight
        },
        timestamp: new Date().toISOString(),
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        language: navigator.language,
        platform: navigator.platform,
        referrer: document.referrer || 'direct',
        sessionId: sessionStorage.getItem('sessionId') || generateSessionId(),
        pageLoadTime: performance.timing.loadEventEnd - performance.timing.navigationStart
    };
    
    // TODO: Send telemetry data to Kinesis Firehose endpoint
    // Example implementation (commented out until endpoint is available):
    /*
    fetch('https://your-kinesis-firehose-endpoint.amazonaws.com/put-record', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer YOUR_API_TOKEN'
        },
        body: JSON.stringify({
            Records: [{
                Data: btoa(JSON.stringify(telemetryData))
            }]
        })
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        console.log('Telemetry data sent successfully');
    })
    .catch(error => {
        console.error('Error sending telemetry data:', error);
    });
    */
    
    console.log('Telemetry data collected:', telemetryData);
    return telemetryData;
}

// Generate a unique session ID
function generateSessionId() {
    const sessionId = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    sessionStorage.setItem('sessionId', sessionId);
    return sessionId;
}

// Initialize visitor count on page load
document.addEventListener('DOMContentLoaded', function() {
    // Get visitor count
    getVisitorCount();
    
    // Collect telemetry data (for future implementation)
    collectTelemetry();
    
    // Add smooth scrolling for internal links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
    
    // Add fade-in animation to sections
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };
    
    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);
    
    // Observe all sections for animation
    document.querySelectorAll('section').forEach(section => {
        section.style.opacity = '0';
        section.style.transform = 'translateY(20px)';
        section.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(section);
    });
});

// Handle window resize events
window.addEventListener('resize', function() {
    // Debounce resize events
    clearTimeout(window.resizeTimer);
    window.resizeTimer = setTimeout(function() {
        console.log('Window resized to:', window.innerWidth + 'x' + window.innerHeight);
        // Collect updated viewport information
        collectTelemetry();
    }, 250);
});

// Handle page visibility changes
document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible') {
        console.log('Page became visible');
        // Optionally refresh visitor count when page becomes visible
        getVisitorCount();
    }
});
