export const PIN_DETAIL_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var documentActive = true, bridgeWarning = false;
  if (window.addEventListener) {
    window.addEventListener('pagehide', function () { documentActive = false; });
    window.addEventListener('pageshow', function () { documentActive = true; bridgeWarning = false; lastState = ''; schedule(); });
  }
  var activePin = '';
  var session = 0;
  var nextId = 1;
  var ids = new WeakMap();
  var controls = {};
  var actionKinds = {};
  var relatedControls = {};
  var lastState = '';
  var scheduled = 0;
  var pausedPin = '';
  var lastMoreAt = 0;
  var webFlowActive = false;
  var webFlowSawPanel = false;
  var lastHero = null;
  var staleHero = null;
  var staleImageUrl = '';

  function pinUrl() {
    var match = location.pathname.match(/^\\/pin\\/(\\d+)(?:\\/|$)/i);
    return match ? location.origin + '/pin/' + match[1] + '/' : '';
  }
  function pinId(value) {
    var match = value && value.match(/\\/pin\\/(\\d+)(?:\\/|\\?|$)/i);
    return match ? match[1] : '';
  }
  function rendered(node) {
    if (!node || !node.isConnected || !node.getBoundingClientRect) return false;
    var rect = node.getBoundingClientRect();
    var style = getComputedStyle(node);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' &&
      style.visibility !== 'hidden' && style.opacity !== '0';
  }
  function text(node) {
    return node ? (node.innerText || node.textContent || '').trim().replace(/\\s+/g, ' ').slice(0, 1600) : '';
  }
  function imageUrl(node) {
    var value = node && (node.currentSrc || node.src || node.getAttribute('src')) || '';
    return /^https:\\/\\//i.test(value) ? value.slice(0, 2000) : '';
  }
  window.PinmonyDetailDemand = function (page) {
    if (!documentActive || page !== location.href) return false;
    clearTimeout(scheduled); scheduled = 0; sync(); return true;
  };
  function notify(value) {
    if (!documentActive) return;
    var serialized = JSON.stringify(value);
    if (serialized === lastState) return;
    try {
      var bridge = window.PinmonyShareBridge;
      if (!bridge || !bridge.detailState) return;
      bridge.detailState(serialized); lastState = serialized;
    } catch (_) { if (!bridgeWarning) { bridgeWarning = true; console.warn('BridgeTrace: detail unavailable'); } }
  }
  function register(node, group) {
    var id = ids.get(node);
    if (!id) {
      id = group + session + '-' + nextId++;
      ids.set(node, id);
    }
    if (group === 'r') relatedControls[id] = node;
    else controls[id] = node;
    return id;
  }
  function enabled(node) {
    return !node.disabled && node.getAttribute('aria-disabled') !== 'true' &&
      node.getAttribute('disabled') === null;
  }
  function findHero() {
    var images = document.querySelectorAll('main img, [role="main"] img');
    var best = null;
    var bestScore = -Infinity;
    for (var index = 0; index < images.length; index++) {
      var image = images[index];
      if (!rendered(image) || !imageUrl(image) || !image.complete || image.naturalWidth < 180) continue;
      var rect = image.getBoundingClientRect();
      if (rect.width < Math.max(180, innerWidth * .58) || rect.height < 180) continue;
      var anchor = image.closest('a[href*="/pin/"]');
      if (anchor && anchor.href && pinId(anchor.href) !== pinId(pinUrl())) continue;
      var score = Math.min(rect.width * rect.height, 400000) - Math.max(0, rect.top) * 100;
      if (image.closest('[data-test-id*="closeup"], [data-test-id*="pin-detail"]')) score += 120000;
      if (image.closest('article')) score += 20000;
      if (score > bestScore) { best = image; bestScore = score; }
    }
    return best;
  }
  function detailRoot(hero) {
    var main = hero.closest('main, [role="main"]');
    for (var node = hero.parentElement; node && node !== main; node = node.parentElement) {
      if (node.querySelectorAll('button, [role="button"]').length >= 2 &&
          node.querySelector('h1, [data-test-id*="description"], [data-test-id*="creator"]')) return node;
    }
    return main;
  }
  function unsupportedMedia(hero, root) {
    var mediaArea = hero.parentElement && hero.parentElement.parentElement || root;
    if (mediaArea.querySelector('video, [data-test-id*="video"], [data-test-id*="carousel"], ' +
      '[aria-label*="Play video"], [aria-label*="播放视频"], [aria-label*="播放"], ' +
      '[aria-label*="Next image"], [aria-label*="下一张"], [aria-label*="Next slide"]')) return true;
    return false;
  }
  function firstText(root, selectors, hero) {
    var heroRect = hero.getBoundingClientRect();
    for (var index = 0; index < selectors.length; index++) {
      var nodes = root.querySelectorAll(selectors[index]);
      for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
        var node = nodes[nodeIndex];
        if (!rendered(node) || !text(node)) continue;
        var rect = node.getBoundingClientRect();
        if (rect.top >= heroRect.top - 200 && rect.top <= heroRect.bottom + 800) return text(node);
      }
    }
    return '';
  }
  function actionKind(node) {
    var childLabel = node.querySelector('[aria-label], [title], svg title');
    var name = (node.getAttribute('aria-label') || node.getAttribute('title') ||
      (childLabel && (childLabel.getAttribute('aria-label') || childLabel.getAttribute('title') || text(childLabel))) ||
      text(node)).trim();
    var testId = node.getAttribute('data-test-id') || '';
    var iconName = node.querySelector('svg, [data-icon]');
    var iconHint = iconName && ((iconName.getAttribute('data-icon') || '') + ' ' +
      (iconName.getAttribute('aria-label') || '') + ' ' +
      (iconName.getAttribute('class') || '')) || '';
    if (/^(?:like|liked|unlike|react|reactions?|hearts?|remove reaction)(?:\\s.*)?$/i.test(name) ||
        /^(?:回应|喜欢|点赞|已点赞|取消点赞|取消喜欢|赞过|为此 Pin 点赞|爱心)/i.test(name) ||
        /(^|[-_])(like|react|reaction|heart)([-_]|$)/i.test(testId) ||
        /(^|[-_\\s])(like|heart)([-_\\s]|$)/i.test(iconHint)) return 'like';
    if (/^(?:comments?|评论|查看评论)(?:\\s.*)?$/i.test(name) || /comment/i.test(testId)) return 'comment';
    if (/^(?:more|more options|more actions|更多|更多选项|更多操作|…|⋯)$/i.test(name) || /more[-_]?options/i.test(testId)) return 'more';
    if (/^(?:save|saved|保存|已保存|收藏|已收藏)(?:\\s.*)?$/i.test(name) || /(^|[-_])save([-_]|$)/i.test(testId)) return 'save';
    if (/^(?:send|share|发送|分享|发送此 Pin 图|分享此 Pin 图)(?:\\s.*)?$/i.test(name) || /(^|[-_])(send|share)([-_]|$)/i.test(testId)) return 'share';
    return '';
  }
  function countInText(value) {
    var match = (value || '').match(/(?:^|[^\\d])(\\d{1,3}(?:,\\d{3})+(?:\\.\\d+)?|\\d+(?:\\.\\d+)?(?:[kKmM万])?)(?=$|[^\\d])/);
    return match && match[1].length <= 10 ? match[1] : '';
  }
  function actionCount(node, scope, rightLimit) {
    if (/react|reaction|like|heart/i.test(node.getAttribute('data-test-id') || '') ||
        /^(?:回应|点赞|喜欢)$/i.test(node.getAttribute('aria-label') || '')) {
      var reactionRow = node.closest('[role="listitem"]');
      var reactionCount = reactionRow && reactionRow.querySelector('[data-test-id="reactions-count"]');
      if (reactionCount && rendered(reactionCount)) {
        var markedCount = countInText(text(reactionCount));
        if (markedCount) return markedCount;
      }
    }
    var direct = countInText(text(node));
    if (direct) return direct;
    var buttonRect = node.getBoundingClientRect();
    var best = '';
    var bestDistance = Infinity;
    var candidates = (scope || node.parentElement).querySelectorAll('span, div, p, strong, b');
    for (var index = 0; index < candidates.length; index++) {
      var candidate = candidates[index];
      if (!rendered(candidate) || candidate.contains(node) || node.contains(candidate)) continue;
      var value = text(candidate);
      if (!/^(?:\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.\\d+)?(?:[kKmM万])?$/.test(value)) continue;
      var childHasSameText = false;
      for (var child = candidate.firstElementChild; child; child = child.nextElementSibling) {
        if (text(child) === value) { childHasSameText = true; break; }
      }
      if (childHasSameText) continue;
      var rect = candidate.getBoundingClientRect();
      if (rightLimit && rect.right > rightLimit) continue;
      var horizontal = rect.left - buttonRect.right;
      var vertical = Math.abs((rect.top + rect.bottom) / 2 -
        (buttonRect.top + buttonRect.bottom) / 2);
      if (horizontal < -8 || horizontal > 180 || vertical > 34) continue;
      var distance = Math.max(0, horizontal) + vertical * 2;
      if (distance < bestDistance) { best = value; bestDistance = distance; }
    }
    return best;
  }
  function commentCount(root, hero) {
    var headings = root.querySelectorAll('#comments-heading, [data-test-id*="comments-heading"]');
    var heroRect = hero.getBoundingClientRect();
    for (var index = 0; index < headings.length; index++) {
      var heading = headings[index];
      var value = text(heading);
      var rect = heading.getBoundingClientRect();
      if (rendered(heading) && /评论|comments?/i.test(value) &&
          rect.top >= heroRect.top - 140 && rect.top <= heroRect.bottom + 800) {
        return countInText(value);
      }
    }
    return '';
  }
  function actionSelected(node, kind, label) {
    if (node.getAttribute('aria-pressed') === 'true' || node.getAttribute('aria-checked') === 'true' ||
        /^(?:on|active|selected)$/i.test(node.getAttribute('data-state') || '')) return true;
    if (kind === 'like') {
      if (/^(?:unlike|liked|remove reaction|已点赞|取消点赞|取消喜欢|已喜欢)/i.test(label)) return true;
      var painted = node.querySelectorAll('svg, svg path');
      for (var paintedIndex = 0; paintedIndex < painted.length; paintedIndex++) {
        var fill = getComputedStyle(painted[paintedIndex]).fill ||
          painted[paintedIndex].getAttribute('fill') || '';
        if (/^(?:#e60023|#ff4d67|rgb\\(230,\\s*0,\\s*35\\)|rgb\\(255,\\s*77,\\s*103\\))$/i.test(fill)) return true;
      }
    }
    return /^(?:saved|已保存|已收藏)$/i.test(label);
  }
  function actions(root, hero) {
    var result = [];
    var found = {};
    var foundNodes = {};
    var nodes = root.querySelectorAll('button, [role="button"]');
    var heroRect = hero.getBoundingClientRect();
    for (var index = 0; index < nodes.length; index++) {
      var node = nodes[index];
      if (!rendered(node) || node.closest('[role="dialog"], [role="menu"], [data-pinweb-native-share-hidden], [data-pinweb-native-more-hidden]')) continue;
      var rect = node.getBoundingClientRect();
      if (rect.top > heroRect.bottom + 600 || rect.bottom < heroRect.top - 140) continue;
      var kind = actionKind(node);
      if (!kind || found[kind]) continue;
      var childLabel = node.querySelector('[aria-label], [title], svg title');
      var label = (node.getAttribute('aria-label') || node.getAttribute('title') ||
        (childLabel && (childLabel.getAttribute('aria-label') || childLabel.getAttribute('title') || text(childLabel))) ||
        text(node)).trim();
      if (!label && kind !== 'like') continue;
      if (!label) label = '点赞';
      found[kind] = true;
      foundNodes[kind] = node;
      var id = register(node, 'a');
      actionKinds[id] = kind;
      var count = kind === 'like' ? actionCount(node, root) :
        kind === 'comment' ? (commentCount(root, hero) || actionCount(node, root)) : '';
      result.push({ id: id, kind: kind, label: label,
        countText: count,
        enabled: enabled(node), selected: actionSelected(node, kind, label) });
    }
    if (foundNodes.like && foundNodes.comment) {
      var likeCount = actionCount(foundNodes.like, root, foundNodes.comment.getBoundingClientRect().left);
      for (var resultIndex = 0; resultIndex < result.length; resultIndex++) {
        if (result[resultIndex].kind === 'like') result[resultIndex].countText = likeCount;
      }
    }
    if (!found.like && foundNodes.comment) {
      var commentRect = foundNodes.comment.getBoundingClientRect();
      var candidates = root.querySelectorAll('button, [role="button"]');
      var bestCandidate = null;
      var bestCount = '';
      var bestDistance = Infinity;
      for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
        var candidate = candidates[candidateIndex];
        if (!rendered(candidate) || !enabled(candidate) || actionKind(candidate) ||
            !candidate.querySelector('svg') ||
            candidate.closest('[role="dialog"], [role="menu"]')) continue;
        var candidateRect = candidate.getBoundingClientRect();
        if (candidateRect.right > commentRect.left + 8 ||
            commentRect.left - candidateRect.right > 220 ||
            Math.abs((candidateRect.top + candidateRect.bottom) / 2 -
              (commentRect.top + commentRect.bottom) / 2) > 34) continue;
        var count = actionCount(candidate, root, commentRect.left);
        if (!count) continue;
        var distance = commentRect.left - candidateRect.right;
        if (distance < bestDistance) {
          bestCandidate = candidate;
          bestCount = count;
          bestDistance = distance;
        }
      }
      if (bestCandidate) {
        var likeId = register(bestCandidate, 'a');
        actionKinds[likeId] = 'like';
        result.unshift({ id: likeId, kind: 'like', label: '点赞', countText: bestCount,
          enabled: true, selected: actionSelected(bestCandidate, 'like', '点赞') });
      }
    }
    return result;
  }
  function website(root, hero) {
    var links = root.querySelectorAll('a[href]');
    var heroRect = hero.getBoundingClientRect();
    for (var index = 0; index < links.length; index++) {
      var link = links[index];
      if (!rendered(link) || link.getBoundingClientRect().top > heroRect.bottom + 700) continue;
      try {
        var url = new URL(link.href);
        if (url.protocol !== 'https:' || /(^|\\.)(pinterest\\.com|pinimg\\.com|pin\\.it)$/i.test(url.hostname)) continue;
        return { node: link, label: text(link) || url.hostname };
      } catch (error) {}
    }
    return null;
  }
  function profileLink(link) {
    if (!link || !link.href) return false;
    try {
      var url = new URL(link.href);
      if (!/(^|\\.)pinterest\\.com$/i.test(url.hostname) ||
          !/^\\/[^/]+\\/?$/.test(url.pathname)) return false;
      var segment = url.pathname.split('/').filter(Boolean)[0].toLowerCase();
      return !/^(?:pin|search|ideas|business|settings|messages|videos|today|explore|login|signup|about|_saved|_created|following|followers)$/.test(segment);
    } catch (error) { return false; }
  }
  function creatorInfo(root, hero) {
    var scopes = [root];
    var main = hero.closest('main, [role="main"]');
    if (main && main !== root) scopes.push(main);
    var heroRect = hero.getBoundingClientRect();
    var best = { name: '', avatar: '' };
    var bestScore = -Infinity;
    for (var scopeIndex = 0; scopeIndex < scopes.length; scopeIndex++) {
      var links = scopes[scopeIndex].querySelectorAll('a[href]');
      for (var index = 0; index < links.length; index++) {
        var link = links[index];
        if (!profileLink(link) || !rendered(link)) continue;
        var rect = link.getBoundingClientRect();
        if (rect.top < heroRect.top + heroRect.height * .5 ||
            rect.top > heroRect.bottom + 750) continue;
        var name = text(link).replace(/\\s*(?:Follow|Following|关注|已关注)\\s*$/i, '').trim();
        var image = link.querySelector('img');
        for (var owner = link.parentElement, depth = 0; owner && depth < 3;
             owner = owner.parentElement, depth++) {
          if (!name) {
            var companion = owner.querySelectorAll('a[href]');
            for (var companionIndex = 0; companionIndex < companion.length; companionIndex++) {
              if (companion[companionIndex] !== link && profileLink(companion[companionIndex]) &&
                  companion[companionIndex].href === link.href && text(companion[companionIndex])) {
                name = text(companion[companionIndex]);
                break;
              }
            }
          }
          if (!image) {
            var nearbyImages = owner.querySelectorAll('img');
            for (var imageIndex = 0; imageIndex < nearbyImages.length; imageIndex++) {
              var imageRect = nearbyImages[imageIndex].getBoundingClientRect();
              if (rendered(nearbyImages[imageIndex]) && imageRect.width >= 20 &&
                  imageRect.width <= 96 && imageRect.height <= 96 &&
                  Math.abs((imageRect.top + imageRect.bottom) / 2 -
                    (rect.top + rect.bottom) / 2) < 100) {
                image = nearbyImages[imageIndex];
                break;
              }
            }
          }
          if (name && image) break;
        }
        if (!name && image && image.alt) {
          name = image.alt.replace(/(?:的)?(?:头像|个人头像|profile picture|avatar).*$/i, '').trim();
        }
        if (!name || /^(?:Follow|Following|关注|已关注)$/i.test(name)) continue;
        var avatar = imageUrl(image);
        if (!avatar) {
          for (var avatarOwner = link, avatarDepth = 0; avatarOwner && avatarDepth < 3;
               avatarOwner = avatarOwner.parentElement, avatarDepth++) {
            var backgroundNodes = avatarOwner.querySelectorAll('[style*="background-image"]');
            for (var backgroundIndex = 0; backgroundIndex < backgroundNodes.length; backgroundIndex++) {
              var backgroundNode = backgroundNodes[backgroundIndex];
              var backgroundRect = backgroundNode.getBoundingClientRect();
              if (!rendered(backgroundNode) || backgroundRect.width < 20 || backgroundRect.width > 96 ||
                  Math.abs((backgroundRect.top + backgroundRect.bottom) / 2 -
                    (rect.top + rect.bottom) / 2) > 100) continue;
              var background = getComputedStyle(backgroundNode).backgroundImage;
              var backgroundMatch = background.match(/url\\(["']?(https:\\/\\/[^"')]+)["']?\\)/i);
              if (backgroundMatch) { avatar = backgroundMatch[1]; break; }
            }
            if (avatar) break;
          }
        }
        var score = (avatar ? 100 : 0) +
          (/(?:creator|owner|profile|user)/i.test(link.getAttribute('data-test-id') || '') ? 60 : 0) -
          Math.abs(rect.top - heroRect.bottom) * .1;
        if (score > bestScore) {
          bestScore = score;
          best = { name: name.slice(0, 180), avatar: avatar };
        }
      }
    }
    return best;
  }
  function related(pin, hero) {
    var result = [];
    var seen = {};
    var links = document.querySelectorAll('main a[href*="/pin/"], [role="main"] a[href*="/pin/"]');
    var heroRect = hero.getBoundingClientRect();
    for (var index = 0; index < links.length && result.length < 40; index++) {
      var link = links[index];
      var match = link.href && link.href.match(/\\/pin\\/(\\d+)(?:\\/|\\?|$)/i);
      if (!match || link.href.indexOf(pin) >= 0 || seen[match[1]] || !rendered(link)) continue;
      var rect = link.getBoundingClientRect();
      if (rect.top < heroRect.bottom - 50) continue;
      var image = link.querySelector('img');
      var url = imageUrl(image);
      if (!image || !url || image.naturalWidth < 100) continue;
      seen[match[1]] = true;
      result.push({ id: register(link, 'r'), pinUrl: link.href, imageUrl: url,
        title: text(link) || image.alt || '', imageWidth: image.naturalWidth,
        imageHeight: image.naturalHeight });
    }
    return result;
  }
  function apiSnapshot(pin) {
    var api = window.PinmonyDetailApi && window.PinmonyDetailApi.read(pin, schedule, function () {
      return pinUrl() === pin && activePin === pin;
    });
    if (!api || !api.detail || !api.image) return { kind: 'apiPending', session: session,
      pinUrl: pin, error: api ? api.detailError : '帖子接口不可用',
      retryable: !!api && !api.mediaUnsupported, mediaUnsupported: !!api && api.mediaUnsupported };
    controls = {}; actionKinds = {}; relatedControls = {};
    var availableActions = [], hero = findHero();
    // The API path uses DOM only as a rendering/lifecycle anchor. All visible
    // detail actions, including source and more, are built from API state.
    if (hero && !(staleHero === hero && imageUrl(hero) === staleImageUrl)) {
      var root = detailRoot(hero);
      if (root) {
        lastHero = hero; staleHero = null; staleImageUrl = '';
        availableActions = actions(hero.closest('main, [role="main"]') || root, hero);
      }
    }
    var data = api.detail, creator = data.origin_pinner || data.pinner || {};
    if (window.PinmonyVideoApi) window.PinmonyVideoApi.nativeMode(String(data.id), api.isVideo === true && !webFlowActive);
    var preview = window.PinmonyPostApi && window.PinmonyPostApi.previewRead && window.PinmonyPostApi.previewRead(pin, true);
    if (window.PinmonyPostApi) availableActions = window.PinmonyPostApi.detailActions(pin, availableActions, schedule);
    if (api.reactionCount !== null && api.reactionCount !== undefined) availableActions.forEach(function (action) {
      if (action.kind === 'like' && !action.countText) action.countText = api.reactionCount;
    });
    function clean(value) { return typeof value === 'string' ? value.trim() : ''; }
    var sourceUrl = '', sourceLabel = clean(data.link_domain) || clean(data.domain);
    var sourceFields = ['link', 'mobile_link', 'tracked_link', 'utm_link', 'affiliate_link', 'pin_direct_to_site_url'];
    for (var sourceIndex = 0; sourceIndex < sourceFields.length && !sourceUrl; sourceIndex++) {
      var candidate = clean(data[sourceFields[sourceIndex]]);
      try {
        var sourceAddress = new URL(candidate, location.href);
        if (sourceAddress.protocol === 'https:' &&
            !/(^|\\.)(pinterest\\.com|pinimg\\.com|pin\\.it)$/i.test(sourceAddress.hostname) &&
            !sourceAddress.username && !sourceAddress.password) sourceUrl = sourceAddress.href;
      } catch (_) {}
    }
    if (sourceUrl) {
      if (!sourceLabel) {
        try { sourceLabel = new URL(sourceUrl).hostname; } catch (_) {}
      }
      availableActions.push({ id: 'api-source', kind: 'source', label: sourceLabel || '打开来源',
        countText: '', enabled: true, selected: false });
    } else sourceLabel = '';
    return { kind: 'state', dataSource: 'api', session: session, pinUrl: pin,
      aiLabel: (Array.isArray(data.ai_disclosures) && data.ai_disclosures.indexOf(1) >= 0 ||
        Array.isArray(data.gen_ai_topics) && data.gen_ai_topics.some(function (topic) {
          return topic && typeof topic.name === 'string' && !!topic.name.trim();
        })) ? '由 AI 修改' : '',
      carousel: api.carousel, isVideo: api.isVideo === true, video: api.video, videoError: api.videoError || '',
      mediaLoading: api.mediaLoading === true, mediaError: api.mediaError || '', mediaKind: api.mediaKind || '',
      originalImageUrl: data.images && data.images.orig && data.images.orig.url || api.image.url,
      imageUrl: api.image.url, imageWidth: api.image.width, imageHeight: api.image.height,
      title: clean(data.closeup_unified_title) || clean(data.title) || clean(data.grid_title),
      description: clean(data.closeup_unified_description) || clean(data.description),
      creator: clean(creator.full_name) || clean(creator.username),
      creatorUrl: /^[a-zA-Z0-9_]+$/.test(creator.username || '') ? location.origin + '/' + creator.username + '/' : '',
      creatorAvatar: /^https:\\/\\//i.test(creator.image_medium_url || '') ? creator.image_medium_url : '',
      sourceLabel: sourceLabel, sourceUrl: sourceUrl, actions: availableActions,
      related: api.related || [], relatedLoading: api.relatedBusy,
      relatedError: api.relatedError, relatedEnded: api.ended, commentPreview: preview && preview.text || '',
      commentLoading: !!preview && preview.loading, commentError: preview && preview.error || '',
      commentsAvailable: !!preview, commentEmpty: !!preview && preview.empty === true,
      imageStageReady: api.imageStageReady, imageLoaded: api.imageLoaded, interactionsSettled: api.interactionsSettled };
  }
  function snapshot(pin) {
    if (window.PinmonyDetailApiEnabled === true) return apiSnapshot(pin);
    var hero = findHero();
    if (!hero) return { kind: 'unsupported', session: session, pinUrl: pin };
    if (staleHero && hero === staleHero && imageUrl(hero) === staleImageUrl) {
      return { kind: 'unsupported', session: session, pinUrl: pin };
    }
    staleHero = null;
    staleImageUrl = '';
    var root = detailRoot(hero);
    if (!root || unsupportedMedia(hero, root)) return { kind: 'unsupported', session: session, pinUrl: pin };
    lastHero = hero;
    controls = {};
    actionKinds = {};
    relatedControls = {};
    var title = firstText(root, ['[data-test-id*="closeup-title"]', '[data-test-id*="pin-title"]', 'h1'], hero);
    var description = firstText(root, ['[data-test-id*="description"]', '[data-test-id*="pinDescription"]', 'p'], hero);
    description = description.replace(/(?:\\s*(?:查看更多|显示更多|展开全文|See more|Read more))+\\s*$/i, '').trim();
    var creator = creatorInfo(root, hero);
    var source = website(root, hero);
    var availableActions = actions(hero.closest('main, [role="main"]') || root, hero);
    if (source) {
      var sourceId = register(source.node, 'a');
      actionKinds[sourceId] = 'source';
      availableActions.push({ id: sourceId, kind: 'source',
        label: source.label, countText: '', enabled: true, selected: false });
    }
    return { kind: 'state', session: session, pinUrl: pin, imageUrl: imageUrl(hero),
      imageWidth: hero.naturalWidth, imageHeight: hero.naturalHeight, title: title,
      description: description, creator: creator.name,
      creatorAvatar: creator.avatar, sourceLabel: source ? source.label : '',
      actions: availableActions, related: related(pin, hero) };
  }
  function sync() {
    scheduled = 0;
    if (!documentActive) return;
    if (window.PinmonyNativeNetworkEnabled === true && window.PinmonyNetwork && typeof window.PinmonyNetwork.isReady === "function" && !window.PinmonyNetwork.isReady()) return;
    scheduled = 0;
    if (pausedPin) return;
    var pin = pinUrl();
    if (pin !== activePin) {
      if (window.PinmonyPostApi) window.PinmonyPostApi.reset();
      if (window.PinmonyDetailApi) window.PinmonyDetailApi.reset();
      staleHero = lastHero;
      staleImageUrl = imageUrl(lastHero);
      lastHero = null;
      activePin = pin;
      session++;
      nextId = 1;
      ids = new WeakMap();
      controls = {};
      actionKinds = {};
      relatedControls = {};
      webFlowActive = false;
      webFlowSawPanel = false;
      lastState = '';
      if (!pin) { notify({ kind: 'closed', session: session, pinUrl: '' }); return; }
      if (window.PinmonyDetailApiEnabled !== true) notify({ kind: 'unsupported', session: session, pinUrl: pin });
    }
    if (!pin) return;
    if (webFlowActive) {
      var panels = document.querySelectorAll('[role="dialog"], [aria-modal="true"]');
      var panelVisible = false;
      for (var panelIndex = 0; panelIndex < panels.length; panelIndex++) {
        if (rendered(panels[panelIndex])) { panelVisible = true; break; }
      }
      if (panelVisible) webFlowSawPanel = true;
      else if (webFlowSawPanel) {
        webFlowActive = false;
        webFlowSawPanel = false;
        notify({ kind: 'flowClosed', session: session, pinUrl: pin });
      }
    }
    notify(snapshot(pin));
    // Once the Pin snapshot is verified, start independent secondary reads in
    // parallel. The native image stage only controls presentation readiness.
    if (window.PinmonyDetailApiEnabled === true && window.PinmonyDetailApi && window.PinmonyDetailApi.raw(pin)) {
      var stage = window.PinmonyDetailApi.read(pin, schedule, function () { return pinUrl() === pin && activePin === pin; });
      var existingPreview = window.PinmonyPostApi && window.PinmonyPostApi.previewRead && window.PinmonyPostApi.previewRead(pin, true);
      var preview = window.PinmonyPostApi && window.PinmonyPostApi.previewRead && window.PinmonyPostApi.previewRead(pin);
      if (!existingPreview && preview) schedule();
      window.PinmonyDetailApi.scheduleRelated(pin);
      if (!preview || !preview.loading) {
        if (window.PinmonyNativeDetailReadsEnabled !== true && !preview && !stage.interactionsSettled && window.PinmonyDetailReadTiming) window.PinmonyDetailReadTiming(pin, 'comments.unavailable', 0);
        window.PinmonyDetailApi.settleInteractions(pin);
        window.PinmonyDetailApi.scheduleRelated(pin);
      }
    }
  }
  function schedule() {
    if (pausedPin || scheduled) return;
    scheduled = setTimeout(sync, 0);
  }
  window.PinmonyDetailImageStage = function (requestedSession, requestedPin, url, outcome) {
    if (requestedSession !== session || requestedPin !== activePin || pinUrl() !== activePin ||
        !window.PinmonyDetailApi || window.PinmonyDetailApiEnabled !== true) return false;
    return window.PinmonyDetailApi.settleImage(requestedPin, url, outcome);
  };
  window.PinmonyDetailReadTiming = function (pin, event, duration) {
    if (pin !== activePin || pinUrl() !== pin || !/^[a-zA-Z0-9_.=-]{1,80}$/.test(event) ||
        !(duration >= 0 && duration <= 60000)) return;
    notify({ kind: 'timing', session: session, pinUrl: pin, timingEvent: event, timingDuration: duration });
  };
  window.PinmonyDetailMore = function (requestedSession, requestedPin, id) {
    var target = controls[id];
    if (!target || actionKinds[id] !== 'more' || requestedSession !== session ||
        requestedPin !== activePin || pinUrl() !== activePin || !target.isConnected ||
        !enabled(target) || typeof window.PinmonyNativeMoreOpenFromHome !== 'function') return false;
    return window.PinmonyNativeMoreOpenFromHome(target, activePin);
  };
  window.PinmonyDetailAction = function (requestedSession, requestedPin, id) {
    if (requestedSession !== session || requestedPin !== activePin || pinUrl() !== activePin) return false;
    // API-owned actions have no corresponding website control. Like must be
    // dispatched directly through the current-session API contract.
    var kind = actionKinds[id] || (id === 'api-like' ? 'like' : '');
    if (window.PinmonyPostApi && kind === 'like') {
      return window.PinmonyPostApi.like(activePin, schedule, function (error) {
        notify({ kind: 'actionUnchanged', session: session, pinUrl: activePin, error: error });
      });
    }
    var target = controls[id];
    if (!target || !target.isConnected || !enabled(target)) return false;
    var before = null;
    if (kind === 'like') {
      var current = snapshot(activePin);
      before = current.actions && current.actions.filter(function (item) { return item.kind === 'like'; })[0];
    }
    webFlowActive = /^(?:save|comment|source)$/.test(kind);
    webFlowSawPanel = false;
    target.click();
    schedule();
    if (kind === 'like' && before) {
      var checkedPin = activePin;
      var checkedSession = session;
      setTimeout(function () {
        if (activePin !== checkedPin || session !== checkedSession || pinUrl() !== checkedPin) return;
        var current = snapshot(checkedPin);
        var after = current.actions && current.actions.filter(function (item) { return item.kind === 'like'; })[0];
        if (!after || (after.selected === before.selected && after.countText === before.countText)) {
          notify({ kind: 'actionUnchanged', session: checkedSession, pinUrl: checkedPin });
        }
      }, 1800);
    }
    return true;
  };
  window.PinmonyDetailRelated = function (requestedSession, requestedPin, id) {
    if (requestedSession !== session || requestedPin !== activePin || pinUrl() !== activePin) return false;
    var apiUrl = window.PinmonyDetailApi && window.PinmonyDetailApi.relatedUrl(id);
    if (apiUrl) { location.assign(apiUrl); return true; }
    var target = relatedControls[id];
    if (!target || requestedSession !== session || requestedPin !== activePin ||
        pinUrl() !== activePin || !target.isConnected) return false;
    target.click();
    schedule();
    return true;
  };
  window.PinmonyDetailPause = function (pin) {
    if (!pin || pin !== pinUrl()) return false;
    pausedPin = pin;
    clearTimeout(scheduled); scheduled = 0;
    if (window.PinmonyDetailApi) window.PinmonyDetailApi.reset();
    if (window.PinmonyPostApi) window.PinmonyPostApi.reset();
    return true;
  };
  function resumeDocument() {
    if (pausedPin) { pausedPin = ''; activePin = ''; lastState = ''; }
    schedule();
  }
  window.PinmonyDetailRefresh = function (resumeCurrent) {
    if (pausedPin && (resumeCurrent === true || pinUrl() !== pausedPin)) resumeDocument();
    lastState = ''; schedule();
  };
  window.PinmonyDetailApiRetry = function (requestedSession, requestedPin, restart) {
    if (requestedSession !== session || requestedPin !== activePin || pinUrl() !== activePin) return false;
    return !!(window.PinmonyDetailApi && (restart ? window.PinmonyDetailApi.restart(requestedPin) : window.PinmonyDetailApi.retry()));
  };
  window.PinmonyDetailPreviewRetry = function (requestedSession, requestedPin) {
    if (requestedSession !== session || requestedPin !== activePin || pinUrl() !== activePin) return false;
    var started = !!(window.PinmonyPostApi && window.PinmonyPostApi.previewRetry && window.PinmonyPostApi.previewRetry(requestedPin));
    if (started) schedule();
    return started;
  };
  window.PinmonyDetailResume = function () {
    webFlowActive = false;
    webFlowSawPanel = false;
    lastState = '';
    schedule();
  };
  window.PinmonyDetailLoadMore = function (requestedSession, requestedPin) {
    if (requestedSession !== session || requestedPin !== activePin || pinUrl() !== activePin ||
        Date.now() - lastMoreAt < 750) return false;
    lastMoreAt = Date.now();
    if (window.PinmonyDetailApiEnabled === true) return !!(window.PinmonyDetailApi && window.PinmonyDetailApi.loadMore());
    window.scrollBy(0, Math.max(300, innerHeight * .8));
    schedule();
    return true;
  };
  function start() {
    if (!document.documentElement) return;
    new MutationObserver(schedule).observe(document.documentElement, {
      childList: true, subtree: true, attributes: true,
      attributeFilter: ['src', 'class', 'style', 'aria-label', 'aria-pressed', 'aria-checked',
        'aria-disabled', 'data-state', 'fill', 'stroke', 'disabled']
    });
    schedule();
  }
  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);
  // API state does not depend on the website finishing its HTML document.
  if (window.PinmonyDetailApiEnabled === true) schedule();
  window.addEventListener('pageshow', resumeDocument);
  window.addEventListener('popstate', function () {
    if (pausedPin && pinUrl() !== pausedPin) resumeDocument();
    else schedule();
  });
  window.setInterval(sync, 700);
})();`;
