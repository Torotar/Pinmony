import { webview } from '@kit.ArkWeb';
import { PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED } from './PinmonyTranslationDiagnosticConfig';

interface PinmonyTranslationDiagnosticSample {
  task: number;
  page: string;
  commentId: string;
  language: string;
  nativeShape: string;
}

// Passive, process-local metadata only. Never reads credentials, copies response
// bodies, issues requests, or commits diagnostic results to the business Store.
export class PinmonyTranslationDiagnostics {
  private static controller: webview.WebviewController | undefined = undefined;
  private static sample: PinmonyTranslationDiagnosticSample | undefined = undefined;
  private static sequence: number = 0;

  static attach(controller: webview.WebviewController): void {
    if (!PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED) return;
    PinmonyTranslationDiagnostics.controller = controller;
    PinmonyTranslationDiagnostics.sample = undefined;
  }

  static detach(controller: webview.WebviewController): void {
    if (PinmonyTranslationDiagnostics.controller !== controller) return;
    PinmonyTranslationDiagnostics.controller = undefined;
    PinmonyTranslationDiagnostics.sample = undefined;
  }

  static begin(page: string, commentId: string, language: string): number {
    if (!PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED || !PinmonyTranslationDiagnostics.controller ||
        !/^https:\/\/(www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(page) ||
        !/^\d+$/.test(commentId) || language.length > 64) return 0;
    const task: number = ++PinmonyTranslationDiagnostics.sequence;
    PinmonyTranslationDiagnostics.sample = { task: task, page: page, commentId: commentId,
      language: language, nativeShape: 'pending' };
    PinmonyTranslationDiagnostics.publish();
    return task;
  }

  static finish(task: number, shape: string): void {
    const sample: PinmonyTranslationDiagnosticSample | undefined = PinmonyTranslationDiagnostics.sample;
    if (!sample || task !== sample.task || !['null', 'string', 'array', 'object', 'undefined', 'number', 'boolean'].includes(shape)) return;
    sample.nativeShape = shape;
    PinmonyTranslationDiagnostics.publish();
  }

  static publish(): void {
    const controller: webview.WebviewController | undefined = PinmonyTranslationDiagnostics.controller;
    if (!PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED || !controller) return;
    const script: string = 'window.__pinmonyTranslationDiagnosticContext=' +
      JSON.stringify(PinmonyTranslationDiagnostics.sample || null) + ';';
    try {
      if (!PinmonyTranslationDiagnostics.allowsPage(controller.getUrl())) return;
      controller.runJavaScript(script).catch((): void => {});
    } catch (_) {}
  }

  static allowsPage(url: string): boolean {
    return url === 'about:blank' || /^https:\/\/(www|uk)\.pinterest\.com(?:\/|$)/.test(url);
  }
}
