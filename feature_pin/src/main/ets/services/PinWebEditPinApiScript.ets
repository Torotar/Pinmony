export const PIN_EDIT_API_ENABLED: boolean = true;
export const PIN_EDIT_API_SCRIPT: string = `
(function () {
  var api = window.PinWebPostApi;
  if (!api || window.PinWebEditApiEnabled !== true) return;
  var state = null;
  function id(pin) { var m = String(pin).match(/\\/pin\\/(\\d+)/); return m ? m[1] : ''; }
  function valid(s) { return state === s && api.currentPin(s.pin); }
  function emptyPicker(pin) { return { pin: pin, loading: false, busy: false, error: '', feedback: '',
    items: [], shortlist: [], savedId: '', savedBoard: '', suggestions: [] }; }
  var reset = api.reset;
  api.reset = function () { state = null; reset(); };
  api.editStart = async function (pin) {
    if (!api.currentPin(pin) || state && state.busy && api.currentPin(state.pin)) return false;
    api.boardsClose();
    var s = state = { pin: pin, loading: true, busy: false, error: '', phase: 'edit', imageUrl: '',
      title: '', description: '', board: { id: '', name: '', imageUrl: '', secret: false, enabled: true }, ai: false,
      uncertain: false, done: '', picker: emptyPicker(pin), raw: null, disclosures: [], initialBoard: '' };
    try {
      var response = await api.resourceRequest(pin, 'PinResource', 'get', { id: id(pin), field_set_key: 'auth_web_main_pin' }, function () { return valid(s); });
      var raw = response.data, user = api.sessionUserId();
      if (!raw || String(raw.id) !== id(pin) || !user || !raw.pinner || String(raw.pinner.id) !== user)
        throw new Error('只能编辑当前账号收藏的 Pin 图');
      s.raw = raw;
      s.title = typeof raw.title === 'string' ? raw.title : '';
      s.description = typeof raw.description === 'string' ? raw.description : '';
      var graph = await api.resourceRequest(pin, '', '', {}, function () { return valid(s); }, {
        queryHash: 'b275f25a3893b0cf502a06e2f634402774be2a3d3b23199b141d4223174d39df', variables: { pinId: id(pin) } });
      var p = graph.v3GetPinQueryv2 && graph.v3GetPinQueryv2.data;
      if (!p || String(p.entityId) !== id(pin) || !p.pinner || String(p.pinner.entityId) !== user ||
          !p.board || !/^\\d+$/.test(String(p.board.entityId)) || !Array.isArray(p.aiDisclosures))
        throw new Error('编辑信息未能确认，请重新读取');
      s.board = { id: String(p.board.entityId), name: p.board.name || '', imageUrl: p.board.imageCoverUrl || '',
        secret: raw.board && raw.board.privacy === 'secret', enabled: true };
      s.initialBoard = s.board.id;
      s.disclosures = p.aiDisclosures.slice(); s.ai = s.disclosures.indexOf(1) >= 0;
      s.sectionId = p.section && String(p.section.entityId || '') || '';
      s.tracking = p.trackingParams || raw.tracking_params || '';
      var images = raw.images || {}, cover = images['736x'] || images['474x'] || images.orig;
      s.imageUrl = cover && cover.url || p.images && p.images.url || '';
    } catch (e) { if (valid(s)) s.error = e.message; }
    finally { if (valid(s)) s.loading = false; }
    return true;
  };
  api.editRead = function(pin) {
    if (!state || state.pin !== pin || !valid(state)) return null;
    var picker = api.boardsRead(pin);
    if (picker) state.picker = Object.assign({}, picker, { savedId: '', savedBoard: '', feedback: '',
      items: picker.items.filter(function(b) { return /^\\d+$/.test(b.id); }),
      shortlist: picker.shortlist.filter(function(b) { return /^\\d+$/.test(b.id); }) });
    return state;
  };
  api.editClose = function() { var picker = state && api.boardsRead(state.pin);
    if (state && state.busy || picker && picker.busy) return false;
    state = null; api.boardsClose(); return true; };
  api.editPhase = function(pin, phase) {
    var s = state, picker = s && api.boardsRead(pin);
    if (!s || s.pin !== pin || !valid(s) || s.busy || s.loading || s.uncertain || picker && picker.busy) return false;
    if (phase === 'boards') { api.boardsStart(pin); s.picker = emptyPicker(pin); s.picker.loading = true; }
    if (['edit', 'boards', 'confirm'].indexOf(phase) < 0) return false;
    s.phase = phase; return true;
  };
  api.editSelect = function(pin, boardId) {
    var s = state, picker = api.boardsRead(pin);
    if (!s || s.pin !== pin || !valid(s) || s.busy || s.uncertain || !picker || picker.loading || picker.busy) return false;
    var board = picker.items.concat(picker.shortlist).find(function(b) { return b.id === boardId && b.enabled && /^\\d+$/.test(b.id); });
    if (!board) return false; s.board = board; s.phase = 'edit'; return true;
  };
  api.editAi = function(pin, enabled) {
    var s = state; if (!s || s.pin !== pin || !valid(s) || s.busy || s.loading || s.uncertain) return false;
    s.ai = enabled === true; return true;
  };
  api.editText = function(pin, field, value) {
    var s = state;
    if (!s || s.pin !== pin || !valid(s) || s.phase !== 'edit' || s.busy || s.loading || s.error || s.uncertain || s.done ||
        ['title', 'description'].indexOf(field) < 0 || typeof value !== 'string' || value.length > 10000) return false;
    s[field] = value; return true;
  };
  api.editCommit = async function(pin, remove, title, description) {
    var s = state, picker = api.boardsRead(pin);
    if (!s || s.pin !== pin || !valid(s) || s.busy || s.loading || s.error || s.uncertain || s.done || !s.raw ||
        picker && picker.busy || remove && s.phase !== 'confirm') return false;
    if (!remove && (title !== undefined || description !== undefined)) {
      if (typeof title !== 'string' || typeof description !== 'string' || title.length > 10000 || description.length > 10000) return false;
      s.title = title; s.description = description;
    }
    s.busy = true; s.error = '';
    try {
      var options, operation = remove ? 'delete' : 'update';
      if (remove) { options = { id: id(pin) }; if (s.tracking) options.client_tracking_params = s.tracking + '~0'; }
      else {
        var disclosures = s.disclosures.filter(function(value) { return value !== 1; });
        if (s.ai) disclosures.push(1);
        options = { id: id(pin), board_id: s.board.id,
          board_section_id: s.board.id === s.initialBoard ? s.sectionId : '',
          title: s.title, description: s.description, ai_disclosures: disclosures };
      }
      var result = await api.resourceRequest(pin, 'PinResource', operation, options, function () { return valid(s); });
      if (result.code !== 0 || result.endpoint_name !== (remove ? 'v3_delete_pin_handler' : 'v3_edit_pin')) throw new Error('操作结果未能确认');
      if (!remove && (!result.data || String(result.data.id) !== id(pin) || !result.data.board ||
          String(result.data.board.id) !== s.board.id || !Array.isArray(result.data.ai_disclosures) ||
          (result.data.ai_disclosures.indexOf(1) >= 0) !== s.ai)) throw new Error('保存结果未能确认');
      if (!remove && ((s.title !== (typeof s.raw.title === 'string' ? s.raw.title : '') && result.data.title !== s.title) ||
          (s.description !== (typeof s.raw.description === 'string' ? s.raw.description : '') && result.data.description !== s.description)))
        throw new Error('标题或描述的保存结果未能确认');
      s.done = remove ? 'deleted' : 'saved';
      if (window.PinWebDetailApi) window.PinWebDetailApi.reload();
      if (window.PinWebProfileApi) window.PinWebProfileApi.reset();
    } catch(e) { if (valid(s)) { s.uncertain = true; s.error = '操作未确认，请重新读取后检查结果。' + e.message; } }
    finally { if (valid(s)) s.busy = false; }
    return true;
  };
})();`;
