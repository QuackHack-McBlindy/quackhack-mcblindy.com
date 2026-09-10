(function() {
  'use strict';

  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  let allPosts = [];
  let activeTag = 'all';
  let isShowingAll = false;

  async function fetchPosts() {
    try {
      const response = await fetch('./../posts.json');
      if (!response.ok) throw new Error('Network response was not ok');
      return await response.json();
    } catch (error) {
      console.warn('Could not load posts.json:', error);
      return [];
    }
  }

  function renderLatestPosts(posts) {
    const container = document.getElementById('latest-posts');
    if (!container) return;

    const latest = posts.slice(0, 4);

    if (latest.length === 0) {
      container.innerHTML = '<p class="muted">No posts yet.</p>';
      return;
    }

    container.innerHTML = latest.map((post, index) => `
      <div class="list-item anim" style="transition-delay:${index * 55}ms">
        <div class="num">${String(index + 1).padStart(2, '0')}</div>
        <div>
          <h4>${post.link ? `<a href="${escapeHTML(post.link)}">${escapeHTML(post.title)}</a>` : escapeHTML(post.title)}</h4>
          <p>${escapeHTML(post.description)}</p>
          ${post.tags && post.tags.length ? `
            <div class="post-tags">
              ${post.tags.map(tag => `<span class="post-tag">${escapeHTML(tag)}</span>`).join('')}
            </div>
          ` : ''}
        </div>
      </div>
    `).join('');

    observeAnimElements(container.querySelectorAll('.anim'));
  }

  function extractTags(posts) {
    const tagMap = new Map();
    posts.forEach(post => {
      if (post.tags && Array.isArray(post.tags)) {
        post.tags.forEach(tag => {
          tagMap.set(tag, (tagMap.get(tag) || 0) + 1);
        });
      }
    });
    return Array.from(tagMap.entries()).sort((a, b) => b[1] - a[1]);
  }

  function renderTagFilters(posts) {
    const container = document.getElementById('tag-filters');
    if (!container) return;

    const tags = extractTags(posts);

    let html = `<button class="tag-chip ${activeTag === 'all' ? 'active' : ''}" data-tag="all">
      All <span class="tag-count">${posts.length}</span>
    </button>`;

    tags.forEach(([tag, count]) => {
      html += `<button class="tag-chip ${activeTag === tag ? 'active' : ''}" data-tag="${escapeHTML(tag)}">
        ${escapeHTML(tag)} <span class="tag-count">${count}</span>
      </button>`;
    });

    container.innerHTML = html;

    container.querySelectorAll('.tag-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        activeTag = chip.dataset.tag;
        renderTagFilters(posts);
        renderAllPosts(posts);
      });
    });
  }

  function renderAllPosts(posts) {
    const grid = document.getElementById('all-posts-grid');
    if (!grid) return;

    let filtered = posts;
    if (activeTag !== 'all') {
      filtered = posts.filter(post => post.tags && post.tags.includes(activeTag));
    }

    if (filtered.length === 0) {
      grid.innerHTML = '<div class="no-results">No posts match this tag.</div>';
      return;
    }

    grid.innerHTML = filtered.map((post, index) => `
      <div class="post-card anim" style="transition-delay:${index * 40}ms">
        <h4>${post.link ? `<a href="${escapeHTML(post.link)}">${escapeHTML(post.title)}</a>` : escapeHTML(post.title)}</h4>
        <p>${escapeHTML(post.description)}</p>
        ${post.tags && post.tags.length ? `
          <div class="post-tags">
            ${post.tags.map(tag => `<span class="post-tag">${escapeHTML(tag)}</span>`).join('')}
          </div>
        ` : ''}
      </div>
    `).join('');

    observeAnimElements(grid.querySelectorAll('.anim'));
  }

  function setupToggleButton() {
    const btn = document.getElementById('toggle-all-posts');
    const section = document.getElementById('all-posts-section');
    if (!btn || !section) return;

    btn.addEventListener('click', () => {
      isShowingAll = !isShowingAll;
      btn.setAttribute('aria-expanded', isShowingAll);
      section.hidden = !isShowingAll;

      if (isShowingAll) {
        section.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  }

  function escapeHTML(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  const animObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('in-view');
      } else {
        entry.target.classList.remove('in-view');
      }
    });
  }, {
    threshold: 0.15,
    rootMargin: '0px 0px -50px 0px'
  });

  function observeAnimElements(elements) {
    elements.forEach(el => animObserver.observe(el));
  }

  function setYear() {
    const yearEl = document.getElementById('year');
    if (yearEl) {
      yearEl.textContent = new Date().getFullYear();
    }
  }

  function setupCopyButtons() {
    document.querySelectorAll('.copy-btn').forEach(button => {
      button.addEventListener('click', async () => {
        const code = button
          .closest('.code-block')
          .querySelector('code')
          .textContent;

        await navigator.clipboard.writeText(code);

        const original = button.textContent;
        button.textContent = 'Copied!';

        setTimeout(() => {
          button.textContent = original;
        }, 1500);
      });
    });
  }

  async function init() {
    setYear();

    observeAnimElements(document.querySelectorAll('.anim'));

    allPosts = await fetchPosts();
    renderLatestPosts(allPosts);
    renderTagFilters(allPosts);
    renderAllPosts(allPosts);
    setupToggleButton();
    setupCopyButtons();
  }

  onReady(init);
})();
