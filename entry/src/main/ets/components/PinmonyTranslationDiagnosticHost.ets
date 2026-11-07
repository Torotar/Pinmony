import { webview } from '@kit.ArkWeb';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyTranslationDiagnostics } from '../app/PinmonyTranslationDiagnostics';

// The operator navigates this blank host through local DevTools. It has no JS
// Proxy, business callbacks, automatic translation, or visible webpage surface.
@Component
export struct PinmonyTranslationDiagnosticHost {
  private diagnosticController: webview.WebviewController = new webview.WebviewController();

  aboutToDisappear(): void {
    PinmonyTranslationDiagnostics.detach(this.diagnosticController);
  }

  build() {
    Stack() {
      Web({ src: 'about:blank', controller: this.diagnosticController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onOverrideUrlLoading((request: WebResourceRequest): boolean => {
          return request.isMainFrame() && !PinmonyTranslationDiagnostics.allowsPage(request.getRequestUrl());
        })
        .onControllerAttached((): void => {
          PinmonyTranslationDiagnostics.attach(this.diagnosticController);
          PinmonyRuntimeLog.info('TranslationDiagnostic: host-attached manual-only=true');
        })
        .onPageEnd((): void => { PinmonyTranslationDiagnostics.publish(); })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .opacity(0)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no-hide-descendants')
  }
}
