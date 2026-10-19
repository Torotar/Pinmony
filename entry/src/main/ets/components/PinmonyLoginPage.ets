import { webview } from '@kit.ArkWeb';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyShareBridge } from '../app/PinmonyShareBridge';
import { PinmonyWebLifecycleCoordinator } from '../app/PinmonyWebLifecycleCoordinator';
import { GOOGLE_LOGIN_UNAVAILABLE_EVENT, isGoogleLoginTarget } from 'common_session';

const PINTEREST_URL: string = 'https://www.pinterest.com/';
export interface PinmonyLoginView {
  url?: string;
  isCurrent?: (controller: webview.WebviewController) => boolean;
  controller: webview.WebviewController;
  bridge: PinmonyShareBridge;
  scripts: ScriptItem[];
  lifecycle: PinmonyWebLifecycleCoordinator;
  visible: boolean;
  authenticated: boolean;
  presentationOnly: boolean;
  captureEnvironment: () => void;
  onUnsupportedLogin: () => void;
}

export function notifyUnsupportedLogin(view: PinmonyLoginView): void {
  if (view.isCurrent?.(view.controller) === false || !view.visible || view.authenticated) return;
  view.onUnsupportedLogin();
}

export function rejectGoogleLoginNavigation(view: PinmonyLoginView, url: string, mainFrame: boolean): boolean {
  if (!mainFrame || !isGoogleLoginTarget(url)) return false;
  notifyUnsupportedLogin(view);
  return true;
}

// Index mounts this host only for login in the native lifecycle. The legacy
// manual rollback keeps it hidden after authentication; business pages stay native.
@Builder
export function PinmonyBuildLoginPage(view: PinmonyLoginView) {
        Stack() {
          Web({ src: view.url || PINTEREST_URL, controller: view.controller })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .darkMode(WebDarkMode.Auto)
            .forceDarkAccess(true)
            .javaScriptProxy({
              object: view.bridge,
              name: 'PinmonyShareBridge',
              methodList: ['homeMenuChanged', 'authState', 'postState', 'share', 'navigation', 'pageNavigation', 'pageBack', 'sheetState', 'moreState', 'detailState',
                'profileState', 'profilePublish', 'boardState', 'inboxState', 'homeState', 'searchState', 'networkRequest', 'cancelNetwork'],
              controller: view.controller
            })
            .runJavaScriptOnDocumentStart(view.scripts)
            .onControllerAttached(() => { if(view.isCurrent?.(view.controller) === false)return;view.captureEnvironment(); view.lifecycle.controllerAttached(); })
            .onPageBegin((event) => { if(view.isCurrent?.(view.controller) === false)return;view.captureEnvironment(); view.lifecycle.pageBegin(event.url); })
            .onPageEnd(() => { if(view.isCurrent?.(view.controller) === false)return;view.captureEnvironment(); view.lifecycle.pageEnd(); })
            .onConsole((event) => {
              if(view.isCurrent?.(view.controller) === false)return false;
              if (!event) return false;
              try {
                const message: string = event.message.getMessage();
                if (message === GOOGLE_LOGIN_UNAVAILABLE_EVENT) { notifyUnsupportedLogin(view); return true; }
                return view.lifecycle.consoleMessage(message);
              }
              catch (_) { return false; }
            })
            .onErrorReceive((event) => {
              if(view.isCurrent?.(view.controller) === false)return;
              if (view.presentationOnly || !event) return;
              try {
                if (event.request.isMainFrame()) view.lifecycle.mainFrameError(
                  event.request.getRequestUrl(), event.error.getErrorCode(), event.error.getErrorInfo());
              } catch (_) { PinmonyRuntimeLog.warn('Web: error callback unavailable'); }
            })
            .onOverrideUrlLoading((request: WebResourceRequest) => {
              if(view.isCurrent?.(view.controller) === false)return true;
              try {
                const mainFrame: boolean = request.isMainFrame();
                if (rejectGoogleLoginNavigation(view, request.getRequestUrl(), mainFrame)) return true;
                return mainFrame ? view.lifecycle.overrideUrl(request.getRequestUrl()) : false;
              }
              catch (_) { return view.authenticated; }
            })
            .onLoadIntercept((event) => {
              if(view.isCurrent?.(view.controller) === false)return true;
              if (!event) return false;
              try {
                if (rejectGoogleLoginNavigation(view, event.data.getRequestUrl(), event.data.isMainFrame())) return true;
                return view.lifecycle.interceptLoad(event.data.getRequestUrl(), event.data.isMainFrame());
              }
              catch (_) { return view.authenticated; }
            })
            .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .accessibilityLevel(view.visible ? 'auto' : 'no-hide-descendants')
        .opacity(view.visible ? 1 : 0)
        .hitTestBehavior(view.visible ? HitTestMode.Default : HitTestMode.None)

}
