import { PIN_NATIVE_PIN_MENUS_ENABLED } from './PinmonyPinMenuNative';
import { PIN_NATIVE_PROFILE_SETTINGS_ENABLED } from './PinmonyProfileSettingsClient';
import { PIN_NATIVE_SHARE_PUBLISH_ENABLED } from './PinmonySharePublishClient';
import { PIN_NATIVE_COMMENT_WRITES_ENABLED } from './PinmonyCommentNativeWrites';
import { PIN_NATIVE_POST_OPERATIONS_ENABLED } from './PinmonyPostNativeOperations';
import { PIN_NATIVE_BOARD_READS_ENABLED } from './PinmonyBoardNativeReads';
import { PIN_NATIVE_PROFILE_READS_ENABLED } from './PinmonyProfileNativeReads';
import { PIN_NATIVE_INBOX_MESSAGES_ENABLED } from './PinmonyInboxMessagesNativeReads';
import { PIN_NATIVE_INBOX_UPDATES_ENABLED } from './PinmonyInboxUpdatesNativeReads';
import { PIN_NATIVE_SEARCH_READS_ENABLED } from './PinmonySearchNativeReads';
import { PIN_NATIVE_SEARCH_DISCOVERY_ENABLED } from './PinmonySearchDiscoveryNativeReads';
import { PIN_NATIVE_HOME_READS_ENABLED } from './PinmonyHomeNativeReads';
import { PIN_NATIVE_DETAIL_AUXILIARY_ENABLED } from './PinmonyDetailNativeAuxiliary';
import { PIN_NATIVE_DETAIL_READS_ENABLED } from './PinmonyDetailNativeReads';
import { PIN_PROFILE_PANEL_SCRIPT } from 'feature_profile';
import { allowsSpeculativeReads } from 'common_foundation';
import { PIN_NATIVE_NETWORK_SCRIPT, PIN_NATIVE_NETWORK_ENABLED, PIN_READ_MERGING_ENABLED, useNativeTransport } from 'common_network';
import { BOTTOM_BAR_SCRIPT } from '../app/PinmonyBottomBarScript';
import { PIN_MORE_MENU_BRIDGE_SCRIPT } from 'feature_pin';
import { SHARE_PANEL_BRIDGE_SCRIPT } from 'feature_pin';
import { SHARE_LINK_SCRIPT } from 'feature_pin';
import { PIN_AUTH_BRIDGE_SCRIPT, PIN_GOOGLE_LOGIN_UNAVAILABLE_SCRIPT } from 'common_session';
import { PIN_BOARD_API_ENABLED, PIN_BOARD_API_SCRIPT, PIN_BOARD_SHARE_BRIDGE_SCRIPT } from 'feature_board';
import { PIN_DETAIL_BRIDGE_SCRIPT } from 'feature_pin';
import { PIN_DETAIL_API_ENABLED, PIN_DETAIL_API_SCRIPT } from 'feature_pin';
import { PIN_CAROUSEL_API_ENABLED, PIN_CAROUSEL_API_SCRIPT } from 'feature_pin';
import { PIN_VIDEO_API_ENABLED, PIN_VIDEO_API_SCRIPT } from 'feature_pin';
import { PIN_POST_API_ENABLED, PIN_POST_API_SCRIPT } from 'feature_pin';
import { PIN_POST_EXTENSIONS_ENABLED, PIN_POST_EXTENSIONS_SCRIPT } from 'feature_pin';
import { PIN_EDIT_API_ENABLED, PIN_EDIT_API_SCRIPT } from 'feature_pin';
import { PIN_NAVIGATION_BRIDGE_SCRIPT } from '../app/PinmonyNavigationScript';
import { PIN_PROFILE_BRIDGE_SCRIPT } from 'feature_profile';
import { PIN_PROFILE_API_ENABLED, PIN_PROFILE_API_SCRIPT } from 'feature_profile';
import { PIN_PROFILE_ORGANIZE_ENABLED, PIN_PROFILE_ORGANIZE_SCRIPT } from 'feature_profile';
import { PIN_HOME_BRIDGE_SCRIPT } from 'feature_home';
import { PIN_HOME_API_ENABLED, PIN_HOME_API_SCRIPT } from 'feature_home';
import { PIN_INBOX_API_ENABLED, PIN_INBOX_API_SCRIPT } from 'feature_inbox';
import { PIN_INBOX_CONTACTS_API_ENABLED, PIN_INBOX_CONTACTS_API_SCRIPT } from 'feature_inbox';
import { PIN_INBOX_BRIDGE_SCRIPT } from 'feature_inbox';
import { PIN_INBOX_CONVERSATIONS_API_ENABLED, PIN_INBOX_CONVERSATION_SCRIPT } from 'feature_inbox';
import { PIN_SEARCH_BRIDGE_SCRIPT } from 'feature_search';
import { PIN_SEARCH_QUIZ_API_ENABLED, PIN_SEARCH_QUIZ_API_SCRIPT } from 'feature_search';
import { PIN_SEARCH_API_ENABLED, PIN_SEARCH_API_SCRIPT } from 'feature_search';
import { PIN_SEARCH_DISCOVERY_API_ENABLED, PIN_SEARCH_DISCOVERY_API_SCRIPT } from 'feature_search';
import { PIN_SEARCH_UI_API_ENABLED, PIN_SEARCH_UI_API_SCRIPT } from 'feature_search';

// Order is part of the existing bridge contract. Keep the Web host mounted in Index.
function nonBoardDomScript(script: string): string {
  return '(function () { if (window.PinmonyBoardDocument === true) return;' + script + '\n})();';
}

export function pinWebDocumentStartScripts(): ScriptItem[] {
  return [
              { script: 'window.PinmonyBoardDocument = (function () { var p = location.pathname.split("/").filter(Boolean);' +
                'return p.length === 2 && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(p[0]) && !/^_|^(?:followers|following)$/i.test(p[1]); })();' +
                'window.PinmonySpeculativeReadsEnabled = ' + allowsSpeculativeReads().toString() + ';' +
                'window.PinmonyNativeProfileSettingsEnabled = ' + PIN_NATIVE_PROFILE_SETTINGS_ENABLED.toString() + ';' +
                'window.PinmonyNativeSharePublishEnabled = ' + PIN_NATIVE_SHARE_PUBLISH_ENABLED.toString() + ';' +
                'window.PinmonyNativeBoardPinWritesEnabled = ' + PIN_NATIVE_BOARD_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeBoardManagementWritesEnabled = ' + PIN_NATIVE_BOARD_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeBoardContentWritesEnabled = ' + PIN_NATIVE_BOARD_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeBoardCollaboratorWritesEnabled = ' + PIN_NATIVE_BOARD_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeBoardAuxReadsEnabled = ' + PIN_NATIVE_BOARD_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeBoardReadsEnabled = ' + PIN_NATIVE_BOARD_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativePinMenusEnabled = ' + PIN_NATIVE_PIN_MENUS_ENABLED.toString() + ';' +
                'window.PinmonyNativeProfileReadsEnabled = ' + PIN_NATIVE_PROFILE_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeInboxMessagesEnabled = ' + PIN_NATIVE_INBOX_MESSAGES_ENABLED.toString() + ';' +
                'window.PinmonyNativeInboxWritesEnabled = ' + PIN_NATIVE_INBOX_MESSAGES_ENABLED.toString() + ';' +
                'window.PinmonyNativeInboxUpdatesEnabled = ' + PIN_NATIVE_INBOX_UPDATES_ENABLED.toString() + ';' +
                'window.PinmonyNativeSearchReadsEnabled = ' + PIN_NATIVE_SEARCH_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeSearchDiscoveryEnabled = ' + PIN_NATIVE_SEARCH_DISCOVERY_ENABLED.toString() + ';' +
                'window.PinmonyNativeHomeReadsEnabled = ' + PIN_NATIVE_HOME_READS_ENABLED.toString() + ';' +
                'window.PinmonyNativeCommentWritesEnabled = ' + PIN_NATIVE_COMMENT_WRITES_ENABLED.toString() + ';' +
                'window.PinmonyNativePostOperationsEnabled = ' + PIN_NATIVE_POST_OPERATIONS_ENABLED.toString() + ';' +
                'window.PinmonyNativeDetailAuxiliaryEnabled = ' + PIN_NATIVE_DETAIL_AUXILIARY_ENABLED.toString() + ';' +
                'window.PinmonyNativeDetailReadsEnabled = ' + PIN_NATIVE_DETAIL_READS_ENABLED.toString() + ';' +
                'window.PinmonyReadMergingEnabled = ' + PIN_READ_MERGING_ENABLED.toString() + ';' +
                'window.PinmonyNativeNetworkEnabled = ' + PIN_NATIVE_NETWORK_ENABLED.toString() + ';' + PIN_NATIVE_NETWORK_SCRIPT, scriptRules: ['*'] },
              { script: PIN_AUTH_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: PIN_GOOGLE_LOGIN_UNAVAILABLE_SCRIPT, scriptRules: ['*'] },
              { script: PIN_NAVIGATION_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: nonBoardDomScript(SHARE_LINK_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonyPostApiEnabled = ' + PIN_POST_API_ENABLED.toString() + ';' + useNativeTransport(PIN_POST_API_SCRIPT) +
                'window.PinmonyPostExtensionsEnabled = ' + PIN_POST_EXTENSIONS_ENABLED.toString() + ';' + PIN_POST_EXTENSIONS_SCRIPT + 'window.PinmonyEditApiEnabled = ' + PIN_EDIT_API_ENABLED.toString() + ';' + PIN_EDIT_API_SCRIPT, scriptRules: ['*'] },
              { script: '(function () { if (window.PinmonyBoardDocument === true) {' + PIN_BOARD_SHARE_BRIDGE_SCRIPT +
                '} else {' + SHARE_PANEL_BRIDGE_SCRIPT + '} })();', scriptRules: ['*'] },
              { script: nonBoardDomScript(PIN_MORE_MENU_BRIDGE_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonyDetailApiEnabled = ' + PIN_DETAIL_API_ENABLED.toString() + ';' +
                'window.PinmonyVideoApiEnabled = ' + PIN_VIDEO_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_VIDEO_API_SCRIPT) + 'window.PinmonyCarouselApiEnabled = ' + PIN_CAROUSEL_API_ENABLED.toString() + ';' + useNativeTransport(PIN_CAROUSEL_API_SCRIPT) + useNativeTransport(PIN_DETAIL_API_SCRIPT), scriptRules: ['*'] },
              { script: nonBoardDomScript(PIN_DETAIL_BRIDGE_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonyProfileApiEnabled = ' + PIN_PROFILE_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_PROFILE_API_SCRIPT) + 'window.PinmonyProfileOrganizeEnabled = ' + PIN_PROFILE_ORGANIZE_ENABLED.toString() + ';' +
                useNativeTransport(PIN_PROFILE_ORGANIZE_SCRIPT) + useNativeTransport(PIN_PROFILE_PANEL_SCRIPT), scriptRules: ['*'] },
              { script: PIN_PROFILE_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: 'window.PinmonyBoardApiEnabled = ' + PIN_BOARD_API_ENABLED.toString() + ';' + useNativeTransport(PIN_BOARD_API_SCRIPT),
                scriptRules: ['*'] },
              { script: 'window.PinmonyInboxApiEnabled = ' + PIN_INBOX_API_ENABLED.toString() + ';' + useNativeTransport(PIN_INBOX_API_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonyInboxContactsApiEnabled = ' + PIN_INBOX_CONTACTS_API_ENABLED.toString() + ';' + useNativeTransport(PIN_INBOX_CONTACTS_API_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonyInboxConversationsEnabled = ' + PIN_INBOX_CONVERSATIONS_API_ENABLED.toString() + ';' + useNativeTransport(PIN_INBOX_CONVERSATION_SCRIPT), scriptRules: ['*'] },
              { script: PIN_INBOX_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: 'window.PinmonyHomeApiEnabled = ' + PIN_HOME_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_HOME_API_SCRIPT), scriptRules: ['*'] },
              { script: PIN_HOME_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: 'window.PinmonySearchUiApiEnabled = ' + PIN_SEARCH_UI_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_SEARCH_UI_API_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonySearchApiEnabled = ' + PIN_SEARCH_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_SEARCH_API_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonySearchDiscoveryApiEnabled = ' + PIN_SEARCH_DISCOVERY_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_SEARCH_DISCOVERY_API_SCRIPT), scriptRules: ['*'] },
              { script: 'window.PinmonySearchQuizApiEnabled = ' + PIN_SEARCH_QUIZ_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_SEARCH_QUIZ_API_SCRIPT), scriptRules: ['*'] },
              { script: PIN_SEARCH_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: nonBoardDomScript(BOTTOM_BAR_SCRIPT), scriptRules: ['*'] }
            ];
}
