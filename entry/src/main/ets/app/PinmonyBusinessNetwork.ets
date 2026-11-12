import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyProfileNetwork } from 'feature_profile';
import { PinmonySearchNetwork, PhotoSearchRegion } from 'feature_search';
import { PinmonyBoardNetwork } from 'feature_board';
import { PinmonyPinNetwork } from 'feature_pin';
import { PinmonyInboxNetwork } from 'feature_inbox';
import { PinmonyHomeNetwork } from 'feature_home';
import { PinmonySettingsNetwork } from 'feature_settings';

// Product composition only; contracts and validation belong to feature services.
export class PinmonyBusinessNetwork extends PinmonyNativeNetwork {
  private readonly profileClient: PinmonyProfileNetwork = new PinmonyProfileNetwork(this);
  private readonly searchClient: PinmonySearchNetwork = new PinmonySearchNetwork(this);
  private readonly boardClient: PinmonyBoardNetwork = new PinmonyBoardNetwork(this);
  private readonly pinClient: PinmonyPinNetwork = new PinmonyPinNetwork(this);
  private readonly inboxClient: PinmonyInboxNetwork = new PinmonyInboxNetwork(this);
  private readonly homeClient: PinmonyHomeNetwork = new PinmonyHomeNetwork(this);
  private readonly settingsClient: PinmonySettingsNetwork = new PinmonySettingsNetwork(this);
  async requestBusinessProfileBoardFollow(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
      page: string, board: string, viewer: string, owner: () => boolean): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessProfileBoardFollow(job, session, page, board, viewer, owner); }
  async requestBusinessSharePublish(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    mode: string, objectId: string, viewer: string, contacts: string[], boards: string[], ownerCurrent: () => boolean, topics: string[] = [], sections: string[] = []): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessSharePublish(job, session, mode, objectId, viewer, contacts, boards, ownerCurrent, topics, sections); }
  async requestBusinessProfileInitialSort(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessProfileInitialSort(job, session, ownerCurrent); }
  async requestBusinessProfileSort(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    userId: string, viewerId: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessProfileSort(job, session, userId, viewerId, ownerCurrent); }
  async requestBusinessProfileSuggestion(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    clusterId: string, name: string, ownerCurrent: () => boolean, clusterPins: string[] = []): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessProfileSuggestion(job, session, clusterId, name, ownerCurrent, clusterPins); }
  async requestBusinessUserAvatarRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    profileUrl: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessUserAvatarRead(job, session, profileUrl, ownerCurrent); }
  async requestBusinessProfileRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    profileUrl: string, userId: string, ownerCurrent: () => boolean, viewerId: string = '', visitor: boolean = false): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessProfileRead(job, session, profileUrl, userId, ownerCurrent, viewerId, visitor); }
  async requestBusinessProfileSearchDelete(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    query: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessProfileSearchDelete(job, session, query, ownerCurrent); }
  async requestBusinessProfileSearchRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.profileClient.requestBusinessProfileSearchRead(job, session, ownerCurrent); }
  async uploadProfileAvatar(bytes: ArrayBuffer, mime: string, page: string, ownPage: string,
      session: () => PinmonyBusinessSessionContext, owner: () => boolean, id: string,
      dispatched: () => void): Promise<string>{ return this.profileClient.uploadProfileAvatar(bytes, mime, page, ownPage, session, owner, id, dispatched); }
  async uploadPublishImage(bytes: ArrayBuffer, mime: string, pin: string, context: () => PinmonyNetworkContext, viewer: string, ownerId: string, mediaIds: string[]): Promise<PinmonyPublishImageUpload>{ return this.profileClient.uploadPublishImage(bytes, mime, pin, context, viewer, ownerId, mediaIds); }
  async requestBusinessSearchUserFollow(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
      page: string, user: string, viewer: string, owner: () => boolean): Promise<PinmonyNetworkReply>{ return this.searchClient.requestBusinessSearchUserFollow(job, session, page, user, viewer, owner); }
  async requestBusinessSearchRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.searchClient.requestBusinessSearchRead(job, session, ownerCurrent); }
  async requestBusinessSearchDiscoveryRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.searchClient.requestBusinessSearchDiscoveryRead(job, session, ownerCurrent); }
  async readPhotoHistory(cursor: string, imageUrl: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<ArrayBuffer>{ return this.searchClient.readPhotoHistory(cursor, imageUrl, session, owner, id); }
  async deletePhotoHistory(ids: string[], page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<ArrayBuffer>{ return this.searchClient.deletePhotoHistory(ids, page, session, owner, id); }
  async searchUploadedPhoto(bytes: ArrayBuffer, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string, crop?: PhotoSearchRegion): Promise<string>{ return this.searchClient.searchUploadedPhoto(bytes, page, session, owner, id, crop); }
  async saveUploadedPhotoHistory(bytes: ArrayBuffer, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<void>{ return this.searchClient.saveUploadedPhotoHistory(bytes, page, session, owner, id); }
  async requestBusinessBoardFollow(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
      page: string, board: string, viewer: string, owner: () => boolean): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardFollow(job, session, page, board, viewer, owner); }
  async requestBusinessBoardSectionRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext, board: string, section: string, sectionPath: string, current: () => boolean): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardSectionRead(job, session, board, section, sectionPath, current); }
  async requestBusinessBoardSectionWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    board: string, section: string, viewer: string, owner: string, allIds: string[], selected: string[], complete: boolean,
    targets: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardSectionWrite(job, session, board, section, viewer, owner, allIds, selected, complete, targets, ownerCurrent); }
  async requestBusinessBoardContent(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, canContribute: boolean, loadedIds: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardContent(job, session, boardId, viewerId, ownerId, canContribute, loadedIds, ownerCurrent); }
  async requestBusinessBoardManagementWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, member: boolean, ownerCurrent: () => boolean, mergeTargets: string[] = []): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardManagementWrite(job, session, boardId, viewerId, ownerId, member, ownerCurrent, mergeTargets); }
  async requestBusinessBoardPinWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, loadedIds: string[], enabledTargets: string[], recommendedIds: string[], ownerCurrent: () => boolean, savedCopies: string[] = [], recommendationPath: string = ''): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardPinWrite(job, session, boardId, viewerId, loadedIds, enabledTargets, recommendedIds, ownerCurrent, savedCopies, recommendationPath); }
  async requestBusinessBoardCollaboratorWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, canInvite: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardCollaboratorWrite(job, session, boardId, viewerId, ownerId, canInvite, ownerCurrent); }
  async requestBusinessBoardCover(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, pinId: string, image: string, imageWidth: number, imageHeight: number,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardCover(job, session, boardId, viewerId, ownerId, pinId, image, imageWidth, imageHeight, ownerCurrent); }
  async requestBusinessBoardAuxRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, username: string, viewerId: string, ownerCurrent: () => boolean, createdBoardIdeas: boolean = false): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardAuxRead(job, session, boardId, username, viewerId, ownerCurrent, createdBoardIdeas); }
  async requestBusinessBoardRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, sectionId: string, viewerId: string, ownCollection: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.boardClient.requestBusinessBoardRead(job, session, boardId, sectionId, viewerId, ownCollection, ownerCurrent); }
  async requestPinRead(job: PinmonyNetworkJob, context: () => PinmonyNetworkContext,
    pinUrl: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestPinRead(job, context, pinUrl, ownerCurrent); }
  async requestBusinessShuffleRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, shuffleId: string, current: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessShuffleRead(job, session, pin, shuffleId, current); }
  async requestBusinessDetailAuxiliary(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessDetailAuxiliary(job, session, pin, ownerCurrent); }
  async requestBusinessCommentWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, aggregate: string, viewer: string, comment: string, own: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessCommentWrite(job, session, pin, aggregate, viewer, comment, own, ownerCurrent); }
  async requestBusinessPost(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext, pin: string,
    viewer: string, writableBoards: string[], ownsPin: boolean, editableContent: boolean, copyId: string, copyOwned: boolean,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessPost(job, session, pin, viewer, writableBoards, ownsPin, editableContent, copyId, copyOwned, ownerCurrent); }
  async requestBusinessPinMenu(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessPinMenu(job, session, pin, ownerCurrent); }
  async requestBusinessAuxiliary(job: PinmonyNetworkJob,session: () => PinmonyBusinessSessionContext,mode: string,target: string,ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessAuxiliary(job, session, mode, target, ownerCurrent); }
  async requestBusinessProductRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessProductRead(job, session, pin, ownerCurrent); }
  async requestBusinessPinRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pinUrl: string, ownerCurrent: () => boolean,
    legacyContext?: () => PinmonyNetworkContext, aggregatedPinId: string = '', commentId: string = ''): Promise<PinmonyNetworkReply>{ return this.pinClient.requestBusinessPinRead(job, session, pinUrl, ownerCurrent, legacyContext, aggregatedPinId, commentId); }
  async uploadCommentImage(bytes: ArrayBuffer, pin: string, context: () => PinmonyNetworkContext, ownerId: string = ''): Promise<string>{ return this.pinClient.uploadCommentImage(bytes, pin, context, ownerId); }
  async requestBusinessInboxWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext, viewerId: string, conversationId: string,
    contacts: string[], selectedIds: string[], reactionIds: string[], ownMessageIds: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.inboxClient.requestBusinessInboxWrite(job, session, viewerId, conversationId, contacts, selectedIds, reactionIds, ownMessageIds, ownerCurrent); }
  async requestBusinessInboxActivity(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    target: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.inboxClient.requestBusinessInboxActivity(job, session, target, ownerCurrent); }
  async requestBusinessInboxMessagesRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.inboxClient.requestBusinessInboxMessagesRead(job, session, ownerCurrent); }
  async requestBusinessInboxNewsRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    newsId: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.inboxClient.requestBusinessInboxNewsRead(job, session, newsId, ownerCurrent); }
  async requestBusinessInboxUpdatesRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.inboxClient.requestBusinessInboxUpdatesRead(job, session, ownerCurrent); }
  async requestBusinessHomeRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    username: string, board: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.homeClient.requestBusinessHomeRead(job, session, username, board, ownerCurrent); }
  async requestBusinessProfileSettings(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    profileUrl: string, userId: string, viewer: string, allowed: string[], permissions: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply>{ return this.settingsClient.requestBusinessProfileSettings(job, session, profileUrl, userId, viewer, allowed, permissions, ownerCurrent); }
}
