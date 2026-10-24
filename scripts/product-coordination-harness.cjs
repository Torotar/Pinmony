const fs = require('node:fs'), vm = require('node:vm');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const bindings = require('./product-coordination-bindings.json');
const runtimes = new WeakMap();
function runtime(ts, globals = {}) {
    if (runtimes.has(globals))
        return runtimes.get(globals);
    const original = globals;
    globals = { ...globals };
    delete globals.exports;
    delete globals.require;
    const mocks = { '@kit.CoreFileKit': { fileIo: {} }, '@ohos.file.fs': {}, '@kit.CryptoArchitectureKit': {}, '@ohos.util': {}, '@kit.ArkTS': { util: {} }, '@kit.ArkUI': {}, '@kit.AbilityKit': {}, '@kit.ShareKit': {}, '@kit.BasicServicesKit': {}, '@kit.MediaLibraryKit': {}, '@kit.ArkWeb': {}, '@kit.UIDesignKit': {} };
    mocks['@kit.RemoteCommunicationKit'] = { rcp: {} };
    mocks['@kit.UIDesignKit'] = { HdsAnimationMode: globals.HdsAnimationMode || { SCROLL_ANIMATION: 0, CLICK_ANIMATION: 1 } };
    const base = createArktsLoader(ts, { ...mocks }, globals);
    mocks.common_foundation = new Proxy({}, { get: (_, key) => key === 'PinmonyRuntimeLog' ? (globals.PinmonyRuntimeLog || { info() { }, warn() { }, error() { } }) : base.loadPackage('common_foundation')[key] });
    const loader = createArktsLoader(ts, mocks, globals);
    runtimes.set(original, loader);
    return loader;
}
function stores(native, loader, globals = {}) {
    native.usesNativeProfileReads ||= () => globals.PIN_NATIVE_PROFILE_READS_ENABLED === true;
    native.uiText ||= source => require('./local-message-test-fixture.cjs').rawLocalMessages.text(source);
    native.sessionDocumentUrl ||= () => native.controller?.getUrl?.() || '';
    native.runSessionScript ||= script => native.controller?.runJavaScript?.(script) || Promise.resolve('');
    native.loadSessionDocument ||= url => native.controller?.loadUrl?.(url);
    const { PinmonyBusinessSession } = loader.loadFile('common_session/src/main/ets/services/PinmonyBusinessSession.ets');
    native.businessSession ||= new PinmonyBusinessSession();
    const { PinmonySessionEnvironment } = loader.loadFile('common_session/src/main/ets/services/PinmonySessionEnvironment.ets');
    native.sessionEnvironment ||= new PinmonySessionEnvironment();
    if (!native.sessionEnvironment.userAgent() && native.controller?.getUserAgent) native.sessionEnvironment.capture(native.controller.getUserAgent());
    native.authenticatedProfileUrl ??= '';
    if (!native.nativeBusinessSessionContext) {
      const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
      const body = index.match(/private nativeBusinessSessionContext\(\): PinmonyBusinessSessionContext \{([\s\S]*?)\n  \}/)[1];
      native.nativeBusinessSessionContext = Function(body);
    }
    for (const feature of ['home', 'pin', 'board', 'search', 'profile', 'inbox', 'settings']) {
        const field = feature + 'Store', name = 'Pinmony' + feature[0].toUpperCase() + feature.slice(1) + 'Store';
        const Type = loader.loadFile('feature_' + feature + '/src/main/ets/stores/' + name + '.ets')[name];
        if (!native[field])
            native[field] = new Type();
        else if (Object.getPrototypeOf(native[field])?.constructor?.name === 'Object') {
            const defaults = new Type();
            for (const key of Object.keys(defaults))
                if (!Object.hasOwn(native[field], key))
                    native[field][key] = defaults[key];
            Object.setPrototypeOf(native[field], Type.prototype);
        }
    }

}
function createHost(Type, ts, globals = {}) {
    const native = new Type();
    stores(native, runtime(ts, globals), globals);
    return native;
}
function bind(native, ts, globals = {}, groups) {
    const loader = runtime(ts, globals);
    stores(native, loader, globals);
    if (groups?.includes('Session') && !native.inboxMessagesNativeReads) bind(native, ts, globals, ['NativeInboxMessages']);
    if (groups?.includes('Session') && !native.inboxUpdatesNativeReads) bind(native, ts, globals, ['NativeInboxUpdates']);
    if (groups?.includes('Session') && !native.searchNativeReads) bind(native, ts, globals, ['NativeSearchReads']);
    if (groups?.includes('Session') && !native.boardNativeReads) bind(native, ts, globals, ['NativeBoardReads']);
    if (groups?.includes('Session') && !native.profileNativeReads) bind(native, ts, globals, ['NativeProfileReads']);
    if (groups?.includes('Session') && !native.searchDiscoveryNativeReads) bind(native, ts, globals, ['NativeSearchDiscovery']);
    if (groups?.includes('Session') && !native.homeNativeReads) bind(native, ts, globals, ['NativeHomeReads']);
    if (groups?.includes('NativeDetailAuxiliary') && !native.detailNativeReads) bind(native, ts, globals, ['NativeDetailReads']);
    if (groups?.includes('DetailOpening') && !native.detailNativeReads) bind(native, ts, globals, ['NativeDetailReads']);
    if (groups?.includes('PinmonyFailureRecoveryCoordinator') && !native.rootContextCoordinator?.failDocument) {
        delete native.rootContextCoordinator;
        bind(native, ts, globals, ['RootContext']);
    }
    native.pageTasks ||= new (loader.loadFile('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets').PinmonyTaskRegistry)();
    require('./medium-priority-controller-harness.cjs').bindWork(native, ts, globals);
    const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
    if ((!groups || groups.includes('BoardOperations')) && !native.boardOperationsController) {
        const match = index.match(/private readonly boardOperationsController:[^=]+ = new PinmonyBoardOperationsController\(this.boardStore, \{([\s\S]*?)\} as PinmonyBoardOperationsPorts\);/);
        const exported = loader.loadFile('feature_board/src/main/ets/controllers/PinmonyBoardOperationsController.ets'), out = {};
        vm.runInNewContext(ts.transpileModule('export function bind(){this.boardOperationsController=new PinmonyBoardOperationsController(this.boardStore,{' + match[1] + '});}', { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, { exports: out, ...globals, ...exported });
        out.bind.call(native);
    }
    for (const item of bindings.filter((v, i, a) => a.findIndex(x => x.field === v.field) === i)) {
        if (groups && !groups.includes(item.group))
            continue;
        if (native[item.field])
            continue;
        const match = index.match(new RegExp('private readonly ' + item.field + ': [^=]+ = new ' + item.className + '\\(\\{([\\s\\S]*?)\\} as ' + item.className + 'Ports\\);'));
        if (!match)
            throw Error('Missing Index binding ' + item.field);
        const exported = loader.loadFile('entry/src/main/ets/app/' + item.className + '.ets'), out = {};
        vm.runInNewContext(ts.transpileModule('export function bind(){this.' + item.field + '=new ' + item.className + '({' + match[1] + '});}', { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, { exports: out, ...globals, ...exported });
        out.bind.call(native);
        for (const b of bindings.filter(x => x.field === item.field)) {
            if (Object.hasOwn(native, b.name) && typeof native[b.name] === 'function')
                native[item.field][b.name] = native[b.name].bind(native);
        }
    }
    return loader;
}
function run(ts, code, context = {}, options) {
    context.PinmonyI18n ??= require('./local-message-test-fixture.cjs').rawLocalMessages;
    context.PIN_NATIVE_PIN_MENUS_ENABLED ??= false; // Legacy fixtures; default native menu has production execution coverage.
    context.PIN_NATIVE_PROFILE_SETTINGS_ENABLED ??= false; // Legacy bridge fixtures; native profile/settings have production-binding coverage.
    context.PIN_NATIVE_DETAIL_AUXILIARY_ENABLED ??= false; // Legacy fixtures; native auxiliary paths have focused execution coverage.
    context.PIN_NATIVE_SHARE_PUBLISH_ENABLED ??= false; // Legacy bridge fixtures; native production bindings have focused coverage.
    context.PIN_NATIVE_POST_OPERATIONS_ENABLED ??= false; // Existing bridge fixtures; native post paths have focused coverage.
    context.PIN_NATIVE_BOARD_READS_ENABLED ??= false; // Legacy bridge tests; default native board path has its own check.
    context.PIN_NATIVE_PROFILE_READS_ENABLED ??= false; // Extracted legacy hosts select their branch explicitly; native defaults have dedicated execution checks.
    context.PIN_NATIVE_INBOX_MESSAGES_ENABLED ??= false; // Extracted legacy hosts select their branch explicitly; native defaults have dedicated execution checks.
    context.PIN_NATIVE_INBOX_UPDATES_ENABLED ??= false; // Extracted legacy hosts select their branch explicitly; native defaults have dedicated execution checks.
    context.PIN_NATIVE_SEARCH_READS_ENABLED ??= false; // Extracted legacy hosts select their branch explicitly; native defaults have dedicated execution checks.
    context.PIN_NATIVE_SEARCH_DISCOVERY_ENABLED ??= false; // Extracted legacy hosts select their branch explicitly; native defaults have dedicated execution checks.
    context.PIN_NATIVE_HOME_READS_ENABLED ??= false; // Extracted legacy hosts select their branch explicitly; native defaults have dedicated execution checks.
    context.PIN_NATIVE_DETAIL_READS_ENABLED ??= false; // Extracted legacy hosts select their branch explicitly; native defaults have dedicated execution checks.
    context.PinmonyRouteParser ||= runtime(ts, context).loadFile('entry/src/main/ets/app/PinmonyRouteParser.ets').PinmonyRouteParser;
    if (!context.require)
        context.require = spec => runtime(ts, context).loadPackage(spec);
    const result = vm.runInNewContext(code, context, options);
    const classes = new Set([result, ...Object.values(context)].filter(v => typeof v === 'function' && v.prototype));
    for (const Type of classes) {
        if (!Object.getOwnPropertyNames(Type.prototype).some(n => typeof Object.getOwnPropertyDescriptor(Type.prototype, n)?.value === 'function' && /this\.(?:[a-z]+Store|(?:rootContext|navigation|session|photoMenu|detailOpening|businessResults|webLifecycle|networkBridge|failureRecovery|bottomBar)Coordinator|boardOperationsController)/.test(Object.getOwnPropertyDescriptor(Type.prototype, n).value.toString())))
            continue;
        for (const name of Object.getOwnPropertyNames(Type.prototype)) {
            if (name === 'constructor')
                continue;
            const fn = Type.prototype[name];
            if (typeof fn !== 'function')
                continue;
            const moved = name === 'boardOperation' && fn.toString().includes('this.boardOperationsController') ? { group: 'BoardOperations' } : bindings.find(b => b.name === name && fn.toString().includes('this.' + b.field + '.'));
            const notify = fn.toString().includes('this.rootContextCoordinator.notify()');
            if (!moved && !notify)
                continue;
            Type.prototype[name] = function (...args) {
                if (moved?.field && this[moved.field] && typeof this[moved.field][name] !== 'function')
                    delete this[moved.field];
                bind(this, ts, context, moved ? [moved.group] : ['RootContext']);
                return fn.apply(this, args);
            };
        }
        const original = Type.prototype;
        for (const name of Object.getOwnPropertyNames(original)) {
            const fn = original[name];
            if (name !== 'constructor' && typeof fn === 'function' && !fn.toString().includes('bind(this')) {
                original[name] = function (...args) {
                    stores(this, runtime(ts, context), context);
                    if (fn.toString().includes('this.boardNativeReads.')) bind(this, ts, context, ['NativeBoardReads']);
                    if (fn.toString().includes('this.profileNativeReads.')) bind(this, ts, context, ['NativeProfileReads']);
                    if (fn.toString().includes('this.inboxMessagesNativeReads.')) bind(this, ts, context, ['NativeInboxMessages']);
                    if (fn.toString().includes('this.inboxUpdatesNativeReads.')) bind(this, ts, context, ['NativeInboxUpdates']);
                    if (fn.toString().includes('this.searchNativeReads.')) bind(this, ts, context, ['NativeSearchReads']);
                    if (fn.toString().includes('this.searchDiscoveryNativeReads.')) bind(this, ts, context, ['NativeSearchDiscovery']);
                    if (fn.toString().includes('this.homeNativeReads.')) bind(this, ts, context, ['NativeHomeReads']);
                    if (fn.toString().includes('this.inboxMenuNative.')) bind(this, ts, context, ['NativeInboxMenu']);
                    if (fn.toString().includes('this.boardInvitationNative.')) bind(this, ts, context, ['NativeInvitations']);
                    if (fn.toString().includes('this.detailNativeAuxiliary.')) bind(this, ts, context, ['NativeDetailAuxiliary']);
                    if (fn.toString().includes('this.detailNativeReads.')) bind(this, ts, context, ['NativeDetailReads']);
                    if (fn.toString().includes('this.inboxActionsController.'))
                        require('./medium-priority-controller-harness.cjs').bind(this, ts, context, ['inboxActions']);
                    if (fn.toString().includes('this.webLifecycleCoordinator.'))
                        bind(this, ts, context, ['WebLifecycle']);
                    if (fn.toString().includes('this.photoMenuCoordinator.notify()'))
                        bind(this, ts, context, ['PhotoMenu']);
                    if (!this.coordinatorTasks || !this.pagePerformance?.beginSecondary)
                        require('./medium-priority-controller-harness.cjs').bindWork(this, ts, context);
                    return fn.apply(this, args);
                };
            }
        }
    }
    return result;
}
module.exports = { runtime, stores, createHost, bind, run };
