const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts; try { ts = require('typescript'); } catch (_) { ts = require(process.argv[2]); }
const text = fs.readFileSync('common_network/src/main/ets/PinmonyNativeNetwork.ets', 'utf8').replace(/^import .*;\r?$/gm, '');
const code = ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
const pin = 'https://www.pinterest.com/pin/101/';
function harness(uploadHost = 'https://pinterest-media-upload.s3.amazonaws.com/', onUpload = () => {}) {
  const uploads = [], reads = [], context = { authenticated: true, epoch: 1, page: pin, userAgent: 'test' };
  const scope = { exports: {}, PinmonySessionCredentials: class {}, PinmonyRuntimeLog: { info() {}, warn() {} }, setTimeout,
    rcp: { MultipartForm: class { constructor(fields) { this.fields = fields; } },
      Request: class { constructor(url, method, headers, body) { Object.assign(this, { url, method, headers, body }); } },
      createSession: () => ({ fetch: async request => { uploads.push(request); onUpload(request); return { statusCode: 204 }; }, close() {}, cancel() {} }) } };
  const policyScope = { exports: {}, PinmonyRuntimeLog: scope.PinmonyRuntimeLog };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_network/src/main/ets/PinmonyRequestPolicy.ets', 'utf8').replace(/^import .*;\r?$/gm, ''), { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText, policyScope);
  scope.PinmonyRequestPolicy = policyScope.exports.PinmonyRequestPolicy;
  vm.runInNewContext(code, scope);
  const network = new scope.exports.PinmonyNativeNetwork();
  network.request = async job => {
    reads.push(job);
    const registration = job.method === 'POST';
    const data = registration ? { upload_id: '303', upload_url: uploadHost, upload_parameters: {
      'x-amz-date': 'synthetic', 'x-amz-signature': 'synthetic', 'x-amz-security-token': 'synthetic',
      'x-amz-algorithm': 'synthetic', key: 'synthetic', policy: 'synthetic', 'x-amz-credential': 'synthetic', 'Content-Type': 'image/jpeg'
    } } : { '303': { upload_id: '303', status: 'succeeded', type: 'triedit-image', signature: 'a'.repeat(32) } };
    return { status: 200, error: '', body: JSON.stringify({ resource_response: { status: 'success', code: 0,
      endpoint_name: registration ? 'register_media_upload' : 'get_media_uploads', data } }) };
  };
  return { network, context, uploads, reads };
}
async function main() {
  const h = harness(); const bytes = new Uint8Array([1, 2, 3]).buffer;
  assert.equal(await h.network.uploadCommentImage(bytes, pin, () => h.context), 'a'.repeat(32));
  assert.equal(h.reads.length, 2);
  assert.equal(h.uploads.length, 1);
  assert.deepEqual(Object.keys(h.uploads[0].headers), [], 'upload host receives no site credentials');
  assert.equal(h.uploads[0].body.fields.file.contentOrPath.content, bytes);
  assert.equal(h.uploads[0].body.fields.file.contentType, 'image/jpeg');
  const wrongHost = harness('https://example.com/');
  await assert.rejects(wrongHost.network.uploadCommentImage(bytes, pin, () => wrongHost.context));
  assert.equal(wrongHost.uploads.length, 0);
  const stale = harness(); stale.context.page = 'https://www.pinterest.com/pin/999/';
  await assert.rejects(stale.network.uploadCommentImage(bytes, pin, () => stale.context));
  assert.equal(stale.reads.length, 0);
  const late = harness();
  const original = late.network.request;
  late.network.request = async job => { const result = await original(job); late.network.invalidate(); return result; };
  await assert.rejects(late.network.uploadCommentImage(bytes, pin, () => late.context));
  assert.equal(late.uploads.length, 0);
  const hidden = harness(); hidden.network.setForeground(false);
  await assert.rejects(hidden.network.uploadCommentImage(bytes, pin, () => hidden.context), /background/);
  assert.equal(hidden.reads.length, 0, 'background cannot register a new upload');
  const registrationHidden = harness(); const register = registrationHidden.network.request;
  registrationHidden.network.request = async job => { const result = await register(job); registrationHidden.network.setForeground(false); return result; };
  await assert.rejects(registrationHidden.network.uploadCommentImage(bytes, pin, () => registrationHidden.context), /background/);
  assert.equal(registrationHidden.uploads.length, 0, 'background after registration cannot start multipart upload');
  const dispatched = harness(undefined, () => {
    dispatched.network.setForeground(false);
    assert.equal(dispatched.network.pending.size, 1, 'already dispatched multipart upload remains pending');
    dispatched.network.setForeground(true);
  });
  assert.equal(await dispatched.network.uploadCommentImage(bytes, pin, () => dispatched.context), 'a'.repeat(32));
  assert.equal(dispatched.uploads.length, 1, 'foreground restoration never repeats upload');
  console.log('comment upload: native registration/status, multipart bytes, host restriction, credential isolation and stale cancellation passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
