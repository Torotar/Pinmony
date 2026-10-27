@Component
export struct PinmonyBoardCoverImage {
  @Prop @Watch('resetImages') urls: string[] = [];
  @State private failedUrls: string[] = [];
  private resetImages(): void { this.failedUrls = []; }
  private failImage(url: string): void {
    if(this.urls.includes(url) && !this.failedUrls.includes(url))this.failedUrls = this.failedUrls.concat([url]);
  }
  private visibleUrls(): string[] {
    const url: string | undefined = this.urls.find((candidate: string): boolean => !!candidate && !this.failedUrls.includes(candidate));
    return url ? [url] : [];
  }
  build() {
    Stack() {
      ForEach(this.visibleUrls(),(url: string) => {
        Image(url).width('100%').height('100%').objectFit(ImageFit.Cover)
          .onError((): void => { this.failImage(url); })
      },(url: string): string => url)
    }.width('100%').height('100%')
  }
}
