(function () {
  'use strict';

  var searchIndex = null;
  var inputEl = document.getElementById('search-input');
  var resultsEl = document.getElementById('search-results');

  if (!inputEl || !resultsEl) return;

  function loadSearchIndex(callback) {
    if (searchIndex) { callback(); return; }
    fetch('../docs/search-index.json')
      .catch(function () { return fetch('search-index.json'); })
      .then(function (response) { return response.json(); })
      .then(function (data) { searchIndex = data; callback(); })
      .catch(function () { searchIndex = []; callback(); });
  }

  function normalizeText(str) {
    return str.toLowerCase().replace(/[^a-z0-9]/g, ' ').trim();
  }

  function extractTerms(query) {
    return normalizeText(query).split(/\s+/).filter(function (w) { return w.length > 1; });
  }

  function rankEntry(entry, terms) {
    var titleText = normalizeText(entry.title);
    var headingText = (entry.headings || []).map(normalizeText).join(' ');
    var bodyText = normalizeText(entry.body_excerpt || '');
    var points = 0;
    terms.forEach(function (term) {
      if (titleText.indexOf(term) !== -1) points += 4;
      if (headingText.indexOf(term) !== -1) points += 2;
      if (bodyText.indexOf(term) !== -1) points += 1;
    });
    return points;
  }

  function runQuery(query) {
    var terms = extractTerms(query);
    if (!terms.length) return [];
    return searchIndex
      .map(function (entry) { return { entry: entry, points: rankEntry(entry, terms) }; })
      .filter(function (r) { return r.points > 0; })
      .sort(function (a, b) { return b.points - a.points; })
      .slice(0, 8)
      .map(function (r) { return r.entry; });
  }

  function buildResultHTML(entry) {
    var excerpt = (entry.body_excerpt || '').slice(0, 120);
    var titleSpan = '<span class="result-title">' + entry.title + '</span>';
    var excerptSpan = excerpt ? '<span class="result-excerpt">' + excerpt + '...</span>' : '';
    return '<li><a href="' + entry.url + '">' + titleSpan + excerptSpan + '</a></li>';
  }

  function renderResults(items) {
    if (!items.length) {
      resultsEl.innerHTML = '<li class="no-results">No results</li>';
      resultsEl.hidden = false;
      return;
    }
    resultsEl.innerHTML = items.map(buildResultHTML).join('');
    resultsEl.hidden = false;
  }

  var debounceTimer;
  inputEl.addEventListener('input', function () {
    clearTimeout(debounceTimer);
    var query = inputEl.value.trim();
    if (!query) { resultsEl.hidden = true; return; }
    debounceTimer = setTimeout(function () {
      loadSearchIndex(function () { renderResults(runQuery(query)); });
    }, 180);
  });

  document.addEventListener('click', function (evt) {
    if (!resultsEl.contains(evt.target) && evt.target !== inputEl) {
      resultsEl.hidden = true;
    }
  });

  inputEl.addEventListener('keydown', function (evt) {
    if (evt.key === 'Escape') { resultsEl.hidden = true; inputEl.blur(); }
  });
}());
