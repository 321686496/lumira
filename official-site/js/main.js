(function() {
  'use strict';

  var revealElements = document.querySelectorAll('.reveal');
  if (revealElements.length === 0) return;

  // Staggered reveal: add .visible with increasing delay for a cascading fade-in
  revealElements.forEach(function(el, index) {
    setTimeout(function() {
      el.classList.add('visible');
    }, index * 60);
  });

  var nav = document.querySelector('.site-nav');
  if (nav) {
    var navObserver = new IntersectionObserver(
      function(entries) {
        entries.forEach(function(e) {
          nav.style.borderBottomColor = e.isIntersecting
            ? 'transparent'
            : 'var(--color-border)';
        });
      },
      { threshold: [0], rootMargin: '-64px 0px 0px 0px' }
    );
    var hero = document.querySelector('.hero');
    if (hero) navObserver.observe(hero);
  }
})();