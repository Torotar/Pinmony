export class PinWebShareBridge {
  onNetworkRequest: ((value: string) => void) | undefined = undefined;
  onCancelNetwork: ((id: string) => void) | undefined = undefined;
  networkRequest(value: string): void { if (this.onNetworkRequest) this.onNetworkRequest(value); }
  cancelNetwork(id: string): void { if (this.onCancelNetwork) this.onCancelNetwork(id); }
  onAuthState: ((value: string) => void) | undefined = undefined;
  authState(value: string): void { if (this.onAuthState) this.onAuthState(value); }
  onBoardState: ((value: string) => void) | undefined = undefined;
  boardState(value: string): void { if (this.onBoardState) this.onBoardState(value); }
  onPostState: ((value: string) => void) | undefined = undefined;
  postState(value: string): void { if (this.onPostState) this.onPostState(value); }
  onShare: ((targetUrl: string, pinUrl: string) => void) | undefined = undefined;
  onNavigation: ((visible: boolean, index: number) => void) | undefined = undefined;
  onPageNavigation: ((url: string, mode: string) => void) | undefined = undefined;
  onPageBack: (() => void) | undefined = undefined;
  onSheetState: ((value: string) => void) | undefined = undefined;
  onMoreState: ((value: string) => void) | undefined = undefined;
  onDetailState: ((value: string) => void) | undefined = undefined;
  onProfileState: ((value: string) => void) | undefined = undefined;
  onProfilePublish: ((value: string) => void) | undefined = undefined;
  onHomeState: ((value: string) => void) | undefined = undefined;
  onInboxState: ((value: string) => void) | undefined = undefined;
  onSearchState: ((value: string) => void) | undefined = undefined;

  share(targetUrl: string, pinUrl: string): void {
    if (this.onShare) {
      this.onShare(targetUrl, pinUrl);
    }
  }

  navigation(visible: boolean, index: number): void {
    if (this.onNavigation) {
      this.onNavigation(visible, index);
    }
  }

  pageNavigation(url: string, mode: string): void {
    if (this.onPageNavigation) this.onPageNavigation(url, mode);
  }

  pageBack(): void {
    if (this.onPageBack) this.onPageBack();
  }

  sheetState(value: string): void {
    if (this.onSheetState) {
      this.onSheetState(value);
    }
  }

  moreState(value: string): void {
    if (this.onMoreState) {
      this.onMoreState(value);
    }
  }

  detailState(value: string): void {
    if (this.onDetailState) {
      this.onDetailState(value);
    }
  }

  profileState(value: string): void {
    if (this.onProfileState) this.onProfileState(value);
  }

  profilePublish(value: string): void {
    if (this.onProfilePublish) this.onProfilePublish(value);
  }

  homeState(value: string): void {
    if (this.onHomeState) this.onHomeState(value);
  }

  inboxState(value: string): void {
    if (this.onInboxState) this.onInboxState(value);
  }

  searchState(value: string): void {
    if (this.onSearchState) this.onSearchState(value);
  }

}
