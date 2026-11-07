import { UIContext } from '@kit.ArkUI';
import { HdsNavigationTitleBarOptions, HdsNavigationTitleBarStyle, HdsNavigationIconItemStyle } from '@kit.UIDesignKit';

/** Resolve app colors in the host's current configuration before HDS builds its
 * alternate palette. Passing Resource objects there can select a stale adapter
 * on HarmonyOS 7. Keep callbacks, geometry, safe areas and material unchanged. */
export class PinmonyHdsTitleBar {
  static resolve(context: UIContext, options: HdsNavigationTitleBarOptions,
    _darkMode: boolean): HdsNavigationTitleBarOptions {
    // The caller reads its StorageLink for every options evaluation. Do not
    // cache resolved numbers across an application/system color-mode change.
    return { padding: options.padding, content: options.content, enableHoverMode: options.enableHoverMode,
      avoidLayoutSafeArea: options.avoidLayoutSafeArea, enableComponentSafeArea: options.enableComponentSafeArea,
      style: options.style ? { scrollEffectOpts: options.style.scrollEffectOpts,
        blurStrategy: options.style.blurStrategy, thermoCtrl: options.style.thermoCtrl,
        systemMaterialEffect: options.style.systemMaterialEffect,
        originalStyle: PinmonyHdsTitleBar.style(context, options.style.originalStyle),
        scrollEffectStyle: PinmonyHdsTitleBar.style(context, options.style.scrollEffectStyle) } : undefined };
  }

  private static color(context: UIContext, value: ResourceColor | undefined): ResourceColor | undefined {
    if (!value || typeof value !== 'object') return value;
    try {
      const host = context.getHostContext();
      if (!host || value.id < 0) return value;
      return host.resourceManager.getColorSync(value.id);
    } catch (_) { return value; }
  }

  private static icon(context: UIContext, icon: HdsNavigationIconItemStyle | undefined): HdsNavigationIconItemStyle | undefined {
    return icon ? { backgroundColor: PinmonyHdsTitleBar.color(context, icon.backgroundColor),
      iconColor: PinmonyHdsTitleBar.color(context, icon.iconColor),
      textColor: PinmonyHdsTitleBar.color(context, icon.textColor) } : undefined;
  }

  private static style(context: UIContext, style: HdsNavigationTitleBarStyle | undefined): HdsNavigationTitleBarStyle | undefined {
    if (!style) return undefined;
    const content = style.contentStyle;
    return { backgroundStyle: style.backgroundStyle ? {
      backgroundColor: PinmonyHdsTitleBar.color(context, style.backgroundStyle.backgroundColor),
      maskExtraHeight: style.backgroundStyle.maskExtraHeight, blurRadius: style.backgroundStyle.blurRadius } : undefined,
      contentStyle: content ? {
        titleStyle: content.titleStyle ? {
          mainTitleColor: PinmonyHdsTitleBar.color(context, content.titleStyle.mainTitleColor),
          subTitleColor: PinmonyHdsTitleBar.color(context, content.titleStyle.subTitleColor),
          mainTitleShadowColor: PinmonyHdsTitleBar.color(context, content.titleStyle.mainTitleShadowColor),
          subTitleShadowColor: PinmonyHdsTitleBar.color(context, content.titleStyle.subTitleShadowColor) } : undefined,
        backIconStyle: PinmonyHdsTitleBar.icon(context, content.backIconStyle),
        menuStyle: PinmonyHdsTitleBar.icon(context, content.menuStyle),
        subIconStyle: PinmonyHdsTitleBar.icon(context, content.subIconStyle),
        dividerStyle: content.dividerStyle ? { dividerColor: PinmonyHdsTitleBar.color(context,
          content.dividerStyle.dividerColor) } : undefined } : undefined };
  }
}
