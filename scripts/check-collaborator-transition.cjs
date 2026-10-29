const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardCollaboratorsPage.ets', 'utf8');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1)).replace(/\s*@Builder\s*$/, '');
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + ['subpage', 'dispatch'].map(method).join('\n') +
  '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const host = new Host(), actions = [];
Object.assign(host, { snapshot: { token: 1, page: 'board', phase: 'members', users: [{ id: '1' }], invites: true, permission: 1 },
  onAction: (action, value) => actions.push([action, value]) });
host.dispatch('permissions', ''); host.snapshot.phase = 'permissions'; host.snapshot.users.pop();
assert(host.subpage()); assert.equal(host.retainedMembers.users.length, 1);
assert.equal(host.retainedMembers.phase, 'members');
host.snapshot.phase = 'members'; assert.equal(host.subpage(), false);
host.dispatch('invite', ''); host.snapshot.phase = 'invite'; assert(host.subpage());
host.snapshot.token = 2; assert.equal(host.subpage(), false);
assert.deepEqual(actions.map(item => item[0]), ['permissions', 'invite']);
assert(source.includes('this.allowInvites = this.snapshot.invites') && source.includes('this.selectedPermission = this.snapshot.permission'));
assert(source.includes('duration: 180, curve: Curve.EaseOut') && source.includes('duration: 150, curve: Curve.EaseIn'));
const boardPosition = index.indexOf('PinmonyBoardPage({ profileBoard:');
const collaboratorPosition = index.indexOf('PinmonyBoardCollaboratorsPage({ snapshot:');
assert(boardPosition >= 0 && collaboratorPosition > boardPosition, 'collaborator page overlays the board');
assert(index.slice(boardPosition, collaboratorPosition).includes(".accessibilityLevel(this.boardStore.collaborators ? 'no-hide-descendants' : 'auto')"));
assert(index.slice(collaboratorPosition, collaboratorPosition + 450).includes('.transition(NATIVE_PAGE_TRANSITION)'));
assert(index.includes("this.boardStore.collaborators.phase !== 'members') { this.boardCollaboratorsAction('members', ''); return; }"));
console.log('Collaborator transitions: retained board and members, invite/permissions, back and identity passed');
