// Enhanced LibreDrop Platform Detection with Real Release API
(function() {
    'use strict';
    
    // GitHub API configuration
    const GITHUB_API = 'https://api.github.com/repos/pablojavier/libredrop';
    let latestRelease = null;
    
    function detectPlatform() {
        const userAgent = navigator.userAgent.toLowerCase();
        const platform = navigator.platform.toLowerCase();
        
        if (userAgent.includes('android')) return 'android';
        if (userAgent.includes('iphone') || userAgent.includes('ipad')) return 'ios';
        if (platform.includes('win')) return 'windows';
        if (platform.includes('mac')) return 'macos';
        if (platform.includes('linux')) return 'linux';
        
        return 'unknown';
    }
    
    function getDownloadUrl(platform, release) {
        if (!release || !release.assets) return '#';
        
        const platformPatterns = {
            'android': /android-arm64\.apk$/,
            'windows': /windows-setup\.exe$/,
            'macos': /macos\.dmg$/,
            'linux': /linux\.AppImage$/
        };
        
        const pattern = platformPatterns[platform];
        if (!pattern) return release.html_url;
        
        const asset = release.assets.find(asset => pattern.test(asset.name));
        return asset ? asset.browser_download_url : release.html_url;
    }
    
    function formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }
    
    function updateDownloadButton() {
        const platform = detectPlatform();
        const downloadBtn = document.getElementById('download-auto');
        
        if (!downloadBtn) return;
        
        // Update button text based on platform and language
        const lang = document.documentElement.lang || 'en';
        const platformLabels = {
            'en': {
                'android': 'Download for Android',
                'windows': 'Download for Windows',
                'macos': 'Download for macOS',
                'linux': 'Download for Linux',
                'ios': 'Coming Soon for iOS'
            },
            'es': {
                'android': 'Descargar para Android',
                'windows': 'Descargar para Windows',
                'macos': 'Descargar para macOS',
                'linux': 'Descargar para Linux',
                'ios': 'Próximamente para iOS'
            },
            'pt': {
                'android': 'Baixar para Android',
                'windows': 'Baixar para Windows',
                'macos': 'Baixar para macOS',
                'linux': 'Baixar para Linux',
                'ios': 'Em breve para iOS'
            }
        };
        
        const labels = platformLabels[lang] || platformLabels['en'];
        const btnText = downloadBtn.querySelector('.btn-text');
        if (btnText && labels[platform]) {
            btnText.textContent = labels[platform];
        }
        
        // Update download URL with real release
        if (latestRelease) {
            const downloadUrl = getDownloadUrl(platform, latestRelease);
            downloadBtn.href = downloadUrl;
            
            // Add file size if available
            const platformPatterns = {
                'android': /android-arm64\.apk$/,
                'windows': /windows-setup\.exe$/,
                'macos': /macos\.dmg$/,
                'linux': /linux\.AppImage$/
            };
            
            const pattern = platformPatterns[platform];
            if (pattern) {
                const asset = latestRelease.assets.find(asset => pattern.test(asset.name));
                if (asset && asset.size) {
                    const sizeElement = downloadBtn.querySelector('.btn-size');
                    if (sizeElement) {
                        sizeElement.textContent = formatFileSize(asset.size);
                    }
                }
            }
        }
        
        // Handle iOS special case
        if (platform === 'ios') {
            downloadBtn.classList.add('btn-disabled');
            downloadBtn.href = '#';
            downloadBtn.onclick = function(e) {
                e.preventDefault();
                const messages = {
                    'en': 'iOS support is coming soon! Sign up for updates at hello@libredrop.org',
                    'es': '¡El soporte para iOS llegará pronto! Regístrate para actualizaciones en hello@libredrop.org',
                    'pt': 'Suporte para iOS em breve! Cadastre-se para atualizações em hello@libredrop.org'
                };
                alert(messages[lang] || messages['en']);
            };
        }
        
        // Add platform class to body
        document.body.classList.add('platform-' + platform);
    }
    
    function updateReleaseInfo(release) {
        // Update version numbers throughout the site
        const versionElements = document.querySelectorAll('.btn-version, .version-number, .current-version');
        versionElements.forEach(el => {
            el.textContent = release.tag_name || 'v1.0.0';
        });
        
        // Update release date
        const dateElements = document.querySelectorAll('.release-date');
        if (release.published_at) {
            const date = new Date(release.published_at).toLocaleDateString();
            dateElements.forEach(el => {
                el.textContent = date;
            });
        }
        
        // Update download count (if available)
        const downloadElements = document.querySelectorAll('.download-count');
        if (release.assets && downloadElements.length > 0) {
            const totalDownloads = release.assets.reduce((sum, asset) => sum + (asset.download_count || 0), 0);
            downloadElements.forEach(el => {
                el.textContent = totalDownloads.toLocaleString();
            });
        }
        
        // Update release notes link
        const releaseNotesLinks = document.querySelectorAll('.release-notes-link');
        releaseNotesLinks.forEach(link => {
            link.href = release.html_url;
        });
    }
    
    function fetchLatestRelease() {
        // Show loading state
        const downloadBtn = document.getElementById('download-auto');
        if (downloadBtn) {
            downloadBtn.classList.add('loading');
        }
        
        fetch(`${GITHUB_API}/releases/latest`)
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }
                return response.json();
            })
            .then(data => {
                latestRelease = data;
                
                // Update all release information
                updateReleaseInfo(data);
                updateDownloadButton();
                updateDownloadPageLinks(data);
                
                // Remove loading state
                if (downloadBtn) {
                    downloadBtn.classList.remove('loading');
                }
                
                console.log('✅ Latest release info loaded:', data.tag_name);
                
                // Dispatch custom event for other scripts
                window.dispatchEvent(new CustomEvent('libredrop:release-loaded', {
                    detail: data
                }));
            })
            .catch(error => {
                console.log('⚠️ Could not fetch latest release info:', error);
                
                // Remove loading state and fallback to default behavior
                if (downloadBtn) {
                    downloadBtn.classList.remove('loading');
                }
                updateDownloadButton();
                
                // Dispatch error event
                window.dispatchEvent(new CustomEvent('libredrop:release-error', {
                    detail: error
                }));
            });
    }
    
    function updateDownloadPageLinks(release) {
        if (!release.assets) return;
        
        const linkMap = {
            'android-arm64.apk': '.download-android .btn-primary',
            'android-arm.apk': '.download-android .btn-secondary',
            'windows-setup.exe': '.download-windows .btn-primary',
            'macos.dmg': '.download-macos .btn-primary',
            'linux.AppImage': '.download-linux .btn-primary'
        };
        
        Object.entries(linkMap).forEach(([pattern, selector]) => {
            const asset = release.assets.find(asset => asset.name.includes(pattern));
            const button = document.querySelector(selector);
            
            if (asset && button) {
                button.href = asset.browser_download_url;
                
                // Add file size to button if element exists
                const sizeElement = button.querySelector('.file-size');
                if (sizeElement && asset.size) {
                    sizeElement.textContent = `(${formatFileSize(asset.size)})`;
                }
            }
        });
        
        // Update all download links in tables or lists
        const downloadLinks = document.querySelectorAll('[data-platform]');
        downloadLinks.forEach(link => {
            const platform = link.dataset.platform;
            const asset = release.assets.find(asset => asset.name.includes(platform));
            if (asset) {
                link.href = asset.browser_download_url;
            }
        });
    }
    
    // Add CSS for loading state
    function addLoadingStyles() {
        const style = document.createElement('style');
        style.textContent = `
            .btn-primary.loading {
                opacity: 0.7;
                cursor: wait;
            }
            .btn-primary.loading::after {
                content: "...";
                animation: loading-dots 1.5s infinite;
            }
            @keyframes loading-dots {
                0%, 20% { content: ""; }
                40% { content: "."; }
                60% { content: ".."; }
                80%, 100% { content: "..."; }
            }
        `;
        document.head.appendChild(style);
    }
    
    // Initialize when DOM is ready
    function initialize() {
        addLoadingStyles();
        updateDownloadButton();
        fetchLatestRelease();
        
        // Add platform detection to window for other scripts
        window.LibreDrop = window.LibreDrop || {};
        window.LibreDrop.detectPlatform = detectPlatform;
        window.LibreDrop.getLatestRelease = () => latestRelease;
        window.LibreDrop.refreshReleaseInfo = fetchLatestRelease;
    }
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }
    
})();
