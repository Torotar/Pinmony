import { PIN_PROFILE_PANEL_SCRIPT } from 'feature_profile';
import { PIN_NATIVE_NETWORK_SCRIPT, PIN_NATIVE_NETWORK_ENABLED, useNativeTransport } from 'common_network';
import { BOTTOM_BAR_SCRIPT } from '../app/PinmonyBottomBarScript';
import { PIN_MORE_MENU_BRIDGE_SCRIPT } from 'feature_pin';
import { SHARE_PANEL_BRIDGE_SCRIPT } from 'feature_pin';
import { SHARE_LINK_SCRIPT } from 'feature_pin';
import { PIN_AUTH_BRIDGE_SCRIPT } from 'common_session';
import { PIN_BOARD_API_ENABLED, PIN_BOARD_API_SCRIPT } from 'feature_board';
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
export function pinWebDocumentStartScripts(): ScriptItem[] {
  return [
              { script: 'window.PinmonyNativeNetworkEnabled = ' + PIN_NATIVE_NETWORK_ENABLED.toString() + ';' + PIN_NATIVE_NETWORK_SCRIPT, scriptRules: ['*'] },
              { script: PIN_AUTH_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: PIN_NAVIGATION_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: SHARE_LINK_SCRIPT, scriptRules: ['*'] },
              { script: 'window.PinmonyPostApiEnabled = ' + PIN_POST_API_ENABLED.toString() + ';' + useNativeTransport(PIN_POST_API_SCRIPT) +
                'window.PinmonyPostExtensionsEnabled = ' + PIN_POST_EXTENSIONS_ENABLED.toString() + ';' + PIN_POST_EXTENSIONS_SCRIPT + 'window.PinmonyEditApiEnabled = ' + PIN_EDIT_API_ENABLED.toString() + ';' + PIN_EDIT_API_SCRIPT, scriptRules: ['*'] },
              { script: SHARE_PANEL_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: PIN_MORE_MENU_BRIDGE_SCRIPT, scriptRules: ['*'] },
              { script: 'window.PinmonyDetailApiEnabled = ' + PIN_DETAIL_API_ENABLED.toString() + ';' +
                'window.PinmonyVideoApiEnabled = ' + PIN_VIDEO_API_ENABLED.toString() + ';' +
                useNativeTransport(PIN_VIDEO_API_SCRIPT) + 'window.PinmonyCarouselApiEnabled = ' + PIN_CAROUSEL_API_ENABLED.toString() + ';' + useNativeTransport(PIN_CAROUSEL_API_SCRIPT) + useNativeTransport(PIN_DETAIL_API_SCRIPT), scriptRules: ['*'] },
              { script: PIN_DETAIL_BRIDGE_SCRIPT, scriptRules: ['*'] },
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
              { script: BOTTOM_BAR_SCRIPT, scriptRules: ['*'] }
            ];
}
