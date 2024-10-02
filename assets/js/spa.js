document.addEventListener('DOMContentLoaded', () => {
    const content = document.getElementById('content');
    const links = document.querySelectorAll('.spa-link');

    links.forEach(link => {
        link.addEventListener('click', handleLinkClick);
    });

    function handleLinkClick(e) {
        e.preventDefault();
        const href = this.getAttribute('href');
        loadPage(href);
    }

    async function loadPage(url) {
        content.classList.add('fade-out');

        try {
            const response = await fetch(url);
            if (!response.ok) throw new Error('Page not found');
            const html = await response.text();
            const parser = new DOMParser();
            const doc = parser.parseFromString(html, 'text/html');
            const newContent = doc.getElementById('content');
            const newTitle = doc.querySelector('title').textContent;

            window.history.pushState({}, '', url);

            content.innerHTML = newContent.innerHTML;
            document.title = newTitle;

            void content.offsetWidth;

            content.classList.remove('fade-out');
        } catch (error) {
            console.error('Error loading page:', error);
            content.classList.remove('fade-out');
        }
    }

    window.addEventListener('popstate', (event) => {
        loadPage(window.location.pathname);
    });
});