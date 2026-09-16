const screen = document.getElementById('screen');
const title = document.getElementById('title');
const lines = ['line1', 'line2', 'line3', 'line4'].map((id) => document.getElementById(id));

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'show') {
        title.textContent = data.title || 'PATCH REQUIRED';
        const textLines = data.lines || [];
        lines.forEach((el, i) => {
            el.textContent = textLines[i] || '';
        });
        screen.classList.remove('hidden');
    }

    if (data.action === 'hide') {
        screen.classList.add('hidden');
    }
});
